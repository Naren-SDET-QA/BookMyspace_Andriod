import 'package:bookmyspace/features/booking/domain/invoice_repository.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a server-generated invoice artifact and signed URL', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice': {'invoice_number': 'BMS-2026-ABC123'},
      'signed_url': 'https://example.test/signed-invoice',
    });

    expect(invoice.invoiceNumber, 'BMS-2026-ABC123');
    expect(invoice.invoiceId, isNull);
    expect(invoice.signedUrl, 'https://example.test/signed-invoice');
  });

  test('accepts a flat invoice response for backwards-compatible callers', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice_number': 'BMS-2026-FLAT',
    });

    expect(invoice.invoiceNumber, 'BMS-2026-FLAT');
    expect(invoice.signedUrl, isNull);
    expect(invoice.emailQueued, isFalse);
    expect(invoice.taxDetails, isNull);
  });

  test('parses server email_queued without client outbox writes', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice': {'invoice_number': 'BMS-2026-MAIL'},
      'signed_url': 'https://example.test/signed-invoice',
      'email_queued': true,
    });
    expect(invoice.emailQueued, isTrue);
  });

  test('parses server GST tax details without trusting client totals', () {
    final invoice = InvoiceArtifact.fromJson({
      'invoice': {'invoice_number': 'BMS-2026-GST'},
      'tax_details': {
        'tax_mode': 'cgst_sgst',
        'sac_code': '997212',
        'cgst_amount': 90,
        'sgst_amount': 90,
      },
    });
    expect(invoice.taxDetails?['tax_mode'], 'cgst_sgst');
    expect(invoice.taxDetails?['sac_code'], '997212');
  });
}
