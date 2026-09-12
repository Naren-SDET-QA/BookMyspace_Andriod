// Deno edge function: Razorpay webhook receiver.
//
// SECURITY: verifies the Razorpay webhook signature before processing.
// IDEMPOTENT: event identity is specific to the provider event, and the
// event is marked processed only after the business operation succeeds.
//
// Razorpay signs the raw body with HMAC-SHA256 using the webhook secret.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  confirmationRpcArgs,
  deriveRazorpayEventId,
  type RazorpayWebhookEvent,
  verifyRazorpaySignature,
} from "./helpers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function stringValue(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

async function markEventProcessed(
  supabase: SupabaseClient,
  provider: string,
  eventId: string,
): Promise<void> {
  const { data, error } = await supabase
    .from("webhook_events")
    .update({ processed: true, processed_at: new Date().toISOString() })
    .eq("provider", provider)
    .eq("event_id", eventId)
    .eq("processed", false)
    .select("id")
    .maybeSingle();
  if (error || !data) {
    throw new Error("webhook_processing_state_update_failed");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  if (!verifyRazorpaySignature(rawBody, signature, RAZORPAY_WEBHOOK_SECRET)) {
    return jsonResponse({ error: "invalid_signature" }, 400);
  }

  let event: RazorpayWebhookEvent;
  try {
    event = JSON.parse(rawBody) as RazorpayWebhookEvent;
  } catch (_) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const eventType = stringValue(event.event) ?? "unknown";
  let eventId: string;
  try {
    eventId = deriveRazorpayEventId(
      event,
      eventType,
      req.headers.get("x-razorpay-event-id"),
    );
  } catch (_) {
    return jsonResponse({ error: "missing_event_identity" }, 400);
  }

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  // Registration is a claim, not success. The row remains unprocessed until
  // the operation below completes, so a failed delivery can be retried.
  const { data: registered, error: registerError } = await supabase.rpc(
    "register_webhook_event",
    {
      p_provider: "razorpay",
      p_event_id: eventId,
      p_event_type: eventType,
      p_payload: event,
    },
  );
  if (registerError) {
    return jsonResponse({ error: "webhook_registration_failed" }, 500);
  }
  if (registered === false) {
    return jsonResponse({ status: "duplicate" });
  }

  try {
    const paymentEntity = event.payload?.payment?.entity;
    const orderId = stringValue(paymentEntity?.order_id);
    const paymentId = stringValue(paymentEntity?.id);

    if (eventType === "payment.captured") {
      if (!orderId || !paymentId) {
        return jsonResponse({ error: "invalid_captured_payload" }, 400);
      }

      const providerAmountPaise = Number(paymentEntity?.amount);
      if (!Number.isFinite(providerAmountPaise)) {
        return jsonResponse({ error: "invalid_captured_amount" }, 400);
      }

      const { data: payment, error: paymentError } = await supabase
        .from("payments")
        .select("id, booking_id, user_id, amount, status")
        .eq("provider_order_id", orderId)
        .maybeSingle();
      if (paymentError || !payment) {
        return jsonResponse({ error: "payment_not_found" }, 404);
      }

      const expectedAmountPaise = Math.round(Number(payment.amount) * 100);
      if (providerAmountPaise !== expectedAmountPaise) {
        return jsonResponse({ error: "payment_amount_mismatch" }, 409);
      }

      // Persist the provider result with the service-role client before
      // invoking the server-side booking lifecycle RPC.
      const { error: paymentUpdateError } = await supabase
        .from("payments")
        .update({ status: "captured", provider_payment_id: paymentId })
        .eq("id", payment.id);
      if (paymentUpdateError) {
        return jsonResponse({ error: "payment_update_failed" }, 500);
      }

      const { data: confirmation, error: confirmationError } = await supabase
        .rpc(
          "confirm_venue_booking",
          confirmationRpcArgs({
            bookingId: payment.booking_id,
            userId: payment.user_id,
            paymentId,
          }),
        );
      if (confirmationError) {
        return jsonResponse({ error: "booking_confirmation_failed" }, 409);
      }
      if (
        !confirmation ||
        typeof confirmation !== "object" ||
        (confirmation as { success?: unknown }).success !== true
      ) {
        return jsonResponse({ error: "booking_confirmation_rejected" }, 409);
      }

      await markEventProcessed(supabase, "razorpay", eventId);
      return jsonResponse({ status: "confirmed" });
    }

    if (eventType === "payment.authorized" || eventType === "order.paid") {
      // Booking confirmation is owned by payment.captured only. These events
      // are recorded independently so they cannot duplicate a booking.
      await markEventProcessed(supabase, "razorpay", eventId);
      return jsonResponse({
        status: eventType === "order.paid"
          ? "recorded_order_paid"
          : "recorded_authorized",
      });
    }

    if (eventType === "payment.failed") {
      if (!orderId) {
        return jsonResponse({ error: "invalid_failed_payload" }, 400);
      }

      const { data: payment, error: paymentError } = await supabase
        .from("payments")
        .select("id, status")
        .eq("provider_order_id", orderId)
        .maybeSingle();
      if (paymentError || !payment) {
        return jsonResponse({ error: "payment_not_found" }, 404);
      }

      // A late failure notification must never downgrade a captured payment.
      if (payment.status !== "captured") {
        const { error: paymentUpdateError } = await supabase
          .from("payments")
          .update({ status: "failed" })
          .eq("id", payment.id);
        if (paymentUpdateError) {
          return jsonResponse({ error: "payment_update_failed" }, 500);
        }
      }

      await markEventProcessed(supabase, "razorpay", eventId);
      return jsonResponse({ status: "recorded_failed" });
    }

    // payment.authorized and other notifications are recorded independently
    // from payment.captured, then marked processed without confirming a booking.
    await markEventProcessed(supabase, "razorpay", eventId);
    return jsonResponse({ status: "ignored" });
  } catch (_) {
    // The event row intentionally remains processed=false. The provider can
    // retry the event, and all business updates above are idempotent.
    return jsonResponse({ error: "webhook_processing_failed" }, 500);
  }
});
