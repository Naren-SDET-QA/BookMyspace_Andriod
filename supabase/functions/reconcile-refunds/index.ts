// Deno edge function: scheduled reconciler for refunds stuck in
// 'requested'. Does NOT blindly retry the refund POST (that path is
// already idempotency-key-protected in create-refund) — it queries
// Razorpay for the refund's actual state via a read, which is always safe
// to repeat, and applies whatever it finds through apply_refund_result.
//
// NOTE: Razorpay's list-refunds-for-a-payment response does not echo back
// the idempotency key we sent, so correlation to our internal refund row
// is done by matching amount among that payment's refunds. This is a
// known, reported limitation (see the accompanying report) — if a payment
// ever has more than one refund attempt at Razorpay's end for the same
// amount, this cannot disambiguate them and reports
// "no_amount_match_needs_manual_review" rather than guessing.
//
// Phase 9XE addition: a 'requested' refund that has NEVER been sent to
// Razorpay at all (no item at all in the provider's refunds-for-payment
// list) previously sat forever with nothing escalating or submitting it.
// This version detects that case and, when dry_run is false, submits it
// to Razorpay's Refund API using the refund row's own UUID as the
// idempotency key -- the exact same pattern create-refund already uses,
// so a row submitted here and later retried by create-refund (or vice
// versa) cannot double-refund.
//
// SAFETY (Phase 9XG correction): default is WRITE (dry_run = false),
// matching the existing cron job's always-write behavior and its empty
// ('{}') request body. Only an explicit {"dry_run": true} activates
// dry-run/report-only mode. The existing amount-matching reconciliation
// logic below is unchanged; the new unsent-refund submission path follows
// the same dry-run/write gate.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;

// Exported pure helper (Phase 9XG): kept side-effect-free and exported so
// the cron-compatibility-critical default can be unit-tested directly
// (see index_test.ts) without hitting Supabase/Razorpay.
//
// CONTRACT: the live reconcile-refunds-sweep cron job posts an empty body
// ('{}'::jsonb) and has always run in always-write mode. This function
// must resolve an absent/false dry_run field to WRITE mode (false), and
// only an explicit {"dry_run": true} to dry-run mode (true).
export function resolveDryRun(body: unknown): boolean {
  if (body && typeof body === 'object' && (body as Record<string, unknown>).dry_run === true) {
    return true;
  }
  return false; // default: write (matches existing cron behavior)
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

async function fetchRazorpayPaymentRefunds(
  paymentId: string,
): Promise<{ items: Array<{ id: string; amount: number; status: string }> } | null> {
  const res = await fetch(
    `https://api.razorpay.com/v1/payments/${paymentId}/refunds`,
    { headers: { Authorization: razorpayAuthHeader() } },
  );
  if (!res.ok) return null;
  return res.json();
}

async function submitRazorpayRefund(
  paymentId: string,
  refundId: string,
  amountPaise: number,
): Promise<{ ok: true; id: string; status: string } | { ok: false; status: number; body: unknown }> {
  const res = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}/refund`, {
    method: 'POST',
    headers: {
      Authorization: razorpayAuthHeader(),
      'Content-Type': 'application/json',
      'X-Razorpay-Idempotency-Key': refundId,
    },
    body: JSON.stringify({ amount: amountPaise }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) return { ok: false, status: res.status, body };
  return { ok: true, id: body.id, status: body.status };
}

Deno.serve(async (req) => {
  // Intended to be invoked only by a trusted scheduler using the service
  // role key, not by end users — this function is not part of the
  // client-facing surface at all.
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.includes(SUPABASE_SERVICE_ROLE_KEY)) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  // Phase 9XG (9XF MUST-FIX #3): the live `reconcile-refunds-sweep` cron
  // job posts an empty body (`'{}'::jsonb`) and has always run in
  // always-write mode. Defaulting dry_run to true here would silently
  // turn every real reconciliation into a no-op the moment this version
  // is deployed behind that unchanged cron job, while still returning
  // HTTP 200 -- a regression that looks like success in monitoring. So
  // the default here is the OPPOSITE of reconcile-payment-drift: write
  // behavior is preserved unless the caller explicitly opts into dry-run
  // with {"dry_run": true}. This phase does not touch the cron job itself.
  let dryRun = false;
  try {
    const body = await req.json().catch(() => ({}));
    dryRun = resolveDryRun(body);
  } catch {
    // no body / not JSON -> default dry_run stays false (matches existing
    // cron behavior, which has always posted an empty body and always
    // written).
  }

  const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: stale, error } = await supabase.rpc('list_stale_refund_requests', {
    p_older_than_minutes: 10,
    p_limit: 50,
  });
  if (error) {
    return jsonResponse({ error: 'list_failed' }, 500);
  }

  const results: Record<string, unknown>[] = [];
  for (const row of stale ?? []) {
    const { data: payment } = await supabase
      .from('payments')
      .select('id, provider_payment_id')
      .eq('id', row.payment_id)
      .maybeSingle();
    if (!payment?.provider_payment_id) {
      results.push({ refund_id: row.refund_id, outcome: 'skipped_no_provider_payment_id' });
      continue;
    }

    const providerRefunds = await fetchRazorpayPaymentRefunds(payment.provider_payment_id);
    if (!providerRefunds) {
      results.push({ refund_id: row.refund_id, outcome: 'provider_unavailable_no_change' });
      continue;
    }

    if (!providerRefunds.items?.length) {
      // Phase 9XE: never submitted to Razorpay at all -- the original gap.
      if (dryRun) {
        results.push({ refund_id: row.refund_id, outcome: 'would_submit_unsent_refund', dry_run: true });
        continue;
      }
      const targetPaise = Math.round(Number(row.amount) * 100);
      const submission = await submitRazorpayRefund(payment.provider_payment_id, row.refund_id, targetPaise);
      if (!submission.ok) {
        results.push({ refund_id: row.refund_id, outcome: 'submit_failed', http_status: submission.status });
        continue;
      }
      results.push({ refund_id: row.refund_id, outcome: 'submitted', provider_refund_id: submission.id, provider_status: submission.status });
      continue;
    }

    const targetPaise = Math.round(Number(row.amount) * 100);
    const matches = providerRefunds.items.filter((item) => item.amount === targetPaise);
    if (matches.length !== 1) {
      results.push({
        refund_id: row.refund_id,
        outcome: matches.length === 0 ? 'no_amount_match_needs_manual_review' : 'ambiguous_amount_match_needs_manual_review',
      });
      continue;
    }
    const matched = matches[0];

    const status = matched.status === 'processed'
      ? 'processed'
      : matched.status === 'failed'
      ? 'failed'
      : null;
    if (!status) {
      results.push({ refund_id: row.refund_id, outcome: `still_pending_at_provider:${matched.status}` });
      continue;
    }

    if (dryRun) {
      results.push({ refund_id: row.refund_id, outcome: `would_apply_${status}`, dry_run: true });
      continue;
    }

    const { error: applyError } = await supabase.rpc('apply_refund_result', {
      p_refund_id: row.refund_id,
      p_provider_refund_id: matched.id,
      p_status: status,
      p_failure_reason: status === 'failed' ? 'reconciled_from_provider_sweep' : null,
    });
    results.push({ refund_id: row.refund_id, outcome: applyError ? 'apply_failed' : `applied_${status}` });
  }

  return jsonResponse({ dry_run: dryRun, swept: (stale ?? []).length, results });
});
