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

  let preparedBookingId: string | null = null;
  try {
    const body = await req.json();
    const {
      booking_id,
      payment_plan = "full",
      wallet_credit_amount = 0,
    } = body;

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
        "id, booking_ref, total_amount, amount, tax_amount, status, venue_id, hold_id, approval_required, approved_at, approved_by, payment_expires_at",
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

    // Approve-first is enforced here as a second boundary. A caller cannot
    // create a Razorpay order for an awaiting, rejected or expired request,
    // even if it reaches this function with a guessed booking id.
    if (!booking.approved_at || !booking.approved_by) {
      return new Response(JSON.stringify({ error: "owner_approval_required" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (
      booking.payment_expires_at &&
      new Date(booking.payment_expires_at).getTime() <= Date.now()
    ) {
      return new Response(JSON.stringify({ error: "payment_window_expired" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Approval extends the same server-owned hold into the payment window.
    // Refuse to create a provider order if that inventory lock is no longer
    // active; confirmation also rechecks it inside the database transaction.
    if (!booking.hold_id) {
      return new Response(JSON.stringify({ error: "booking_hold_expired" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { data: hold, error: holdError } = await userSupabase
      .from("booking_holds")
      .select("status, expires_at")
      .eq("id", booking.hold_id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (
      holdError ||
      !hold ||
      hold.status !== "active" ||
      !hold.expires_at ||
      new Date(hold.expires_at).getTime() <= Date.now()
    ) {
      return new Response(JSON.stringify({ error: "booking_hold_expired" }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Resolve the payment plan and wallet credit while holding the booking
    // lock. The client may request a plan/credit, but the RPC caps it against
    // the venue policy, the server total, and the current wallet balance.
    const { data: quote, error: quoteError } = await userSupabase.rpc(
      "prepare_booking_payment",
      {
        p_booking_id: booking.id,
        p_payment_plan: String(payment_plan),
        p_wallet_credit: Number(wallet_credit_amount) || 0,
      },
    );
    if (quoteError || !quote || typeof quote !== "object") {
      const safeCode = quoteError?.message?.split(" ")[0] ||
        "payment_quote_failed";
      return new Response(JSON.stringify({ error: safeCode }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quoteJson = quote as Record<string, unknown>;
    preparedBookingId = booking.id;
    const totalAmount = Number(quoteJson.full_amount);
    const payableAmount = Number(quoteJson.payable_amount);
    const walletCredit = Number(quoteJson.wallet_credit_amount) || 0;
    if (!Number.isFinite(totalAmount) || totalAmount <= 0 ||
      !Number.isFinite(payableAmount) || payableAmount < 0) {
      return new Response(JSON.stringify({ error: "invalid_booking_amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // A wallet-only payment has no provider order. The same server-side
    // approval, hold and wallet checks still apply, and the database records
    // the captured wallet payment and confirmation atomically.
    if (payableAmount <= 0) {
      const { data: walletSettlement, error: walletError } =
        await userSupabase.rpc("settle_booking_with_wallet", {
          p_booking_id: booking.id,
        });
      if (walletError || !walletSettlement) {
        await userSupabase.rpc("release_booking_wallet_credit", {
          p_booking_id: booking.id,
        });
        return new Response(JSON.stringify({ error: "wallet_settlement_failed" }), {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      preparedBookingId = null;
      return new Response(JSON.stringify({
        order_id: "",
        amount: 0,
        currency: "INR",
        wallet_only: true,
        wallet_credit_amount: walletCredit,
        payment_plan: quoteJson.payment_plan,
        notes: { booking_id: booking.id },
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const amountInPaise = Math.round(payableAmount * 100);

    // Reuse an existing pending provider order for the same booking. This
    // makes retries and double taps idempotent instead of creating a second
    // Razorpay order for one server booking.
    const { data: existingPayment } = await serviceSupabase
      .from("payments")
      .select("provider_order_id, amount, currency, status")
      .eq("booking_id", booking.id)
      .eq("provider", "razorpay")
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (existingPayment?.provider_order_id) {
      preparedBookingId = null;
      return new Response(
        JSON.stringify({ ...buildClientOrderResponse({
          orderId: existingPayment.provider_order_id,
          amount: Number(existingPayment.amount) || payableAmount,
          currency: existingPayment.currency || "INR",
          publicKeyId: RAZORPAY_KEY_ID,
          bookingId: booking.id,
        }),
          payment_plan: quoteJson.payment_plan,
          full_amount: totalAmount,
          advance_amount: Number(quoteJson.advance_amount) || 0,
          balance_due: Number(quoteJson.balance_due) || 0,
          wallet_credit_amount: walletCredit,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

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
          payment_plan: quoteJson.payment_plan,
          wallet_credit_amount: walletCredit,
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
      await userSupabase.rpc("release_booking_wallet_credit", {
        p_booking_id: booking.id,
      });
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
      await userSupabase.rpc("release_booking_wallet_credit", {
        p_booking_id: booking.id,
      });
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
          amount: payableAmount,
          currency: "INR",
        }),
        { onConflict: "provider, provider_order_id" },
      );
    if (paymentError) {
      await userSupabase.rpc("release_booking_wallet_credit", {
        p_booking_id: booking.id,
      });
      return new Response(JSON.stringify({ error: "payment_record_failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    await serviceSupabase
      .from("payments")
      .update({
        method: "razorpay",
        metadata: {
          payment_plan: quoteJson.payment_plan,
          full_amount: totalAmount,
          wallet_credit_amount: walletCredit,
          balance_due: Number(quoteJson.balance_due) || 0,
        },
      })
      .eq("provider", "razorpay")
      .eq("provider_order_id", orderId);

    return new Response(
      JSON.stringify({ ...buildClientOrderResponse({
        orderId,
        amount: payableAmount,
        currency: "INR",
        publicKeyId: RAZORPAY_KEY_ID,
        bookingId: booking.id,
      }),
        payment_plan: quoteJson.payment_plan,
        full_amount: totalAmount,
        advance_amount: Number(quoteJson.advance_amount) || 0,
        balance_due: Number(quoteJson.balance_due) || 0,
        wallet_credit_amount: walletCredit,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    if (preparedBookingId != null) {
      await userSupabase.rpc("release_booking_wallet_credit", {
        p_booking_id: preparedBookingId,
      });
    }
    const message = err instanceof Error
      ? err.message
      : "order_creation_failed";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
