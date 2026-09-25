// Deno edge function: create an owner-approval booking request atomically on
// the server. The endpoint name is retained for backwards compatibility with
// already-released clients.
//
// Called from the Flutter app AFTER the user picks a venue/date/slot and
// BEFORE payment. The returned hold is an approval hold; payment is only
// allowed after the owner approval RPC moves the booking to `pending`.
//
// POST body:
// {
//   venue_id, slot_id, book_date, idempotency_key,
//   amount, hold_minutes?, approval_minutes?
// }
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Authorise via the user's JWT (RLS-safe identity).
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'missing_auth' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );

  // Resolve the authenticated user id from the JWT.
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const {
      venue_id,
      slot_id,
      book_date,
      idempotency_key,
      amount,
      hold_minutes,
      approval_minutes,
    } = body;

    if (!venue_id || !slot_id || !book_date || !idempotency_key) {
      return new Response(JSON.stringify({ error: 'missing_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // The database function re-reads the venue, exact slot, date, tax and
    // availability while holding the inventory lock. Client amounts are
    // accepted only for backwards-compatible request shape and are not used
    // as an authority for the booking total.
    const { data, error: requestError } = await supabase.rpc(
      'request_venue_booking',
      {
        p_venue_id: venue_id,
        p_slot_id: slot_id,
        p_book_date: book_date,
        p_user_id: user.id,
        p_idempotency_key: idempotency_key,
        p_base_amount: Number(amount) || 0,
        p_tax_amount: 0,
        p_discount_amount: 0,
        p_approval_minutes: approval_minutes ?? 120,
      },
    );
    if (requestError) {
      const raw = requestError.message?.toLowerCase() ?? '';
      const msg = raw.includes('slot_unavailable') || raw.includes('unavailable')
        ? 'slot_unavailable'
        : raw.includes('date_blocked')
        ? 'date_blocked'
        : 'request_failed';
      return new Response(JSON.stringify({ error: msg }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!data || typeof data !== 'object') {
      return new Response(JSON.stringify({ error: 'empty_request_response' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const result = data as Record<string, unknown>;
    if (result.success !== true) {
      const errorCode = typeof result.error_code === 'string'
        ? result.error_code.toLowerCase()
        : 'request_failed';
      const status = errorCode === 'slot_unavailable' ||
          errorCode === 'date_blocked'
        ? 409
        : errorCode === 'unauthorized'
        ? 401
        : 400;
      return new Response(JSON.stringify({ error: errorCode }), {
        status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'internal', detail: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
