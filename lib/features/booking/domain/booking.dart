/// A bookable time slot for a venue (`time_slots`).
class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.venueId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    this.isActive = true,
  });

  final String id;
  final String venueId;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isActive;

  /// "09:00:00" -> "09:00" for display.
  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;

  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: json['id'] as String? ?? '',
        venueId: json['venue_id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        priceAmount: (json['price_amount'] as num?)?.toDouble() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Availability of a single slot, returned by `available_time_slots`.
class SlotAvailability {
  const SlotAvailability({
    required this.slotId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    required this.isAvailable,
    required this.reason,
  });

  final String slotId;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isAvailable;
  final String reason;

  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory SlotAvailability.fromJson(Map<String, dynamic> json) =>
      SlotAvailability(
        slotId: json['slot_id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        priceAmount: (json['price_amount'] as num?)?.toDouble() ?? 0,
        isAvailable: json['is_available'] as bool? ?? false,
        reason: json['reason'] as String? ?? 'unavailable',
      );
}

/// Lifecycle status of a booking (`booking_status` enum).
enum BookingStatus {
  held,
  pending,
  awaitingOwnerApproval,
  pendingOwnerApproval,
  ownerRejected,
  approvalExpired,
  confirmed,
  completed,
  cancelled,
  refunded,
  rejected,
  noShow,
  unknown;

  static BookingStatus fromDb(String value) => switch (value) {
        'held' => BookingStatus.held,
        'pending' => BookingStatus.pending,
        'awaiting_owner_approval' => BookingStatus.awaitingOwnerApproval,
        'pending_owner_approval' => BookingStatus.pendingOwnerApproval,
        'owner_rejected' => BookingStatus.ownerRejected,
        'approval_expired' => BookingStatus.approvalExpired,
        'confirmed' => BookingStatus.confirmed,
        'completed' => BookingStatus.completed,
        'cancelled' => BookingStatus.cancelled,
        'refunded' => BookingStatus.refunded,
        'rejected' => BookingStatus.rejected,
        'no_show' => BookingStatus.noShow,
        _ => BookingStatus.unknown,
      };

  String get dbValue => switch (this) {
        BookingStatus.held => 'held',
        BookingStatus.pending => 'pending',
        BookingStatus.awaitingOwnerApproval => 'awaiting_owner_approval',
        BookingStatus.pendingOwnerApproval => 'pending_owner_approval',
        BookingStatus.ownerRejected => 'owner_rejected',
        BookingStatus.approvalExpired => 'approval_expired',
        BookingStatus.confirmed => 'confirmed',
        BookingStatus.completed => 'completed',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.refunded => 'refunded',
        BookingStatus.rejected => 'rejected',
        BookingStatus.noShow => 'no_show',
        BookingStatus.unknown => 'unknown',
      };

  /// Waiting for the venue owner, under either lineage's status name.
  bool get isAwaitingOwner =>
      this == BookingStatus.awaitingOwnerApproval ||
      this == BookingStatus.pendingOwnerApproval;

  /// Declined by the venue owner, under either lineage's status name.
  bool get isOwnerRejected =>
      this == BookingStatus.ownerRejected || this == BookingStatus.rejected;
}

/// A booking made by the user (or recorded offline by an owner).
class Booking {
  const Booking({
    required this.id,
    required this.bookingRef,
    required this.venueId,
    required this.slotId,
    required this.bookDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    this.discountAmount = 0,
    this.venueName = '',
    this.venueCity = '',
    this.slotLabel = '',
    this.createdAt,
    this.approvalRequired = true,
    this.approvalRequestedAt,
    this.approvalExpiresAt,
    this.approvedAt,
    this.paymentExpiresAt,
    this.rejectionReason,
    this.receiptNumber,
    this.receiptIssuedAt,
    this.customerName = '',
    this.customerPhone = '',
    this.isOffline = false,
    this.paymentMethod = '',
    this.paymentRef = '',
    this.paidAt,
    this.metadata = const {},
  });

  final String id;
  final String bookingRef;
  final String venueId;
  final String slotId;
  final DateTime bookDate;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final double amount;
  final double taxAmount;
  final double totalAmount;

  /// Discount applied by a redeemed coupon (0 when none). Always the
  /// server-computed value persisted on the `bookings` row — never
  /// derived on the client.
  final double discountAmount;

  /// Hydrated venue display fields (empty when not joined).
  final String venueName;
  final String venueCity;
  final String slotLabel;
  final DateTime? createdAt;
  final bool approvalRequired;
  final DateTime? approvalRequestedAt;
  final DateTime? approvalExpiresAt;
  final DateTime? approvedAt;
  final DateTime? paymentExpiresAt;
  final String? rejectionReason;
  final String? receiptNumber;
  final DateTime? receiptIssuedAt;

  /// Customer fields recorded on offline (walk-in) bookings.
  final String customerName;
  final String customerPhone;
  final bool isOffline;

  /// Payment details (hydrated from the `payments` embed).
  final String paymentMethod;
  final String paymentRef;
  final DateTime? paidAt;

  /// Raw `metadata` jsonb, e.g. guests / sharing / deposit info.
  final Map<String, dynamic> metadata;

  /// Server hold-expiry timestamp when the pending booking is still held.
  DateTime? get holdExpiresAt {
    final raw = metadata['hold_expires_at'];
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }

  bool get isActive =>
      status == BookingStatus.pending ||
      status == BookingStatus.awaitingOwnerApproval ||
      status == BookingStatus.confirmed ||
      status == BookingStatus.held;

  bool get canCancel =>
      status == BookingStatus.held ||
      status == BookingStatus.awaitingOwnerApproval ||
      status == BookingStatus.pending;

  /// Payable once the owner approved (main flow); held bookings are payable
  /// directly (release/v1.0 hold flow).
  bool get canPay =>
      status == BookingStatus.held ||
      (status == BookingStatus.pending && approvedAt != null);

  /// release/v1.0 rule used by the v1 screens: held and pending bookings go
  /// straight to server-verified checkout (that flow has no approval gate).
  bool get canPayDirect =>
      status == BookingStatus.pending || status == BookingStatus.held;


  /// Confirmed (captured) bookings can be refunded.
  bool get canRefund => status == BookingStatus.confirmed;

  /// Bookings a customer may want to repeat.
  ///
  /// "Book again" is an offer, not a capability: it only opens the standard
  /// booking flow, where availability, holds and owner approval are
  /// recomputed server-side. Offered for finished-or-abandoned bookings —
  /// statuses with no remaining lifecycle action of their own.
  bool get canBookAgain =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.completed ||
      status == BookingStatus.cancelled ||
      status == BookingStatus.refunded ||
      status == BookingStatus.ownerRejected ||
      status == BookingStatus.rejected ||
      status == BookingStatus.approvalExpired;

  /// Bookings whose payment was captured can produce an itemized receipt.
  ///
  /// Mirrors the gate in `public.issue_booking_receipt`, which refuses every
  /// other status on the grounds that a receipt is evidence of payment. Kept in
  /// step with the migration deliberately: offering a button that always fails
  /// server-side is worse than not offering it.
  bool get canViewReceipt =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.completed ||
      status == BookingStatus.refunded;

  /// Only confirmed and completed bookings can be exported to a calendar.
  ///
  /// A cancelled/rejected/expired booking should not appear in the user's
  /// calendar — exporting it would create a false commitment. Held/pending
  /// bookings are not yet final and may be cancelled by the system.
  bool get canExportCalendar =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.completed;
  /// An invoice is available for paid/terminal bookings.
  bool get canViewInvoice =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.completed ||
      status == BookingStatus.refunded ||
      status == BookingStatus.noShow;

  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final venueRaw = json['venues'];
    final slotRaw = json['time_slots'];
    final receiptValue = json['booking_receipts'];
    final receiptRaw = receiptValue is Map
        ? Map<String, dynamic>.from(receiptValue)
        : receiptValue is List &&
                receiptValue.isNotEmpty &&
                receiptValue.first is Map
            ? Map<String, dynamic>.from(receiptValue.first as Map)
            : null;
    final paymentsRaw = json['payments'];
    final payment = paymentsRaw is List && paymentsRaw.isNotEmpty
        ? paymentsRaw.first is Map
              ? Map<String, dynamic>.from(paymentsRaw.first as Map)
              : null
        : paymentsRaw is Map
        ? Map<String, dynamic>.from(paymentsRaw as Map)
        : null;
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw as Map)
        : const <String, dynamic>{};
    return Booking(
      id: json['id'] as String? ?? '',
      bookingRef: json['booking_ref'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      slotId: json['slot_id'] as String? ?? '',
      bookDate: DateTime.tryParse(json['book_date'] as String? ?? '') ??
          DateTime(1970),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: BookingStatus.fromDb(json['status'] as String? ?? 'unknown'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      venueName: venueRaw is Map<String, dynamic>
          ? (venueRaw['name'] as String? ?? '')
          : '',
      venueCity: venueRaw is Map<String, dynamic>
          ? (venueRaw['city'] as String? ?? '')
          : '',
      slotLabel: slotRaw is Map<String, dynamic>
          ? (slotRaw['label'] as String? ?? '')
          : '',
      approvalRequired: json['approval_required'] as bool? ?? true,
      approvalRequestedAt:
          DateTime.tryParse(json['approval_requested_at'] as String? ?? ''),
      approvalExpiresAt:
          DateTime.tryParse(json['approval_expires_at'] as String? ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
      paymentExpiresAt:
          DateTime.tryParse(json['payment_expires_at'] as String? ?? ''),
      rejectionReason: json['rejection_reason'] as String?,
      receiptNumber: receiptRaw?['receipt_number'] as String?,
      receiptIssuedAt: DateTime.tryParse(
        receiptRaw?['issued_at'] as String? ?? '',
      ),
      customerName: metadata['customer_name'] as String? ?? '',
      customerPhone: metadata['customer_phone'] as String? ?? '',
      isOffline: metadata['offline_booking'] == true,
      paymentMethod: payment?['method'] as String? ?? '',
      paymentRef: payment?['provider_payment_id'] as String? ?? '',
      paidAt: payment?['created_at'] != null
          ? DateTime.tryParse(payment!['created_at'] as String? ?? '')
          : null,
      metadata: metadata,
    );
  }
}

/// Result of a successfully acquired booking hold.
class BookingHold {
  const BookingHold({
    required this.id,
    required this.expiresAt,
    this.bookingId,
    this.status,
    this.totalAmount,
  });

  final String id;
  final DateTime expiresAt;
  final String? bookingId;
  final String? status;
  final double? totalAmount;

  factory BookingHold.fromResponse(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final expiresIn = (json['expires_in_minutes'] as num?)?.toInt() ?? 10;
    final parsed = DateTime.tryParse(
      json['approval_expires_at'] as String? ??
          json['expires_at'] as String? ??
          '',
    );
    final expiresAt = parsed?.toLocal() ??
        (now ?? DateTime.now()).add(Duration(minutes: expiresIn));
    return BookingHold(
      id: json['hold_id'] as String? ?? '',
      expiresAt: expiresAt,
      bookingId: json['booking_id'] as String?,
      status: json['status'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
    );
  }

  bool isExpired([DateTime? now]) => !((now ?? DateTime.now()).isBefore(expiresAt));

  Duration remaining([DateTime? now]) {
    final left = expiresAt.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

/// Formats a hold countdown from the server expiry timestamp.
class HoldCountdown {
  static String format(Duration remaining) {
    final total = remaining.inSeconds;
    if (total <= 0) return '00:00';
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
