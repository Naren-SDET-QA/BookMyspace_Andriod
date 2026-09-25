import { Buffer } from "node:buffer";
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
    refund?: {
      entity?: {
        id?: unknown;
        payment_id?: unknown;
        amount?: unknown;
        status?: unknown;
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

  // Refund events carry their own provider-issued id, which is the most
  // specific identity available and is checked before falling back to the
  // payment/order composite (which refund events may not even carry).
  const refundEntity = event.payload?.refund?.entity;
  const refundId = nonEmptyString(refundEntity?.id);
  if (refundId) return refundId;

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

export function extractRefundEntity(event: RazorpayWebhookEvent): {
  id?: string;
  paymentId?: string;
  status?: string;
} {
  const entity = event.payload?.refund?.entity;
  return {
    id: nonEmptyString(entity?.id),
    paymentId: nonEmptyString(entity?.payment_id),
    status: nonEmptyString(entity?.status),
  };
}
