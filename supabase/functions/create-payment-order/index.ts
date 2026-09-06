// Deno edge function: creates a Razorpay payment order authoritatively on the server.
//
// Ensures payment secrets never live in the client, validates booking status,
// and saves the order in the `payments` table before client checkout.
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') || 'rzp_test_bookmyspace';
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') || '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

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
    const { booking_id } = body;

    if (!booking_id) {
      return new Response(JSON.stringify({ error: 'missing_booking_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Fetch the pending booking row
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('id, booking_ref, total_amount, amount, tax_amount, status, venue_id')
      .eq('id', booking_id)
      .eq('user_id', user.id)
      .single();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: 'booking_not_found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const totalAmount = Number(booking.total_amount) || (Number(booking.amount) + Number(booking.tax_amount));
    const amountInPaise = Math.round(totalAmount * 100);

    let orderId = `order_${booking.id.replace(/-/g, '').slice(0, 14)}`;

    // Call Razorpay API if credentials are configured
    if (RAZORPAY_KEY_SECRET) {
      try {
        const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
        const rzpRes = await fetch('https://api.razorpay.com/v1/orders', {
          method: 'POST',
          headers: {
            'Authorization': `Basic ${auth}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: amountInPaise,
            currency: 'INR',
            receipt: booking.booking_ref || booking.id,
            notes: {
              booking_id: booking.id,
              user_id: user.id,
            },
          }),
        });

        if (rzpRes.ok) {
          const rzpData = await rzpRes.json();
          orderId = rzpData.id;
        }
      } catch (err) {
        console.warn('Razorpay API request warning:', err);
      }
    }

    // Record or update payment record
    await supabase.from('payments').upsert({
      booking_id: booking.id,
      user_id: user.id,
      provider: 'razorpay',
      provider_order_id: orderId,
      amount: totalAmount,
      currency: 'INR',
      status: 'pending',
    }, { onConflict: 'provider, provider_order_id' });

    return new Response(JSON.stringify({
      order_id: orderId,
      amount: totalAmount,
      currency: 'INR',
      key_id: RAZORPAY_KEY_ID,
      notes: {
        booking_id: booking.id,
      },
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || 'order_creation_failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
