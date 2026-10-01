import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice_repository.dart';

class SupabaseInvoiceRepository implements InvoiceRepository {
  SupabaseInvoiceRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<InvoiceArtifact> generate(String bookingId) async {
    final result = await _client.functions.invoke(
      'generate-invoice',
      body: {'booking_id': bookingId},
    );
    if (result.data is! Map) {
      throw StateError('Invoice generation returned an invalid response');
    }
    return InvoiceArtifact.fromJson(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  @override
  Future<bool> resend(String invoiceId, {String? recipientEmail}) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'resend_invoice_email',
      params: {'p_invoice_id': invoiceId, 'p_recipient_email': recipientEmail},
    );
    return result['queued'] == true || result['already_queued'] == true;
  }
}
