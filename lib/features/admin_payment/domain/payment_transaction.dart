/// A single read-only ledger row surfaced to Admin from the
/// `admin_list_payment_transactions` backend RPC. This model intentionally
/// excludes anything the backend RPC itself never returns (no secrets, no
/// signature material, no full customer PII) — the RPC is the authoritative
/// privacy boundary and this model simply mirrors its output.
class PaymentTransaction {
  const PaymentTransaction({
    required this.paymentId,
    required this.bookingId,
    required this.bookingReference,
    required this.venueId,
    required this.venueName,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.approvalStatus,
    required this.providerOrderId,
    required this.providerPaymentId,
    required this.webhookReceived,
    required this.reconciliationFlag,
    required this.paymentCreatedAt,
    required this.paymentUpdatedAt,
    required this.bookingCreatedAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      paymentId: json['payment_id'] as String,
      bookingId: json['booking_id'] as String,
      bookingReference: json['booking_reference'] as String? ?? '',
      venueId: json['venue_id'] as String?,
      venueName: json['venue_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? 'unknown',
      bookingStatus: json['booking_status'] as String? ?? 'unknown',
      approvalStatus: json['approval_status'] as String? ?? 'not_required',
      providerOrderId: json['provider_order_id'] as String?,
      providerPaymentId: json['provider_payment_id'] as String?,
      webhookReceived: json['webhook_received'] as bool? ?? false,
      reconciliationFlag: json['reconciliation_flag'] as String? ?? 'ok',
      paymentCreatedAt: DateTime.parse(json['payment_created_at'] as String),
      paymentUpdatedAt: json['payment_updated_at'] != null
          ? DateTime.tryParse(json['payment_updated_at'] as String)
          : null,
      bookingCreatedAt: json['booking_created_at'] != null
          ? DateTime.tryParse(json['booking_created_at'] as String)
          : null,
    );
  }

  final String paymentId;
  final String bookingId;
  final String bookingReference;
  final String? venueId;
  final String? venueName;
  final double amount;
  final String currency;
  final String paymentStatus;
  final String bookingStatus;
  final String approvalStatus;
  final String? providerOrderId;
  final String? providerPaymentId;
  final bool webhookReceived;
  final String reconciliationFlag;
  final DateTime paymentCreatedAt;
  final DateTime? paymentUpdatedAt;
  final DateTime? bookingCreatedAt;

  bool get hasReconciliationException => reconciliationFlag != 'ok';
}

/// A single page of the transaction ledger, including the server-computed
/// total row count so the UI can render pagination controls without
/// fetching every page.
class PaymentTransactionPage {
  const PaymentTransactionPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<PaymentTransaction> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => page * pageSize < totalCount;
  bool get hasPreviousPage => page > 1;
  int get totalPages =>
      totalCount == 0 ? 1 : ((totalCount + pageSize - 1) ~/ pageSize);
}

/// Filters accepted by the Transaction Ledger screen. Mirrors, 1:1, the
/// parameters accepted by the `admin_list_payment_transactions` RPC.
class PaymentTransactionFilter {
  const PaymentTransactionFilter({
    this.from,
    this.to,
    this.paymentStatus,
    this.bookingStatus,
    this.venueId,
    this.search,
  });

  final DateTime? from;
  final DateTime? to;
  final String? paymentStatus;
  final String? bookingStatus;
  final String? venueId;
  final String? search;

  PaymentTransactionFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? paymentStatus,
    String? bookingStatus,
    String? venueId,
    String? search,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearPaymentStatus = false,
    bool clearBookingStatus = false,
    bool clearVenueId = false,
    bool clearSearch = false,
  }) {
    return PaymentTransactionFilter(
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      paymentStatus:
          clearPaymentStatus ? null : (paymentStatus ?? this.paymentStatus),
      bookingStatus:
          clearBookingStatus ? null : (bookingStatus ?? this.bookingStatus),
      venueId: clearVenueId ? null : (venueId ?? this.venueId),
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}

/// The set of `payment_status` values the backend enum actually supports.
/// Kept in sync with the `payment_status` Postgres enum.
const List<String> kPaymentStatusValues = [
  'pending',
  'authorized',
  'captured',
  'failed',
  'refunded',
  'partially_refunded',
];

/// The set of `booking_status` values the backend enum actually supports.
/// Kept in sync with the `booking_status` Postgres enum.
const List<String> kBookingStatusValues = [
  'held',
  'pending',
  'confirmed',
  'completed',
  'cancelled',
  'refunded',
  'no_show',
  'awaiting_owner_approval',
  'owner_rejected',
  'approval_expired',
];
