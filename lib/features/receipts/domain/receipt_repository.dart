import 'receipt.dart';

/// Reads itemized receipts.
///
/// Issuing is a server operation: the server owns tax, totals and the receipt
/// number, so this interface has no local fallback. A receipt that could not be
/// fetched from the server does not exist as far as the client is concerned.
abstract interface class ReceiptRepository {
  /// Returns the itemized receipt for [bookingId].
  ///
  /// Idempotent: the server issues the receipt on the first call and returns
  /// the same frozen document on every later call, so a receipt never changes
  /// after it has been shown to a customer.
  Future<ReceiptResult> issueReceipt(String bookingId);
}
