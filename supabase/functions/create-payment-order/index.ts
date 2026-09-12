// Deno edge function: creates a Razorpay payment order authoritatively on the server.
//
// Ensures payment secrets never live in the client, validates booking status,
// and saves the order in the `payments` table before client checkout.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildClientOrderResponse,
  buildPendingPaymentRecord,
} from "./helpers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";
function readSecret(name: string): string {
  let value = (Deno.env.get(name) || "").trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1).trim();
  }
  return value;
}

const RAZORPAY_KEY_ID = readSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET = readSecret("RAZORPAY_KEY_SECRET");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing_auth" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!SUPABASE_ANON_KEY) {
    return new Response(
      JSON.stringify({ error: "supabase_auth_not_configured" }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  // This client is deliberately user-scoped. It is used only to validate the
  // caller and read the caller's own pending booking through RLS.
  const userSupabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );

  // This client is deliberately separate and never receives the caller's
  // Authorization header. It is the only client allowed to write payments.
  const serviceSupabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  const { data: { user }, error: userError } = await userSupabase.auth
    .getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    return new Response(
      JSON.stringify({ error: "payment_provider_not_configured" }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
  if (
    !(RAZORPAY_KEY_ID.startsWith("rzp_test_") ||
      RAZORPAY_KEY_ID.startsWith("rzp_live_"))
  ) {
    return new Response(
      JSON.stringify({ error: "payment_provider_invalid" }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const body = await req.json();
    const { booking_id } = body;

    if (!booking_id) {
      return new Response(JSON.stringify({ error: "missing_booking_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the pending booking row
    const { data: booking, error: bookingError } = await userSupabase
      .from("bookings")
      .select(
        "id, booking_ref, total_amount, amount, tax_amount, status, venue_id",
      )
      .eq("id", booking_id)
      .eq("user_id", user.id)
      .single();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: "booking_not_found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (booking.status !== "pending") {
      return new Response(JSON.stringify({ error: "booking_not_payable" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const totalAmount = Number(booking.total_amount);
    if (!Number.isFinite(totalAmount) || totalAmount <= 0) {
      return new Response(JSON.stringify({ error: "invalid_booking_amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const amountInPaise = Math.round(totalAmount * 100);

    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: "INR",
        receipt: `${String(booking.booking_ref || booking.id).slice(0, 20)}-${Date.now().toString(36)}`.slice(0, 40),
        notes: {
          booking_id: booking.id,
          user_id: user.id,
        },
      }),
    });

    if (!rzpRes.ok) {
      let providerCode = "unknown";
      try {
        const errJson = await rzpRes.json() as {
          error?: { code?: string };
        };
        if (typeof errJson?.error?.code === "string") {
          providerCode = errJson.error.code;
        }
      } catch {
        // Never forward provider payloads; they can include account details.
      }
      return new Response(
        JSON.stringify({
          error: "payment_order_failed",
          provider_status: rzpRes.status,
          provider_code: providerCode,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const rzpData = await rzpRes.json();
    const orderId = typeof rzpData.id === "string" ? rzpData.id : "";
    if (orderId.length === 0) {
      return new Response(JSON.stringify({ error: "payment_order_invalid" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Record or update payment record
    const { error: paymentError } = await serviceSupabase
      .from("payments")
      .upsert(
        buildPendingPaymentRecord({
          bookingId: booking.id,
          userId: user.id,
          providerOrderId: orderId,
          amount: totalAmount,
          currency: "INR",
        }),
        { onConflict: "provider, provider_order_id" },
      );
    if (paymentError) {
      return new Response(JSON.stringify({ error: "payment_record_failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify(buildClientOrderResponse({
        orderId,
        amount: totalAmount,
        currency: "INR",
        publicKeyId: RAZORPAY_KEY_ID,
        bookingId: booking.id,
      })),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const message = err instanceof Error
      ? err.message
      : "order_creation_failed";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
