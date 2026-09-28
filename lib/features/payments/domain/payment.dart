import '../../../core/errors/app_exceptions.dart' as app_errors;

/// Lifecycle status of a payment row in the `payments` table.
enum PaymentStatus {
  pending,
  authorized,
  captured,
  failed,
  refunded,
  partiallyRefunded;

  static PaymentStatus fromDb(String value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'authorized' => PaymentStatus.authorized,
    'captured' => PaymentStatus.captured,
    'failed' => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    'partially_refunded' => PaymentStatus.partiallyRefunded,
    _ => PaymentStatus.pending,
  };

  String get dbValue => switch (this) {
    PaymentStatus.pending => 'pending',
    PaymentStatus.authorized => 'authorized',
    PaymentStatus.captured => 'captured',
    PaymentStatus.failed => 'failed',
    PaymentStatus.refunded => 'refunded',
    PaymentStatus.partiallyRefunded => 'partially_refunded',
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
    this.paymentPlan = 'full',
    this.fullAmount,
    this.advanceAmount,
    this.balanceDue,
    this.walletCreditAmount = 0,
    this.walletOnly = false,
  });

  final String orderId;
  final double amount;
  final String currency;
  final String? keyId;
  final Map<String, dynamic>? notes;
  final String paymentPlan;
  final double? fullAmount;
  final double? advanceAmount;
  final double? balanceDue;
  final double walletCreditAmount;
  final bool walletOnly;

  factory PaymentOrder.fromResponse(Map<String, dynamic> json) => PaymentOrder(
    orderId: (json['order_id'] ?? json['id']) as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    currency: json['currency'] as String? ?? 'INR',
    keyId: json['key_id'] as String?,
    notes: json['notes'] is Map<String, dynamic>
        ? json['notes'] as Map<String, dynamic>
        : null,
    paymentPlan: json['payment_plan'] as String? ?? 'full',
    fullAmount: (json['full_amount'] as num?)?.toDouble(),
    advanceAmount: (json['advance_amount'] as num?)?.toDouble(),
    balanceDue: (json['balance_due'] as num?)?.toDouble(),
    walletCreditAmount: (json['wallet_credit_amount'] as num?)?.toDouble() ?? 0,
    walletOnly: json['wallet_only'] as bool? ?? false,
  );

  factory PaymentOrder.fromJson(Map<String, dynamic> json) =>
      PaymentOrder.fromResponse(json);

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'amount': amount,
    'currency': currency,
    if (keyId != null) 'key_id': keyId,
    if (notes != null) 'notes': notes,
    'payment_plan': paymentPlan,
    if (fullAmount != null) 'full_amount': fullAmount,
    if (advanceAmount != null) 'advance_amount': advanceAmount,
    if (balanceDue != null) 'balance_due': balanceDue,
    'wallet_credit_amount': walletCreditAmount,
    'wallet_only': walletOnly,
  };
}

/// Server-authoritative checkout quote. The client may display these values,
/// but the Edge Function recalculates them again when the order is created.
class CheckoutQuote {
  const CheckoutQuote({
    required this.bookingId,
    required this.currency,
    required this.paymentPlan,
    required this.fullAmount,
    required this.advanceAmount,
    required this.balanceDue,
    required this.advanceEnabled,
    required this.minimumAdvanceAmount,
    this.walletEnabled = false,
    this.walletBalance = 0,
  });

  final String bookingId;
  final String currency;
  final String paymentPlan;
  final double fullAmount;
  final double advanceAmount;
  final double balanceDue;
  final bool advanceEnabled;
  final double minimumAdvanceAmount;
  final bool walletEnabled;
  final double walletBalance;

  double get payableAmount => advanceAmount;

  factory CheckoutQuote.fromResponse(Map<String, dynamic> json) =>
      CheckoutQuote(
        bookingId: json['booking_id'] as String? ?? '',
        currency: json['currency'] as String? ?? 'INR',
        paymentPlan: json['payment_plan'] as String? ?? 'full',
        fullAmount: (json['full_amount'] as num?)?.toDouble() ?? 0,
        advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0,
        balanceDue: (json['balance_due'] as num?)?.toDouble() ?? 0,
        advanceEnabled: json['advance_enabled'] as bool? ?? false,
        minimumAdvanceAmount:
            (json['minimum_advance_amount'] as num?)?.toDouble() ?? 0,
        walletEnabled: json['wallet_enabled'] as bool? ?? false,
        walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
      );
}

class VenuePaymentRules {
  const VenuePaymentRules({
    this.allowPayAtVenue = false,
    this.onlineEnabled = true,
    this.disabledPaymentMethods = const {},
  });

  final bool allowPayAtVenue;
  final bool onlineEnabled;
  final Set<String> disabledPaymentMethods;

  bool allows(PaymentMethodType method) => switch (method) {
    PaymentMethodType.razorpayCheckout =>
      onlineEnabled && !disabledPaymentMethods.contains('razorpay'),
    PaymentMethodType.payAtVenue =>
      allowPayAtVenue && !disabledPaymentMethods.contains('pay_at_venue'),
  };

  factory VenuePaymentRules.fromResponse(Map<String, dynamic> json) {
    final raw = json['disabled_payment_methods'];
    return VenuePaymentRules(
      allowPayAtVenue: json['allow_pay_at_venue'] as bool? ?? false,
      onlineEnabled: json['online_enabled'] as bool? ?? true,
      disabledPaymentMethods: raw is List
          ? raw.whereType<String>().toSet()
          : const {},
    );
  }
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
    // Explicit column wins; otherwise only captured money is refundable.
    isRefundable:
        json['is_refundable'] as bool? ??
        _refundableStatus(
          PaymentStatus.fromDb(json['status'] as String? ?? 'pending'),
        ),
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

  /// Parses the response of the `create-refund` Edge Function.
  factory Refund.fromResponse(Object? json) {
    if (json is Map<String, dynamic>) return Refund.fromJson(json);
    throw const app_errors.SerializationException(
      'Could not read the refund response.',
    );
  }

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
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

/// Payment method supported by the currently deployed payment flow.
///
/// Razorpay Checkout itself provides the available UPI, card and net-banking
/// choices. Keeping one client method prevents unsupported client-only
/// payment promises from being shown as completed bookings.
enum PaymentMethodType {
  razorpayCheckout(
    '⚡ Razorpay Standard Checkout',
    'All cards, UPI, net banking, wallets',
  ),
  payAtVenue('Pay at venue', 'Pay the venue owner at the scheduled visit');

  const PaymentMethodType(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

bool _refundableStatus(PaymentStatus status) =>
    status == PaymentStatus.captured ||
    status == PaymentStatus.partiallyRefunded;
