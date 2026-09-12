// Deno edge function: verifies Razorpay payment and confirms booking.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { createHmac, timingSafeEqual } from 'node:crypto';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') || '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function verifyRazorpaySignature(orderId: string, paymentId: string, signature: string): boolean {
  // A missing secret is a configuration failure, never a valid signature.
  if (!RAZORPAY_KEY_SECRET) return false;
  try {
    const expected = createHmac('sha256', RAZORPAY_KEY_SECRET)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');
    const a = Buffer.from(signature ?? '');
    const b = Buffer.from(expected);
    return a.length === b.length && timingSafeEqual(a, b);
  } catch (_) {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

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

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const { booking_id, order_id, payment_id, signature } = body;

    if (!booking_id || !order_id || !payment_id || !signature) {
      return new Response(JSON.stringify({ error: 'missing_required_fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!verifyRazorpaySignature(order_id, payment_id, signature)) {
      return new Response(JSON.stringify({ error: 'invalid_signature' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Confirm booking atomically via RPC
    const { error: confirmError } = await supabase.rpc('confirm_booking', {
      p_booking_id: booking_id,
      p_payment_ref: payment_id,
    });

    if (confirmError) {
      return new Response(JSON.stringify({ error: 'booking_confirmation_failed' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Update payment record to captured
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .update({
        status: 'captured',
        provider_payment_id: payment_id,
        updated_at: new Date().toISOString(),
      })
      .eq('booking_id', booking_id)
      .eq('provider_order_id', order_id)
      .select('id')
      .maybeSingle();
    if (paymentError || !payment) {
      return new Response(JSON.stringify({ error: 'payment_update_failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      booking_id,
      payment_id,
      status: 'confirmed',
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || 'verification_failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
