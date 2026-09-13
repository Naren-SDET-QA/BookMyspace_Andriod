import 'dart:convert';

import 'package:bookmyspace/features/receipts/application/receipt_pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show PdfDocument, PdfFont;
import 'package:pdf/widgets.dart' as pw;

import 'receipt_fixtures.dart';

/// The font as the renderer builds it.
///
/// `pw.Font.ttf` is only a lazy wrapper; `PdfFont.isRuneSupported` is the gate
/// `pdf` actually consults before deciding to draw a missing-glyph box. Going
/// through `buildFont` means these assertions exercise that same path rather
/// than a stand-in.
PdfFont _pdfFont(ByteData data) =>
    pw.TtfFont(data).buildFont(PdfDocument(compress: false));

void main() {
  // rootBundle only resolves declared assets once the binding exists.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('embedded font', () {
    test('can draw the rupee sign', () async {
      final font = _pdfFont(await rootBundle.load(ReceiptPdf.regularFontAsset));

      expect(
        font.isRuneSupported(0x20B9),
        isTrue,
        reason: 'the PDF base-14 fonts cannot draw ₹ and silently substitute a '
            'missing-glyph box, so a receipt for ₹1,770 printed as □1,770.00',
      );
      expect(font.isRuneSupported(0x24), isTrue, reason: r'$');
      expect(font.isRuneSupported(0x00A3), isTrue, reason: '£');
      expect(font.isRuneSupported(0x20AC), isTrue, reason: '€');
      expect(font.isRuneSupported(0x00E9), isTrue, reason: 'é');
    });

    test('bold weight covers the same characters', () async {
      final font = _pdfFont(await rootBundle.load(ReceiptPdf.boldFontAsset));

      expect(font.isRuneSupported(0x20B9), isTrue);
      expect(font.isRuneSupported(0x00E9), isTrue);
    });

    test('is honestly documented as Latin-only', () async {
      final font = _pdfFont(await rootBundle.load(ReceiptPdf.regularFontAsset));

      // pdf performs no OpenType shaping, so Devanagari would render as
      // isolated, wrongly-ordered glyphs even if a font were bundled. The
      // subset is Latin-only on purpose: a visible missing-glyph box is more
      // honest than plausible-but-wrong text.
      expect(font.isRuneSupported(0x0915), isFalse, reason: 'Devanagari KA');
      expect(font.isRuneSupported(0x062F), isFalse, reason: 'Arabic DAL');
    });
  });

  group('generated document', () {
    test('is a PDF that embeds a TrueType font and no base-14 font', () async {
      final bytes = await ReceiptPdf.build(serverResult());
      final raw = latin1.decode(bytes, allowInvalid: true);

      expect(raw.startsWith('%PDF-'), isTrue);
      expect(
        raw,
        contains('/FontFile2'),
        reason: 'a TrueType font file must be embedded, or ₹ cannot render',
      );
      expect(
        raw,
        isNot(contains('/WinAnsiEncoding')),
        reason: 'WinAnsi encoding means a base-14 font, which cannot draw ₹',
      );
      expect(
        raw,
        isNot(contains('/Helvetica')),
        reason: 'falling back to Helvetica is the exact defect this guards',
      );
    });

    test('embeds both weights and keeps the text extractable', () async {
      final bytes = await ReceiptPdf.build(serverResult());
      final raw = latin1.decode(bytes, allowInvalid: true);

      expect(raw, contains('NotoSans-Regular'));
      expect(
        raw,
        contains('NotoSans-Bold'),
        reason: 'the bold weight must be embedded rather than silently mapped '
            'to the regular one',
      );
      expect(
        raw,
        contains('/ToUnicode'),
        reason: 'without a ToUnicode map the document is not searchable or '
            'selectable, which matters for a document a customer may need to '
            'quote a reference from',
      );
    });

    test('renders a receipt with a discount and lakh-scale amounts', () async {
      final bytes = await ReceiptPdf.build(
        serverResult(
          document: serverDocument(
            base: 1234567.50,
            tax: 222222.15,
            discount: 50000,
            total: 1406789.65,
          ),
        ),
      );

      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF-'), isTrue);
    });

    test('renders a statement when no payment was captured', () async {
      final bytes = await ReceiptPdf.build(
        serverResult(
          receiptIssued: false,
          receiptNumber: null,
          document: serverDocument(
            omissions: const ['platform_fee', 'no_payment_recorded'],
          ),
        ),
      );

      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF-'), isTrue);
    });

    test('renders when the breakdown does not reconcile', () async {
      final bytes = await ReceiptPdf.build(
        serverResult(
          document: serverDocument(base: 1500, tax: 270, total: 1900),
        ),
      );

      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF-'), isTrue);
    });

    test('renders a venue with almost nothing recorded', () async {
      final bytes = await ReceiptPdf.build(
        serverResult(
          document: <String, dynamic>{
            'booking_id': 'b1',
            'booking_ref': 'BMS-1',
            'status': 'confirmed',
            'currency': 'INR',
            'total_paid': 0,
            'venue': <String, dynamic>{'name': 'Bare Venue'},
            'slot': <String, dynamic>{},
            'guest': <String, dynamic>{},
            'line_items': <String, dynamic>{'base_amount': 0},
            'omissions': <String>[],
          },
        ),
      );

      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF-'), isTrue);
    });

    test('is deterministic apart from the generated-on stamp', () async {
      final first = await ReceiptPdf.build(serverResult());
      final second = await ReceiptPdf.build(serverResult());

      // Both must be valid PDFs of the same shape. Byte equality is not
      // expected: the document records when it was generated, and the PDF
      // trailer carries a file identifier.
      expect(first.length, second.length,
          reason: 'the same input must produce the same document size');
    });
  });
}
