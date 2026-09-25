// Deno edge function: processes a refund INTENT that already exists in
// `public.refunds` (status='requested'), created by cancel_confirmed_booking
// or admin_cancel_booking. This function never creates the refund intent
// itself and never reads or trusts a client-supplied amount — the amount
// was already computed and persisted server-side, inside the same
// transaction that cancelled the booking, before this function is ever
// invoked (DB-intent-first design).
//
// POST body: { booking_id: string }
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ??
  Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
  '';
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

type RazorpayRefundOutcome =
  | { ok: true; id: string }
  | { ok: false; status: number; detail: string };

async function createRazorpayRefund(
  paymentId: string,
  amountPaise: number,
  idempotencyKey: string,
  reason: string,
): Promise<RazorpayRefundOutcome> {
  const body = new URLSearchParams({
    amount: String(amountPaise),
    notes: reason || 'booking_refund',
  });
  let res: Response;
  try {
    res = await fetch(
      `https://api.razorpay.com/v1/payments/${paymentId}/refund`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          // Ties Razorpay-side idempotency to the same DB row that the
          // partial unique index already protects at the database level —
          // a retried outbound call (client retry, network partition
          // retry) cannot create two real refunds at Razorpay's end either.
          'X-Razorpay-Idempotency-Key': idempotencyKey,
        },
        body,
      },
    );
  } catch (networkError) {
    // Could not even complete the request. We do NOT know whether Razorpay
    // received and processed it before the connection dropped. Report as a
    // non-4xx failure so the caller leaves the row in 'requested' for the
    // reconciler rather than guessing.
    return { ok: false, status: 0, detail: String(networkError) };
  }
  const text = await res.text();
  if (!res.ok) {
    return { ok: false, status: res.status, detail: text };
  }
  try {
    const json = JSON.parse(text);
    return { ok: true, id: String(json.id) };
  } catch (_) {
    return { ok: false, status: 502, detail: 'unparseable_razorpay_response' };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'missing_auth' }, 401);
  }

  if (!SUPABASE_ANON_KEY) {
    return jsonResponse({ error: 'supabase_auth_not_configured' }, 503);
  }

  // User-context client: forwards the caller's own JWT so Supabase/PostgREST
  // derives auth.uid()/role from it (via the Authorization header), for
  // operations that must run as the calling customer under RLS. Uses the
  // anon/publishable key (not the service-role key) so this client object
  // never carries service-role privilege on its own -- the caller's own
  // JWT in the Authorization header is the only thing granting it access.
  const userClient: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );
  // Service-role client: no Authorization header override at all, so it
  // always authenticates purely as service_role. Used only for privileged
  // operations (apply_refund_result) that must not run as `authenticated`.
  const serviceClient: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let booking_id: string | undefined;
  try {
    const body = await req.json();
    booking_id = typeof body?.booking_id === 'string' ? body.booking_id : undefined;
  } catch (_) {
    return jsonResponse({ error: 'invalid_body' }, 400);
  }
  if (!booking_id) {
    return jsonResponse({ error: 'missing_fields' }, 400);
  }

  // This function only authorizes READING the booking to find its already-
  // created refund intent. Authorization to CANCEL happened earlier, inside
  // cancel_confirmed_booking / admin_cancel_booking. A direct client call is
  // scoped to that booking's own customer only.
  const { data: booking, error: bookingError } = await userClient
    .from('bookings')
    .select('id, user_id, status')
    .eq('id', booking_id)
    .maybeSingle();
  if (bookingError || !booking) {
    return jsonResponse({ error: 'booking_not_found' }, 404);
  }
  if (booking.user_id !== user.id) {
    return jsonResponse({ error: 'not_authorized' }, 403);
  }

  // Find the active (non-failed) refund intent for this booking. This row
  // was created by cancel_confirmed_booking/admin_cancel_booking — never by
  // this function — and its amount was computed/authorized there, not here.
  const { data: refund, error: refundError } = await userClient
    .from('refunds')
    .select('id, payment_id, booking_id, amount, status, provider_refund_id, reason')
    .eq('booking_id', booking_id)
    .neq('status', 'failed')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (refundError) {
    return jsonResponse({ error: 'refund_lookup_failed' }, 500);
  }
  if (!refund) {
    return jsonResponse({ error: 'no_refund_intent', booking_status: booking.status }, 404);
  }
  if (refund.status !== 'requested') {
    // Already processed, or already being processed by a concurrent call.
    // Report the current state instead of repeating the provider call —
    // this is what makes a client retry after a lost response safe.
    return jsonResponse({
      id: refund.id,
      status: refund.status,
      provider_refund_id: refund.provider_refund_id,
    });
  }

  const { data: payment, error: paymentError } = await userClient
    .from('payments')
    .select('id, provider_payment_id, amount, status')
    .eq('id', refund.payment_id)
    .maybeSingle();
  if (paymentError || !payment || !payment.provider_payment_id) {
    return jsonResponse({ error: 'payment_not_found' }, 404);
  }

  const result = await createRazorpayRefund(
    payment.provider_payment_id,
    Math.round(Number(refund.amount) * 100),
    refund.id, // idempotency key = this DB row's own id
    refund.reason ?? '',
  );

  if (!result.ok) {
    if (result.status >= 400 && result.status < 500) {
      // Razorpay unambiguously rejected the refund (e.g. already refunded
      // at their end, invalid amount). Safe to mark failed now.
      await serviceClient.rpc('apply_refund_result', {
        p_refund_id: refund.id,
        p_provider_refund_id: null,
        p_status: 'failed',
        p_failure_reason: `razorpay_${result.status}: ${result.detail.slice(0, 500)}`,
      });
      return jsonResponse({ id: refund.id, status: 'failed' }, 502);
    }
    // Network error, timeout, or 5xx: we do NOT know whether Razorpay
    // actually processed the refund before the response was lost. Leave
    // the row in 'requested' — the scheduled reconciler and/or the
    // razorpay-webhook refund-event handler resolve it from here, never
    // this function guessing.
    return jsonResponse(
      { id: refund.id, status: 'requested', note: 'pending_reconciliation' },
      202,
    );
  }

  // Fast-path status update. The razorpay-webhook refund.processed handler
  // is the authoritative confirmation and applies the same result
  // idempotently if it arrives later, or if this update itself fails here
  // (the Razorpay refund has already happened either way — see below).
  const { error: applyError } = await serviceClient.rpc('apply_refund_result', {
    p_refund_id: refund.id,
    p_provider_refund_id: result.id,
    p_status: 'processed',
    p_failure_reason: null,
  });
  if (applyError) {
    // The Razorpay refund already succeeded; this DB update failing does
    // NOT lose that outcome. The row stays 'requested' and the webhook (or
    // the reconciler) will still catch it up.
    return jsonResponse(
      {
        id: refund.id,
        status: 'requested',
        provider_refund_id: result.id,
        note: 'db_update_pending_reconciliation',
      },
      202,
    );
  }

  return jsonResponse({ id: refund.id, status: 'processed', provider_refund_id: result.id });
});
