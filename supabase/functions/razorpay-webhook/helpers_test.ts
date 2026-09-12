import { createHmac } from "node:crypto";

import {
  confirmationRpcArgs,
  deriveRazorpayEventId,
  verifyRazorpaySignature,
} from "./helpers.ts";

Deno.test("verifies the raw Razorpay webhook body signature", () => {
  const body = '{"event":"payment.captured"}';
  const secret = "webhook-test-secret";
  const signature = createHmac("sha256", secret).update(body).digest("hex");

  if (!verifyRazorpaySignature(body, signature, secret)) {
    throw new Error("A valid webhook signature was rejected");
  }
  if (verifyRazorpaySignature(body, "invalid", secret)) {
    throw new Error("An invalid webhook signature was accepted");
  }
});

Deno.test("prefers Razorpay event identity from the header or payload", () => {
  const event = {
    id: "payload-event-1",
    event: "payment.captured",
    payload: { payment: { entity: { id: "pay-1", order_id: "order-1" } } },
  };

  if (
    deriveRazorpayEventId(event, "payment.captured", "header-event-1") !==
      "header-event-1"
  ) {
    throw new Error("The Razorpay event header identity was ignored");
  }
  if (deriveRazorpayEventId(event, "payment.captured") !== "payload-event-1") {
    throw new Error("The payload event identity was ignored");
  }
});

Deno.test("fallback identity separates authorized and captured events", () => {
  const payment = {
    payload: { payment: { entity: { id: "pay-1", order_id: "order-1" } } },
  };
  const authorized = deriveRazorpayEventId(payment, "payment.authorized");
  const captured = deriveRazorpayEventId(payment, "payment.captured");

  if (authorized === captured) {
    throw new Error("Authorized and captured events share an idempotency key");
  }
});

Deno.test("confirmation uses the deployed venue booking RPC signature", () => {
  const args = confirmationRpcArgs({
    bookingId: "booking-1",
    userId: "user-1",
    paymentId: "pay-1",
  });

  if (
    args.p_booking_id !== "booking-1" ||
    args.p_user_id !== "user-1" ||
    args.p_payment_ref !== "pay-1" ||
    args.p_payment_method !== "Razorpay"
  ) {
    throw new Error("The deployed confirmation RPC arguments are incorrect");
  }
});
