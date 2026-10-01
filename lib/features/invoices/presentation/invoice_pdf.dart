import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/invoice.dart';
import '../domain/invoice_design.dart';

Future<Uint8List> buildInvoicePdf(InvoiceDocument invoice) async {
  final design = InvoiceDesign.parse(invoice.config['design_template']);
  final (header, headerText, band) = switch (design) {
    InvoiceDesign.modernTeal => (
      PdfColor.fromInt(0xFF0F766E),
      PdfColors.white,
      PdfColor.fromInt(0xFFCCFBF1),
    ),
    InvoiceDesign.classicNavy => (
      PdfColor.fromInt(0xFF1E3A5F),
      PdfColors.white,
      PdfColor.fromInt(0xFFE2E8F0),
    ),
    InvoiceDesign.minimalMono => (
      PdfColors.black,
      PdfColors.white,
      PdfColors.grey200,
    ),
    InvoiceDesign.corporateSlate => (
      PdfColor.fromInt(0xFF334155),
      PdfColors.white,
      PdfColor.fromInt(0xFFF1F5F9),
    ),
  };
  final document = pw.Document(
    title: invoice.number,
    author: invoice.config['business_name']?.toString(),
  );
  final items = (invoice.snapshot['line_items'] as List? ?? const [])
      .whereType<Map<Object?, Object?>>()
      .toList();
  final visible = Map<String, dynamic>.from(
    invoice.config['visible_fields'] as Map? ?? const {},
  );
  bool show(String key) => visible[key] as bool? ?? true;
  String money(num value) => '${invoice.currency} ${value.toStringAsFixed(2)}';
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(invoice.config['footer']?.toString() ?? ''),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ],
      ),
      build: (_) => [
        pw.Container(
          width: double.infinity,
          color: header,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                invoice.config['business_name']?.toString() ?? 'BookMySpace',
                style: pw.TextStyle(
                  color: headerText,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                design.label,
                style: pw.TextStyle(color: headerText, fontSize: 10),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (invoice.sellerGstin.isNotEmpty)
                  pw.Text('GSTIN ${invoice.sellerGstin}'),
                if (invoice.sacCode.isNotEmpty)
                  pw.Text('SAC ${invoice.sacCode}'),
                if (show('address'))
                  pw.Text(invoice.config['address']?.toString() ?? ''),
                if (show('contact'))
                  pw.Text(
                    [
                      invoice.config['phone'],
                      invoice.config['email'],
                    ].where((e) => '$e'.isNotEmpty && e != null).join(' | '),
                  ),
                if (show('tax_details') &&
                    '${invoice.config['tax_details'] ?? ''}'.isNotEmpty)
                  pw.Text(invoice.config['tax_details'].toString()),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  invoice.documentType.replaceAll('_', ' ').toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(invoice.number),
                pw.Text(DateFormat.yMMMd().format(invoice.issuedAt)),
                pw.Text(invoice.status.toUpperCase()),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        if (show('customer'))
          pw.Text('Bill to: ${invoice.snapshot['customer_name'] ?? ''}'),
        if (show('booking'))
          pw.Text('Booking: ${invoice.snapshot['booking_id'] ?? ''}'),
        if (show('resource'))
          pw.Text(
            '${invoice.snapshot['module'] ?? ''} - ${invoice.snapshot['resource'] ?? ''}',
          ),
        if (show('dates'))
          pw.Text(
            '${invoice.snapshot['start'] ?? ''} ${invoice.snapshot['end'] ?? ''}',
          ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Qty', 'Rate', 'Amount'],
          data: items
              .map(
                (item) => [
                  item['description'] ?? '',
                  item['quantity'] ?? 1,
                  money((item['unit_price'] as num?) ?? 0),
                  money((item['amount'] as num?) ?? 0),
                ],
              )
              .toList(),
          headerDecoration: pw.BoxDecoration(color: band),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: design == InvoiceDesign.minimalMono
                ? PdfColors.black
                : header,
          ),
        ),
        pw.SizedBox(height: 16),
        for (final row in <(String, double)>[
          ('Subtotal', invoice.subtotal),
          ('Discount', -invoice.discount),
          ('Taxes', invoice.taxTotal),
          if (invoice.cgst > 0) ('CGST', invoice.cgst),
          if (invoice.sgst > 0) ('SGST', invoice.sgst),
          if (invoice.igst > 0) ('IGST', invoice.igst),
          ('Fees', invoice.feeTotal),
          ('Total', invoice.total),
          ('Paid', invoice.paid),
          ('Due', invoice.due),
          if (invoice.refund > 0) ('Refund', invoice.refund),
        ])
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${row.$1}: ${money(row.$2)}'),
          ),
        if (show('payment')) ...[
          pw.SizedBox(height: 18),
          pw.Text(
            'Payment: ${invoice.snapshot['payment_method'] ?? ''} | ${invoice.snapshot['payment_status'] ?? ''} | ${invoice.snapshot['payment_ref'] ?? ''}',
          ),
        ],
        if (show('bank') &&
            '${invoice.config['bank_details'] ?? ''}'.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('Payment details'),
          pw.Text(invoice.config['bank_details'].toString()),
        ],
        if (show('terms') && '${invoice.config['terms'] ?? ''}'.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(invoice.config['terms'].toString()),
        ],
        if (invoice.amountInWords.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Amount in words: ${invoice.amountInWords}'),
        ],
        if (show('signature') &&
            '${invoice.config['signature'] ?? ''}'.isNotEmpty) ...[
          pw.SizedBox(height: 30),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(invoice.config['signature'].toString()),
          ),
        ],
      ],
    ),
  );
  return document.save();
}
