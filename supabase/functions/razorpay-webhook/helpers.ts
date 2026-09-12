import { createHmac, timingSafeEqual } from "node:crypto";

export type RazorpayWebhookEvent = {
  id?: unknown;
  event?: unknown;
  payload?: {
    payment?: {
      entity?: {
        id?: unknown;
        order_id?: unknown;
        amount?: unknown;
      };
    };
  };
};

function nonEmptyString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

export function verifyRazorpaySignature(
  body: string,
  signature: string,
  secret: string,
): boolean {
  if (!secret || !signature) return false;
  const expected = createHmac("sha256", secret).update(body).digest("hex");
  const actualBytes = Buffer.from(signature);
  const expectedBytes = Buffer.from(expected);
  return (
    actualBytes.length === expectedBytes.length &&
    timingSafeEqual(actualBytes, expectedBytes)
  );
}

export function deriveRazorpayEventId(
  event: RazorpayWebhookEvent,
  eventType: string,
  eventHeaderId?: string | null,
): string {
  const headerId = nonEmptyString(eventHeaderId);
  if (headerId) return headerId;

  const payloadEventId = nonEmptyString(event.id);
  if (payloadEventId) return payloadEventId;

  const paymentEntity = event.payload?.payment?.entity;
  const paymentId = nonEmptyString(paymentEntity?.id) ?? "unknown-payment";
  const orderId = nonEmptyString(paymentEntity?.order_id) ?? "unknown-order";
  if (paymentId === "unknown-payment" && orderId === "unknown-order") {
    throw new Error("missing_event_identity");
  }

  // Razorpay can reuse the payment ID for authorized and captured events.
  // Including the event type makes the fallback identity event-specific.
  return `${eventType}:${paymentId}:${orderId}`;
}

export function confirmationRpcArgs(input: {
  bookingId: string;
  userId: string;
  paymentId: string;
}): Record<string, string> {
  return {
    p_booking_id: input.bookingId,
    p_user_id: input.userId,
    p_payment_ref: input.paymentId,
    p_payment_method: "Razorpay",
  };
}
