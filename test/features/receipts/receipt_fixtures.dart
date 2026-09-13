import 'package:bookmyspace/features/receipts/domain/receipt.dart';

/// The exact JSON shape `public.issue_booking_receipt` returns.
///
/// Kept in one place so the client's parsing contract is pinned to the
/// migration rather than to the client's own idea of the payload. When the
/// migration changes shape, these fixtures are what should have to change.
Map<String, dynamic> serverDocument({
  String bookingId = '8f14e45f-ceea-467a-9c1c-3d6f1a2b4c5d',
  String bookingRef = 'BMS-883921',
  String status = 'confirmed',
  String currency = 'INR',
  double base = 1500,
  double tax = 270,
  double discount = 0,
  double total = 1770,
  double? taxRate = 18,
  String? paymentRef = 'pay_dev_test_001',
  String? paymentProvider = 'razorpay',
  String? paymentMethod = 'upi',
  String? issuedAt = '2026-09-01T09:30:00.000Z',
  List<String> omissions = const ['platform_fee'],
}) {
  return <String, dynamic>{
    'snapshot_version': 1,
    'booking_id': bookingId,
    'booking_ref': bookingRef,
    'status': status,
    'currency': currency,
    'payment_ref': paymentRef,
    'payment_provider': paymentProvider,
    'payment_method': paymentMethod,
    'venue': <String, dynamic>{
      'name': 'Indiranagar Rooftop Arena',
      'address_line1': '12th Main Road',
      'address_line2': 'Indiranagar',
      'city': 'Bengaluru',
      'state': 'Karnataka',
      'postal_code': '560038',
      'country': 'IN',
    },
    'slot': <String, dynamic>{
      'label': 'Evening Prime',
      'book_date': '2026-09-20',
      'start_time': '18:00:00',
      'end_time': '19:00:00',
      'quantity': 1,
    },
    'guest': <String, dynamic>{
      'name': 'Asha Menon',
      'email': 'asha@example.com',
      'phone': '+91 98450 12345',
    },
    'line_items': <String, dynamic>{
      'base_amount': base,
      'tax_amount': tax,
      'tax_rate_reference': taxRate,
      'discount_amount': discount,
      'platform_fee': null,
    },
    'total_paid': total,
    'computed_subtotal': base + tax - discount,
    'reconciles': (base + tax - discount) == total,
    'omissions': omissions,
    'issued_at': issuedAt,
  };
}

/// The `issue_booking_receipt` envelope, with the document nested under it.
///
/// `receipt_number` deliberately sits beside `document`, not inside it: the
/// snapshot is built before the `booking_receipts` row exists, so it cannot
/// carry a number. Anything that reads a number off the document would always
/// read null.
Map<String, dynamic> serverEnvelope({
  bool success = true,
  bool receiptIssued = true,
  String? receiptNumber = 'BMS-R-4F2A9C1E7B45',
  String? message,
  Map<String, dynamic>? document,
  String? errorCode,
}) {
  return <String, dynamic>{
    'success': success,
    if (errorCode != null) 'error_code': errorCode,
    if (success) 'receipt_issued': receiptIssued,
    if (receiptNumber != null) 'receipt_number': receiptNumber,
    if (message != null) 'message': message,
    if (document != null) 'document': document,
  };
}

/// A parsed result, for the tests that do not care about the wire format.
ReceiptResult serverResult({
  bool receiptIssued = true,
  String? receiptNumber = 'BMS-R-4F2A9C1E7B45',
  String? message,
  Map<String, dynamic>? document,
}) {
  return ReceiptResult(
    document: ReceiptDocument.fromJson(document ?? serverDocument()),
    receiptIssued: receiptIssued,
    receiptNumber: receiptNumber,
    message: message,
  );
}
