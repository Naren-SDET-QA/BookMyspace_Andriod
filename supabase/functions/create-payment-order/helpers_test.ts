import {
  buildClientOrderResponse,
  buildPendingPaymentRecord,
} from "./helpers.ts";

Deno.test("payment persistence uses the server booking amount", () => {
  const row = buildPendingPaymentRecord({
    bookingId: "booking-1",
    userId: "user-1",
    providerOrderId: "order-1",
    amount: 4720,
    currency: "INR",
  });

  if (row.amount !== 4720 || row.status !== "pending") {
    throw new Error("The pending payment row was not server-authoritative");
  }
  if (row.user_id !== "user-1" || row.booking_id !== "booking-1") {
    throw new Error("Payment ownership was not retained");
  }
});

Deno.test("client order response contains no server secret", () => {
  const response = buildClientOrderResponse({
    orderId: "order-1",
    amount: 4720,
    currency: "INR",
    publicKeyId: "rzp_test_public",
    bookingId: "booking-1",
  });
  const serialized = JSON.stringify(response);

  if (response.key_id !== "rzp_test_public") {
    throw new Error("The public Razorpay key was not returned");
  }
  if (
    serialized.includes("RAZORPAY_KEY_SECRET") ||
    serialized.includes("SUPABASE_SERVICE_ROLE_KEY")
  ) {
    throw new Error("A server secret appeared in the client response");
  }
});
