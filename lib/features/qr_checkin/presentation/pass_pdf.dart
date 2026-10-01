import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';

import '../../booking/domain/booking.dart';
import '../domain/qr_check_in.dart';

/// A one-page entry pass. The QR uses the same payload as the on-screen pass.
Future<Uint8List> buildPassPdf(Booking booking) async {
  final payload = BookingCheckInPayload.fromBooking(booking);
  QrImage? matrix;
  try {
    matrix = QrImage(
      QrCode.fromData(
        data: payload.toQrPayloadString(),
        errorCorrectLevel: QrErrorCorrectLevel.Q,
      ),
    );
  } on InputTooLongException {
    matrix = null;
  }
  final document = pw.Document(title: 'BookMySpace pass ${booking.bookingRef}');
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BookMySpace entry pass',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(booking.venueName.isEmpty ? 'Venue' : booking.venueName),
          if (booking.venueCity.isNotEmpty) pw.Text(booking.venueCity),
          pw.SizedBox(height: 6),
          pw.Text(
            '${DateFormat.yMMMd().format(booking.bookDate)}  '
            '${booking.displayStart} – ${booking.displayEnd}',
          ),
          if (booking.slotLabel.isNotEmpty) pw.Text(booking.slotLabel),
          pw.Text(
            'Ref ${booking.bookingRef.isEmpty ? booking.id : booking.bookingRef}',
          ),
          pw.SizedBox(height: 12),
          if (matrix == null)
            pw.Text('Show this booking reference at the entrance.')
          else
            _qrGrid(matrix),
          pw.SizedBox(height: 12),
          pw.Text(
            'Show this pass at the venue entrance. The host scans the code '
            'to check you in.',
          ),
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _qrGrid(QrImage image) {
  const quiet = 4;
  final modules = image.moduleCount + quiet * 2;
  return pw.Column(
    children: [
      for (var row = 0; row < modules; row++)
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            for (var col = 0; col < modules; col++)
              pw.Container(
                width: 3.2,
                height: 3.2,
                color: _isDark(image, row, col, quiet)
                    ? PdfColors.black
                    : PdfColors.white,
              ),
          ],
        ),
    ],
  );
}

bool _isDark(QrImage image, int row, int col, int quiet) {
  final r = row - quiet;
  final c = col - quiet;
  if (r < 0 || c < 0 || r >= image.moduleCount || c >= image.moduleCount) {
    return false;
  }
  return image.isDark(r, c);
}
