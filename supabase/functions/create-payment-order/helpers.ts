export type PendingPaymentRecordInput = {
  bookingId: string;
  userId: string;
  providerOrderId: string;
  amount: number;
  currency: string;
};

export function buildPendingPaymentRecord(
  input: PendingPaymentRecordInput,
): Record<string, unknown> {
  return {
    booking_id: input.bookingId,
    user_id: input.userId,
    provider: "razorpay",
    provider_order_id: input.providerOrderId,
    amount: input.amount,
    currency: input.currency,
    status: "pending",
  };
}

export function buildClientOrderResponse(input: {
  orderId: string;
  amount: number;
  currency: string;
  publicKeyId: string;
  bookingId: string;
}): Record<string, unknown> {
  return {
    order_id: input.orderId,
    amount: input.amount,
    currency: input.currency,
    key_id: input.publicKeyId,
    notes: {
      booking_id: input.bookingId,
    },
  };
}
