// Phase 9XE/9XG: provider-verified payment drift reconciler.
//
// SAFETY MODEL:
// - Default is DRY RUN. Only a request body of {"dry_run": false} enables
//   writes, and even then only to `payments.metadata` (merged, never
//   replaced) / `last_reconciled_at`, and to `provider_orphan_orders` --
//   never to `payments.status`. Status changes are intentionally out of
//   scope for this function's first version; see report notes for why
//   (Phase 9XB/9XD: any auto-fail must be provider-verified, and
//   auto-upgrading a payment to 'captured' from here should go through
//   the same reviewed path as the manual Phase 9XA.3 fix, not be silently
//   automated in v1).
// - Every Razorpay call failure (timeout, 5xx, rate limit) leaves state
//   untouched and reports 'provider_unavailable' -- never treated as
//   confirmation of anything.
// - Not wired to any cron job by this change. Invoke manually to test.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;

// Phase 9XG (9XF MUST-FIX #1): skip re-checking a candidate that was
// verified against Razorpay more recently than this window. Keeps the
// sweep cheap without ever suppressing a *legitimate* re-check -- a row
// with last_reconciled_at = null (never checked) always qualifies.
const RECHECK_COOLDOWN_MINUTES = 15;

// Exported pure helpers (Phase 9XG): kept side-effect-free and exported
// specifically so they can be unit-tested (see index_test.ts) without
// spinning up Deno.serve or hitting Supabase/Razorpay.
export function resolveDryRun(body: unknown): boolean {
  if (body && typeof body === 'object' && (body as Record<string, unknown>).dry_run === false) {
    return false;
  }
  return true; // default: dry-run (this function has always defaulted to dry-run)
}

export function mergeReconciliationMetadata(
  existing: unknown,
  patch: Record<string, unknown>,
): Record<string, unknown> {
  const base = existing && typeof existing === 'object' && !Array.isArray(existing)
    ? existing as Record<string, unknown>
    : {};
  return { ...base, ...patch };
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function razorpayAuthHeader(): string {
  return `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`;
}

async function fetchRazorpayOrder(orderId: string): Promise<{ found: boolean; status?: string } | null> {
  const res = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
    headers: { Authorization: razorpayAuthHeader() },
  });
  if (res.status === 404) return { found: false };
  if (!res.ok) return null; // provider_unavailable -- do NOT treat as not-found
  const body = await res.json();
  return { found: true, status: body.status };
}

interface RazorpayPaymentItem {
  id: string;
  order_id: string;
  amount: number;
  currency: string;
  status: string;
}

// Lists recent Razorpay payments in a rolling window. Returns null on any
// provider error (never an empty array standing in for "no payments" on
// failure -- that distinction matters so a transient error can't be
// mistaken for "nothing to reconcile").
async function fetchRecentRazorpayPayments(fromUnix: number): Promise<RazorpayPaymentItem[] | null> {
  const items: RazorpayPaymentItem[] = [];
  let skip = 0;
  const count = 100;
  for (let page = 0; page < 10; page++) { // hard cap: 1000 payments per sweep
    const res = await fetch(
      `https://api.razorpay.com/v1/payments?from=${fromUnix}&count=${count}&skip=${skip}`,
      { headers: { Authorization: razorpayAuthHeader() } },
    );
    if (!res.ok) return null;
    const body = await res.json();
    const pageItems: RazorpayPaymentItem[] = body.items ?? [];
    items.push(...pageItems);
    if (pageItems.length < count) break;
    skip += count;
  }
  return items;
}

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.includes(SUPABASE_SERVICE_ROLE_KEY)) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let dryRun = true;
  try {
    const body = await req.json().catch(() => ({}));
    dryRun = resolveDryRun(body);
  } catch {
    // no body / not JSON -> default dry_run stays true
  }

  const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const cooldownCutoff = new Date(Date.now() - RECHECK_COOLDOWN_MINUTES * 60_000).toISOString();

  // ---------------------------------------------------------------------
  // Direction 1: Supabase payments rows with no confirmed Razorpay order.
  // Phase 9XG: filtered by last_reconciled_at cooldown -- a row is a
  // candidate if it was never checked, OR its last check is older than
  // the cooldown. This can only ever ADD eligibility over time (a stale
  // check ages back into scope), never permanently exclude a row.
  // ---------------------------------------------------------------------
  const { data: candidates, error: candErr } = await supabase
    .from('payments')
    .select('id, provider_order_id, status, provider_payment_id, last_reconciled_at, metadata')
    .is('provider_payment_id', null)
    .in('status', ['failed', 'pending'])
    .or(`last_reconciled_at.is.null,last_reconciled_at.lt.${cooldownCutoff}`)
    .limit(200);

  if (candErr) {
    return jsonResponse({ error: 'list_failed', detail: candErr.message }, 500);
  }

  const direction1Results: Record<string, unknown>[] = [];

  for (const row of candidates ?? []) {
    if (!row.provider_order_id) {
      direction1Results.push({ payment_id: row.id, outcome: 'skipped_no_provider_order_id' });
      continue;
    }
    const check = await fetchRazorpayOrder(row.provider_order_id);
    if (check === null) {
      direction1Results.push({ payment_id: row.id, outcome: 'provider_unavailable_no_change' });
      continue;
    }
    if (!check.found) {
      direction1Results.push({ payment_id: row.id, outcome: 'confirmed_no_razorpay_order', dry_run: dryRun });
      if (!dryRun) {
        // Phase 9XG (9XF MUST-FIX #1): merge into existing metadata,
        // never replace it. `row.metadata` was already selected above so
        // this update is based on the value read in this same request,
        // not a blind overwrite of whatever the row currently holds.
        const mergedMetadata = mergeReconciliationMetadata(row.metadata, {
          reconciliation_note: 'no_razorpay_order_found',
          checked_at: new Date().toISOString(),
        });
        await supabase
          .from('payments')
          .update({ last_reconciled_at: new Date().toISOString(), metadata: mergedMetadata })
          .eq('id', row.id);
      }
      continue;
    }
    // Order exists at Razorpay but Supabase shows no captured payment --
    // this is the "B" case (paid but Supabase missed it). v1 does NOT
    // auto-correct status; it only reports, matching the safety note
    // above. Still stamp last_reconciled_at (merging metadata, not
    // touching status) so this doesn't get re-checked every 5 minutes
    // forever once a human has been notified.
    direction1Results.push({
      payment_id: row.id,
      outcome: 'razorpay_order_exists_needs_manual_review',
      razorpay_order_status: check.status,
      dry_run: dryRun,
    });
    if (!dryRun) {
      const mergedMetadata = mergeReconciliationMetadata(row.metadata, {
        reconciliation_note: 'razorpay_order_exists_needs_manual_review',
        razorpay_order_status: check.status,
        checked_at: new Date().toISOString(),
      });
      await supabase
        .from('payments')
        .update({ last_reconciled_at: new Date().toISOString(), metadata: mergedMetadata })
        .eq('id', row.id);
    }
  }

  // ---------------------------------------------------------------------
  // Direction 2 (Phase 9XG -- previously missing): Razorpay payments with
  // no corresponding Supabase `payments` row at all. Detection-only:
  // writes exclusively to provider_orphan_orders, NEVER to `payments` or
  // `bookings` -- there is no booking_id to attach on Razorpay's side, so
  // auto-creating a payments row here would be a guess, not a fact.
  // ---------------------------------------------------------------------
  const direction2Results: Record<string, unknown>[] = [];
  const lookbackDays = 30;
  const fromUnix = Math.floor((Date.now() - lookbackDays * 86_400_000) / 1000);
  const recentPayments = await fetchRecentRazorpayPayments(fromUnix);

  if (recentPayments === null) {
    direction2Results.push({ outcome: 'provider_unavailable_no_change' });
  } else {
    const orderIds = recentPayments.map((p) => p.order_id).filter(Boolean);
    const { data: knownPayments, error: knownErr } = orderIds.length
      ? await supabase.from('payments').select('provider_order_id').in('provider_order_id', orderIds)
      : { data: [], error: null };

    if (knownErr) {
      direction2Results.push({ outcome: 'list_failed', detail: knownErr.message });
    } else {
      const knownOrderIds = new Set((knownPayments ?? []).map((p) => p.provider_order_id));
      const orphans = recentPayments.filter((p) => p.order_id && !knownOrderIds.has(p.order_id));

      for (const orphan of orphans) {
        direction2Results.push({
          provider_order_id: orphan.order_id,
          provider_payment_id: orphan.id,
          razorpay_status: orphan.status,
          outcome: 'confirmed_razorpay_only_orphan',
          dry_run: dryRun,
        });
        if (!dryRun) {
          // Upsert on (provider, provider_order_id): re-running this sweep
          // is always safe and never creates duplicate orphan rows.
          await supabase
            .from('provider_orphan_orders')
            .upsert(
              {
                provider: 'razorpay',
                provider_order_id: orphan.order_id,
                provider_payment_id: orphan.id,
                amount: orphan.amount / 100,
                currency: orphan.currency,
                status: orphan.status,
              },
              { onConflict: 'provider,provider_order_id' },
            );
        }
      }
    }
  }

  return jsonResponse({
    dry_run: dryRun,
    direction1_checked: (candidates ?? []).length,
    direction1_results: direction1Results,
    direction2_checked: recentPayments?.length ?? 0,
    direction2_results: direction2Results,
  });
});
