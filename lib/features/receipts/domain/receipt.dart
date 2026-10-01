import 'package:intl/intl.dart';

/// Currency symbols for the codes this platform actually trades in.
///
/// Falls back to the ISO code itself rather than guessing, so an unlisted
/// currency renders as "SGD 1,200.00" instead of a wrong symbol.
const Map<String, String> _currencySymbols = <String, String>{
  'INR': '\u20B9',
  'USD': r'$',
  'EUR': '\u20AC',
  'GBP': '\u00A3',
  'AED': '\u062F.\u0625',
  'SGD': r'S$',
};

String currencySymbol(String currency) =>
    _currencySymbols[currency.toUpperCase()] ?? '${currency.toUpperCase()} ';

/// Formats a receipt amount.
///
/// `en_IN` grouping (lakh/crore) is used for every currency: this is an Indian
/// marketplace, the amounts are authored in rupees, and mixed grouping on one
/// document would be worse than consistent grouping.
String formatReceiptMoney(double amount, String currency) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: currencySymbol(currency),
    decimalDigits: 2,
  ).format(amount);
}

/// One printed line of a receipt.
class ReceiptRow {
  const ReceiptRow({
    required this.label,
    required this.amount,
    this.isCredit = false,
  });

  final String label;

  /// Always a positive magnitude. [isCredit] carries the sign, so a discount is
  /// never accidentally added.
  final double amount;

  /// True for lines that reduce what is owed (discounts, credit notes).
  final bool isCredit;

  double get signedAmount => isCredit ? -amount : amount;
}

/// The itemized components of a receipt.
class ReceiptLineItems {
  const ReceiptLineItems({
    required this.baseAmount,
    required this.taxAmount,
    required this.discountAmount,
    this.taxRateReference,
    this.platformFee,
  });

  final double baseAmount;
  final double taxAmount;
  final double discountAmount;

  /// The venue's configured rate, for reference only.
  ///
  /// Deliberately not used to re-derive [taxAmount]: a receipt states the tax
  /// that was charged, and re-deriving it would let a later venue price edit
  /// change a document that has already been issued.
  final double? taxRateReference;

  /// Null when no platform fee is recorded for this booking.
  ///
  /// `public.platform_commissions` is created by the schema and has no writer
  /// anywhere, so this is null in practice. The row is omitted rather than
  /// printed as zero, because a "Platform fee 0.00" line on a tax document
  /// asserts a fact nobody recorded.
  final double? platformFee;

  /// The charge lines, in print order. Empty-valued lines are omitted.
  List<ReceiptRow> rows() {
    final rows = <ReceiptRow>[
      ReceiptRow(label: 'Base amount', amount: baseAmount),
    ];

    if (discountAmount > 0) {
      rows.add(ReceiptRow(
        label: 'Discount',
        amount: discountAmount,
        isCredit: true,
      ));
    }

    if (taxAmount > 0) {
      rows.add(ReceiptRow(label: 'Taxes', amount: taxAmount));
    }

    final fee = platformFee;
    if (fee != null && fee > 0) {
      rows.add(ReceiptRow(label: 'Platform fee', amount: fee));
    }

    return rows;
  }

  /// Sum of [rows], recomputed here so a receipt never relies on the server's
  /// own arithmetic to decide whether it adds up.
  double get componentTotal =>
      rows().fold(0.0, (sum, row) => sum + row.signedAmount);

  factory ReceiptLineItems.fromJson(Map<String, dynamic> json) {
    return ReceiptLineItems(
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      taxRateReference: (json['tax_rate_reference'] as num?)?.toDouble(),
      platformFee: (json['platform_fee'] as num?)?.toDouble(),
    );
  }
}

/// Venue details as they were at the moment the receipt was issued.
class ReceiptVenue {
  const ReceiptVenue({
    required this.name,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  final String name;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  /// Single-line address, skipping the parts that were never recorded.
  String get formattedAddress {
    final parts = <String>[
      if (_has(addressLine1)) addressLine1!,
      if (_has(addressLine2)) addressLine2!,
      if (_has(city)) city!,
      if (_has(state)) state!,
      if (_has(postalCode)) postalCode!,
      if (_has(country)) country!,
    ];
    return parts.join(', ');
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  factory ReceiptVenue.fromJson(Map<String, dynamic> json) => ReceiptVenue(
        name: json['name'] as String? ?? '',
        addressLine1: json['address_line1'] as String?,
        addressLine2: json['address_line2'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        postalCode: json['postal_code'] as String?,
        country: json['country'] as String?,
      );
}

/// The booked slot.
class ReceiptSlot {
  const ReceiptSlot({
    this.label,
    this.bookDate,
    this.startTime,
    this.endTime,
    this.quantity,
  });

  final String? label;
  final DateTime? bookDate;
  final String? startTime;
  final String? endTime;
  final int? quantity;

  factory ReceiptSlot.fromJson(Map<String, dynamic> json) => ReceiptSlot(
        label: json['label'] as String?,
        bookDate: DateTime.tryParse(json['book_date']?.toString() ?? ''),
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        quantity: (json['quantity'] as num?)?.toInt(),
      );
}

/// Who the booking was for.
class ReceiptGuest {
  const ReceiptGuest({this.name, this.email, this.phone});

  final String? name;
  final String? email;
  final String? phone;

  factory ReceiptGuest.fromJson(Map<String, dynamic> json) => ReceiptGuest(
        name: json['name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

/// A complete receipt document.
///
/// Built from the frozen snapshot the server writes on first issue, so the same
/// booking always renders the same receipt.
class ReceiptDocument {
  const ReceiptDocument({
    required this.bookingId,
    required this.bookingRef,
    required this.status,
    required this.currency,
    required this.venue,
    required this.slot,
    required this.guest,
    required this.lineItems,
    required this.totalPaid,
    this.paymentRef,
    this.paymentProvider,
    this.paymentMethod,
    this.issuedAt,
    this.omissions = const <String>[],
  });

  final String bookingId;
  final String bookingRef;
  final String status;
  final String currency;
  final ReceiptVenue venue;
  final ReceiptSlot slot;
  final ReceiptGuest guest;
  final ReceiptLineItems lineItems;

  /// The amount actually charged. Authoritative — the line items are a
  /// breakdown of it, never a replacement for it.
  final double totalPaid;

  final String? paymentRef;
  final String? paymentProvider;
  final String? paymentMethod;
  final DateTime? issuedAt;

  /// Deliberately no `receiptNumber` here. The snapshot is built before the
  /// `booking_receipts` row exists, so it cannot carry the number; the server
  /// returns that alongside the document instead. It lives on [ReceiptResult],
  /// where it can actually be populated — a field on this class would only ever
  /// read null and invite a screen to print "no receipt number" for a booking
  /// that has one.

  /// Receipt fields the schema has no data for. Currently `platform_fee`.
  final List<String> omissions;

  /// True when the printed rows add up to [totalPaid].
  ///
  /// Recomputed on the client rather than trusting the server's `reconciles`
  /// flag, so a breakdown that does not add up is surfaced instead of printed
  /// as if it were correct.
  bool get lineItemsReconcile =>
      (lineItems.componentTotal - totalPaid).abs() < 0.005;

  /// How far the components are from the charged total, in [currency].
  double get unreconciledDifference => totalPaid - lineItems.componentTotal;

  /// Whether the platform fee could not be itemised, so a caller can explain a
  /// difference instead of leaving it looking like an arithmetic error.
  bool get platformFeeOmitted => omissions.contains('platform_fee');

  String formatMoney(double amount) => formatReceiptMoney(amount, currency);

  factory ReceiptDocument.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) {
      final value = json[key];
      return value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
    }

    final omissionsRaw = json['omissions'];

    return ReceiptDocument(
      bookingId: json['booking_id'] as String? ?? '',
      bookingRef: json['booking_ref'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currency: json['currency'] as String? ?? 'INR',
      paymentRef: json['payment_ref'] as String?,
      paymentProvider: json['payment_provider'] as String?,
      paymentMethod: json['payment_method'] as String?,
      venue: ReceiptVenue.fromJson(sub('venue')),
      slot: ReceiptSlot.fromJson(sub('slot')),
      guest: ReceiptGuest.fromJson(sub('guest')),
      lineItems: ReceiptLineItems.fromJson(sub('line_items')),
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? ''),
      omissions: omissionsRaw is List
          ? omissionsRaw.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }
}

/// The server's answer to `issue_booking_receipt`.
class ReceiptResult {
  const ReceiptResult({
    required this.document,
    required this.receiptIssued,
    this.receiptNumber,
    this.message,
  });

  final ReceiptDocument document;

  /// False when no payment is recorded, so no receipt number could be issued.
  /// The breakdown is still real, but the document is a statement, not a
  /// receipt, and must be labelled as such.
  final bool receiptIssued;

  final String? receiptNumber;
  final String? message;
}
