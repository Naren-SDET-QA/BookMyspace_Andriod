import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/receipt.dart';
import '../domain/receipt_repository.dart';

/// Supabase-backed [ReceiptRepository].
///
/// The server is the only authority for what a receipt says: tax, totals and
/// the receipt number all come from `issue_booking_receipt`. This class maps
/// that response and never derives an amount locally.
class SupabaseReceiptRepository implements ReceiptRepository {
  SupabaseReceiptRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReceiptResult> issueReceipt(String bookingId) async {
    try {
      final response = await _client.rpc(
        'issue_booking_receipt',
        params: {'p_booking_id': bookingId},
      );
      final data = response is Map<String, dynamic> ? response : null;

      // The server owns the verdict. Surface its reason rather than collapsing
      // every outcome into one generic message.
      if (data == null || data['success'] != true) {
        throw app_errors.ServerException(
          data?['message']?.toString() ?? 'The receipt could not be loaded.',
          code: data?['error_code']?.toString().toLowerCase() ??
              'receipt_unavailable',
        );
      }

      final documentRaw = data['document'];
      if (documentRaw is! Map) {
        throw const app_errors.SerializationException(
          'The receipt response did not include a document.',
          code: 'receipt_malformed',
        );
      }

      return ReceiptResult(
        document:
            ReceiptDocument.fromJson(Map<String, dynamic>.from(documentRaw)),
        receiptIssued: data['receipt_issued'] == true,
        receiptNumber: data['receipt_number'] as String?,
        message: data['message'] as String?,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
