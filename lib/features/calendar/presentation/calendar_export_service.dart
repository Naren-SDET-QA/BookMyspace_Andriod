import 'dart:convert';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:url_launcher/url_launcher.dart';

import '../../booking/domain/booking.dart';
import '../domain/calendar_event.dart';
import '../domain/ics_exporter.dart';

/// Platform-specific save/share surface for ICS files.
///
/// - **Android/iOS**: [fp.FilePicker.platform.saveFile] opens the native save
///   dialog; the resulting file can be opened by any calendar app.
/// - **Web**: Encodes the ICS content as a base64 `data:text/calendar` URI and
///   launches it via [launchUrl], triggering the browser's download handler.
///
/// No fake success states: every path returns `true` only when the platform
/// call completed without throwing. Errors are caught and reported honestly.
class CalendarExportService {
  const CalendarExportService();

  static const _exporter = IcsExporter();

  /// Exports a single [Booking] to an .ics file.
  ///
  /// Returns a human-readable result message suitable for a SnackBar.
  /// Never throws — errors are caught and reported.
  Future<String> exportBooking(Booking booking) async {
    if (!booking.canExportCalendar) {
      return 'Only confirmed or completed bookings can be added to your calendar.';
    }

    final event = CalendarEvent.fromBooking(booking);
    if (event == null) {
      return 'This booking has no valid time range to export.';
    }

    final ics = _exporter.toIcs(event);
    final fileName =
        'booking-${booking.bookingRef.isNotEmpty ? booking.bookingRef : booking.id}.ics';

    if (kIsWeb) {
      return _exportWeb(ics, fileName);
    } else {
      return _exportNative(ics, fileName);
    }
  }

  /// Web export: launch a data URI so the browser downloads the .ics file.
  Future<String> _exportWeb(String ics, String fileName) async {
    try {
      final base64Content = base64Encode(utf8.encode(ics));
      final dataUri =
          'data:text/calendar;charset=utf-8;base64,$base64Content';

      final launched = await launchUrl(
        Uri.parse(dataUri),
      );
      if (launched) {
        return 'Calendar export downloaded. Open the file to add it to your calendar.';
      }
      return 'Could not download the calendar file. Please try again.';
    } catch (e) {
      return 'Calendar export failed: $e';
    }
  }

  /// Native export: save the .ics file via [fp.FilePicker].
  Future<String> _exportNative(String ics, String fileName) async {
    try {
      final result = await fp.FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(ics)),
      );
      if (result != null) {
        return 'Calendar export saved to: $result. Open it to add to your calendar.';
      }
      return 'Calendar export was cancelled.';
    } catch (e) {
      return 'Calendar export failed: $e';
    }
  }
}
