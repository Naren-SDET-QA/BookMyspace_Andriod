import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/receipt.dart';
import '../domain/receipt_statement.dart';

/// Renders an itemized receipt as a PDF.
///
/// Pure Dart, so the bytes are identical on Android, iOS and Web: a customer
/// does not get a different document depending on where they opened the app.
///
/// This class only lays out. Every decision about what the document claims —
/// its title, whether it carries a receipt number, which caveats it prints —
/// comes from [ReceiptStatement], so the PDF and the on-screen view cannot
/// disagree.
class ReceiptPdf {
  const ReceiptPdf._();

  /// Subset of Noto Sans with real Latin and currency coverage. Required
  /// because the PDF base-14 fonts cannot draw `₹` — see
  /// `assets/fonts/README.md`.
  static const String regularFontAsset = 'assets/fonts/NotoSans-Receipt.ttf';
  static const String boldFontAsset = 'assets/fonts/NotoSans-Receipt-Bold.ttf';

  static pw.Font? _regular;
  static pw.Font? _bold;

  static final PdfColor _brand = PdfColor.fromHex('#00A084');
  static final PdfColor _ink = PdfColor.fromHex('#0B1F33');
  static final PdfColor _muted = PdfColor.fromHex('#475569');
  static final PdfColor _rule = PdfColor.fromHex('#CBD5E1');
  static final PdfColor _band = PdfColor.fromHex('#F3F7FA');
  static final PdfColor _alert = PdfColor.fromHex('#B45309');
  static final PdfColor _alertBand = PdfColor.fromHex('#FEF3C7');

  static Future<pw.Font> _font(String asset, bool bold) async {
    final cached = bold ? _bold : _regular;
    if (cached != null) return cached;

    final data = await rootBundle.load(asset);
    final font = pw.Font.ttf(data);
    if (bold) {
      _bold = font;
    } else {
      _regular = font;
    }
    return font;
  }

  /// Renders [result] to PDF bytes.
  static Future<Uint8List> build(ReceiptResult result) async {
    final statement = ReceiptStatement(result);
    final regular = await _font(regularFontAsset, false);
    final bold = await _font(boldFontAsset, true);

    final doc = pw.Document(
      title: statement.isReceipt
          ? 'BookMySpace receipt ${statement.numberLine}'
          : 'BookMySpace statement ${statement.document.bookingRef}',
      author: 'BookMySpace',
      creator: 'BookMySpace',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(statement),
        footer: _footer,
        build: (context) => [
          _masthead(statement),
          pw.SizedBox(height: 18),
          _metaBlock(statement),
          pw.SizedBox(height: 18),
          _partiesRow(statement.document),
          pw.SizedBox(height: 18),
          _bookingBlock(statement.document),
          pw.SizedBox(height: 18),
          _itemisationBlock(statement),
          pw.SizedBox(height: 18),
          _paymentBlock(statement.document),
          if (statement.notes.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _notesBlock(statement),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  static pw.Widget _masthead(ReceiptStatement statement) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _band,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _rule, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BookMySpace',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Venue and workspace booking platform',
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                // Never call a statement a receipt. The distinction matters:
                // a receipt is evidence of payment and carries a number.
                statement.title.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: statement.isReceipt ? _ink : _alert,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                statement.numberLine,
                style: pw.TextStyle(fontSize: 9.5, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaBlock(ReceiptStatement statement) {
    final document = statement.document;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _metaList([
            ('Booking reference', document.bookingRef),
            ('Booking status', _titleCase(document.status)),
            ('Issued on', _dateTime(document.issuedAt)),
          ]),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _metaList([
            ('Currency', document.currency),
            ('Document', statement.isReceipt ? 'Receipt' : 'Statement'),
            ('Generated', _dateTime(DateTime.now())),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _metaList(List<(String, String)> entries) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (label, value) in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 96,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    value.isEmpty ? '—' : value,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _partiesRow(ReceiptDocument document) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _partyCard('BILLED TO', _guestLines(document))),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _partyCard('VENUE', _venueLines(document))),
      ],
    );
  }

  static pw.Widget _partyCard(String heading, List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading,
            style: pw.TextStyle(
              fontSize: 8,
              letterSpacing: 0.8,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.Text(
                line,
                style: pw.TextStyle(fontSize: 9.5, color: _ink),
              ),
            ),
        ],
      ),
    );
  }

  static List<String> _guestLines(ReceiptDocument document) {
    final guest = document.guest;
    return <String>[
      _orDash(guest.name),
      if (_present(guest.email)) guest.email!,
      if (_present(guest.phone)) guest.phone!,
    ];
  }

  static List<String> _venueLines(ReceiptDocument document) {
    final venue = document.venue;
    final address = venue.formattedAddress;
    return <String>[
      _orDash(venue.name),
      if (address.isNotEmpty) address,
    ];
  }

  static pw.Widget _bookingBlock(ReceiptDocument document) {
    final slot = document.slot;
    return _section(
      'BOOKING',
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _metaList([
              ('Space', _orDash(slot.label)),
              ('Date', slot.bookDate == null ? '—' : _date(slot.bookDate!)),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: _metaList([
              ('Time', _timeRange(slot.startTime, slot.endTime)),
              ('Quantity', slot.quantity?.toString() ?? '—'),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemisationBlock(ReceiptStatement statement) {
    final document = statement.document;
    return _section(
      'ITEMISATION',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final row in statement.rows)
            _amountRow(row.label, row.signedAmount, document),
          pw.SizedBox(height: 4),
          pw.Container(height: 0.8, color: _rule),
          pw.SizedBox(height: 6),
          _amountRow(
            statement.totalLabel,
            statement.total,
            document,
            emphasised: true,
          ),
          if (statement.needsReconciliationNotice) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _alertBand,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                statement.reconciliationNotice,
                style: pw.TextStyle(fontSize: 8.5, color: _alert),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    double amount,
    ReceiptDocument document, {
    bool emphasised = false,
  }) {
    final style = pw.TextStyle(
      fontSize: emphasised ? 11 : 9.5,
      color: _ink,
      fontWeight: emphasised ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(document.formatMoney(amount), style: style),
        ],
      ),
    );
  }

  static pw.Widget _paymentBlock(ReceiptDocument document) {
    final method = _present(document.paymentMethod)
        ? document.paymentMethod!.toUpperCase()
        : '—';
    return _section(
      'PAYMENT',
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _metaList([
              ('Method', method),
              ('Provider', _orDash(document.paymentProvider)),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: _metaList([
              ('Reference', _orDash(document.paymentRef)),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _notesBlock(ReceiptStatement statement) {
    return _section(
      'NOTES',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final note in statement.notes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 10,
                    child: pw.Text(
                      '•',
                      style: pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      note,
                      style: pw.TextStyle(fontSize: 8.5, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chrome
  // ---------------------------------------------------------------------------

  static pw.Widget _runningHeader(ReceiptStatement statement) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'BookMySpace',
              style: pw.TextStyle(
                fontSize: 9,
                color: _brand,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            statement.isReceipt
                ? statement.numberLine
                : statement.document.bookingRef,
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      margin: const pw.EdgeInsets.only(top: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.7)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Computer-generated document. No signature required.',
              style: pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(String heading, pw.Widget child) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          heading,
          style: pw.TextStyle(
            fontSize: 8,
            letterSpacing: 0.9,
            color: _brand,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 0.7, color: _rule),
        pw.SizedBox(height: 7),
        child,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  static bool _present(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _orDash(String? value) => _present(value) ? value!.trim() : '—';

  static String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);

  static String _dateTime(DateTime? value) => value == null
      ? '—'
      : DateFormat('d MMM yyyy, h:mm a').format(value.toLocal());

  /// `18:00:00` reads as `18:00`. The seconds come from the `time` column and
  /// carry no information on a receipt.
  static String _timeRange(String? start, String? end) {
    final from = _clock(start);
    final to = _clock(end);
    if (from == null && to == null) return '—';
    if (from == null) return to!;
    if (to == null) return from;
    return '$from – $to';
  }

  static String? _clock(String? raw) {
    if (!_present(raw)) return null;
    final parts = raw!.trim().split(':');
    if (parts.length < 2) return raw.trim();
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return '—';
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
