/// Lifecycle status of a payment row in the `payments` table.
enum PaymentStatus {
  pending,
  captured,
  failed,
  refunded;

  static PaymentStatus fromDb(String value) => switch (value) {
        'pending' => PaymentStatus.pending,
        'captured' => PaymentStatus.captured,
        'failed' => PaymentStatus.failed,
        'refunded' => PaymentStatus.refunded,
        _ => PaymentStatus.pending,
      };

  String get dbValue => switch (this) {
        PaymentStatus.pending => 'pending',
        PaymentStatus.captured => 'captured',
        PaymentStatus.failed => 'failed',
        PaymentStatus.refunded => 'refunded',
      };
}

/// A payment order generated for Razorpay checkout.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    this.keyId,
    this.notes,
  });

  final String orderId;
  final double amount;
  final String currency;
  final String? keyId;
  final Map<String, dynamic>? notes;

  factory PaymentOrder.fromResponse(Map<String, dynamic> json) => PaymentOrder(
        orderId: (json['order_id'] ?? json['id']) as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'INR',
        keyId: json['key_id'] as String?,
        notes: json['notes'] is Map<String, dynamic>
            ? json['notes'] as Map<String, dynamic>
            : null,
      );

  factory PaymentOrder.fromJson(Map<String, dynamic> json) =>
      PaymentOrder.fromResponse(json);

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'amount': amount,
        'currency': currency,
        if (keyId != null) 'key_id': keyId,
        if (notes != null) 'notes': notes,
      };
}

/// A completed or attempted payment transaction in `payments`.
class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    this.userId = '',
    this.provider = 'razorpay',
    this.providerOrderId,
    this.providerPaymentId,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.method,
    this.isRefundable = true,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookingId;
  final String userId;
  final String provider;
  final String? providerOrderId;
  final String? providerPaymentId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? method;
  final bool isRefundable;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String? ?? '',
        bookingId: json['booking_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        provider: json['provider'] as String? ?? 'razorpay',
        providerOrderId: json['provider_order_id'] as String?,
        providerPaymentId: json['provider_payment_id'] as String?,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'INR',
        status: PaymentStatus.fromDb(json['status'] as String? ?? 'pending'),
        method: json['method'] as String?,
        isRefundable: json['is_refundable'] as bool? ?? true,
        metadata: json['metadata'] is Map<String, dynamic>
            ? json['metadata'] as Map<String, dynamic>
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'user_id': userId,
        'provider': provider,
        'provider_order_id': providerOrderId,
        'provider_payment_id': providerPaymentId,
        'amount': amount,
        'currency': currency,
        'status': status.dbValue,
        'method': method,
        'is_refundable': isRefundable,
        'metadata': metadata,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// A refund record from the `refunds` table.
class Refund {
  const Refund({
    required this.id,
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.status,
    this.reason = '',
    this.providerRefundId,
    this.processedAt,
    this.createdAt,
  });

  final String id;
  final String paymentId;
  final String bookingId;
  final double amount;
  final String status;
  final String reason;
  final String? providerRefundId;
  final DateTime? processedAt;
  final DateTime? createdAt;

  factory Refund.fromResponse(Map<String, dynamic> json) => Refund(
        id: json['id'] as String? ?? '',
        paymentId: json['payment_id'] as String? ?? '',
        bookingId: json['booking_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'requested',
        reason: json['reason'] as String? ?? '',
        providerRefundId: json['provider_refund_id'] as String?,
        processedAt: DateTime.tryParse(json['processed_at'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  factory Refund.fromJson(Map<String, dynamic> json) =>
      Refund.fromResponse(json);

  Map<String, dynamic> toJson() => {
        'id': id,
        'payment_id': paymentId,
        'booking_id': bookingId,
        'amount': amount,
        'status': status,
        'reason': reason,
        'provider_refund_id': providerRefundId,
        'processed_at': processedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}

/// Payment method options matching Android's configurable methods.
enum PaymentMethodType {
  razorpayCheckout('⚡ Razorpay Standard Checkout', 'All cards, UPI, net banking, wallets'),
  upiGpay('📱 UPI (Google Pay, PhonePe, Paytm)', 'Instant approval via UPI apps'),
  creditDebitCard('💳 Credit / Debit Card', 'Visa, Mastercard, RuPay & Amex'),
  netBanking('🏦 Net Banking', 'All major Indian banks supported'),
  payAtVenue('🏢 Pay at Venue / Desk', 'Zero upfront payment, pay on arrival'),
  splitAdvanceToken('🪙 Split Advance Token (20%)', 'Pay 20% advance now, remaining at venue');

  const PaymentMethodType(this.title, this.subtitle);

  final String title;
  final String subtitle;
}
