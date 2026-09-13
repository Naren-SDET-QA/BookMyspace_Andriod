import 'dart:ui' as ui;

import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/qr_checkin/domain/qr_check_in.dart';
import 'package:bookmyspace/features/qr_checkin/presentation/widgets/qr_code_pass_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

const String _bookingId = '8f14e45f-ceea-467a-9c1c-3d6f1a2b4c5d';

Booking _booking({String id = _bookingId}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-883921',
    venueId: '3b241101-e2bb-4255-8caf-4136c566a962',
    slotId: 'a1c9f0de-77b2-4a13-9f5e-2d8c1b0a6e44',
    bookDate: DateTime(2026, 9, 20),
    startTime: '18:00:00',
    endTime: '19:00:00',
    status: BookingStatus.confirmed,
    amount: 1500,
    taxAmount: 270,
    totalAmount: 1770,
    venueName: 'Indiranagar Rooftop Arena',
    slotLabel: 'Evening Prime',
    createdAt: DateTime(2026, 9, 1, 9, 30),
  );
}

/// The symbol the widget is expected to draw, encoded independently here so the
/// test compares the widget against the specification rather than against
/// itself.
QrImage _expectedSymbol(Booking booking) {
  final payload = BookingCheckInPayload.fromBooking(booking);
  return QrImage(
    QrCode.fromData(
      data: payload.toQrPayloadString(),
      errorCorrectLevel: QrErrorCorrectLevel.Q,
    ),
  );
}

bool _isFinderPattern(QrImage image, int top, int left) {
  for (var r = 0; r < 7; r++) {
    for (var c = 0; c < 7; c++) {
      final expected = r == 0 || r == 6 || c == 0 || c == 6
          ? true
          : (r >= 2 && r <= 4 && c >= 2 && c <= 4);
      if (image.isDark(top + r, left + c) != expected) return false;
    }
  }
  return true;
}

/// FNV-1a over the module matrix, as a stable fingerprint of the encoder's
/// output. Written out here rather than pulled from a hashing package so the
/// test gains no dependency, and so a failure reports a number the verification
/// harness can reproduce.
int _fingerprint(QrImage image) {
  var hash = 0x811c9dc5;
  for (var r = 0; r < image.moduleCount; r++) {
    if (r > 0) {
      hash = ((hash ^ 0x0A) * 0x01000193) & 0xFFFFFFFF;
    }
    for (var c = 0; c < image.moduleCount; c++) {
      hash = ((hash ^ (image.isDark(r, c) ? 0x31 : 0x30)) * 0x01000193) &
          0xFFFFFFFF;
    }
  }
  return hash;
}

void main() {
  group('check-in payload', () {
    test('is compact and identical across rebuilds', () {
      final first =
          BookingCheckInPayload.fromBooking(_booking()).toQrPayloadString();
      final second =
          BookingCheckInPayload.fromBooking(_booking()).toQrPayloadString();

      expect(
        first,
        second,
        reason: 'a rebuilt pass must encode the same string, or the rendered '
            'matrix churns on every frame',
      );

      // SupabaseBookingRepository._bookingCode reads booking_id out of this map.
      expect(first, contains('"booking_id"'));
      expect(first, contains(_bookingId));

      // Density budget. At quartile error correction the symbol grows a version
      // for roughly every 20 further bytes, and a pass this size cannot afford
      // many more modules. See the measurement in toQrPayloadString.
      expect(first.length, lessThan(120));
    });

    test('carries the identifier even when the booking has no reference yet',
        () {
      final booking = Booking(
        id: _bookingId,
        bookingRef: '',
        venueId: 'venue-1',
        slotId: 'slot-1',
        bookDate: DateTime(2026, 9, 20),
        startTime: '18:00:00',
        endTime: '19:00:00',
        status: BookingStatus.confirmed,
        amount: 100,
        taxAmount: 18,
        totalAmount: 118,
      );

      expect(
        BookingCheckInPayload.fromBooking(booking).toQrPayloadString(),
        contains(_bookingId),
      );
    });
  });

  group('encoded symbol', () {
    test('is a real QR symbol with the mandatory finder patterns', () {
      final image = _expectedSymbol(_booking());

      // Real QR versions are 21 + 4n modules. A hand-drawn grid has no reason
      // to land on that series, so this is what separates an encoded symbol
      // from a picture of one.
      expect((image.moduleCount - 17) % 4, 0);
      expect(image.moduleCount, greaterThanOrEqualTo(21));

      for (final (top, left) in [
        (0, 0),
        (0, image.moduleCount - 7),
        (image.moduleCount - 7, 0),
      ]) {
        expect(
          _isFinderPattern(image, top, left),
          isTrue,
          reason: 'finder pattern missing at row $top, column $left',
        );
      }
    });

    test('differs between bookings', () {
      final a = _expectedSymbol(_booking());
      final b = _expectedSymbol(
        _booking(id: '11111111-2222-3333-4444-555555555555'),
      );

      var differences = 0;
      for (var r = 0; r < a.moduleCount; r++) {
        for (var c = 0; c < a.moduleCount; c++) {
          if (a.isDark(r, c) != b.isDark(r, c)) differences++;
        }
      }

      expect(differences, greaterThan(50));
    });

    // The painted-matrix test below compares the widget against this same
    // encoder, so a dependency bump that changed how `qr` encodes would move
    // both sides together and every other test here would still pass. This
    // pins the encoder's own output so that cannot happen quietly.
    //
    // The value was cross-checked two independent ways before being frozen:
    // qr 3.0.2 and qr 4.0.0 produce this matrix module for module, and OpenCV's
    // QR detector decodes it back to the exact expected payload — including
    // with the brand badge occluding the centre and at the production
    // three-pixels-per-module size.
    //
    // If this fails, the symbol changed. Re-verify the new symbol before
    // re-freezing; do not paste in the new number.
    test('encodes to a frozen symbol', () {
      final image = _expectedSymbol(_booking());

      expect(image.moduleCount, 45, reason: 'a 45-module symbol is version 7');
      expect(image.typeNumber, 7);
      expect(image.errorCorrectLevel, 3, reason: '3 is quartile');
      expect(image.maskPattern, 2);
      expect(_fingerprint(image), 0x432716c5);
    });
  });

  testWidgets('the painted pass matches the encoded matrix module for module',
      (tester) async {
    const passSize = 240.0;

    final booking = _booking();
    final image = _expectedSymbol(booking);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: const Key('pass_boundary'),
              child: QrCodePassWidget(
                booking: booking,
                size: passSize,
                showTokenLabel: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('pass_boundary')),
    );
    final raster = await tester.runAsync(() => boundary.toImage());
    final raw = await tester.runAsync(
      () => raster!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(raw, isNotNull);

    // Read the painter's real geometry rather than assuming it. The container's
    // border and padding both inset the drawing area, and guessing at that is
    // exactly the kind of silent error this test exists to catch.
    final paintFinder = find.descendant(
      of: find.byKey(const Key('pass_boundary')),
      matching: find.byType(CustomPaint),
    );
    expect(paintFinder, findsOneWidget);
    final paintBox = tester.renderObject<RenderBox>(paintFinder);
    final paintSize = paintBox.size;
    final paintOrigin =
        paintBox.localToGlobal(Offset.zero) - boundary.localToGlobal(Offset.zero);

    final pixels = raw!.buffer.asUint8List();
    final width = raster!.width;

    // Mirror the painter: a four-module quiet zone on every side, modules laid
    // out from the symbol's origin, and a cell size taken from the shortest
    // side of the drawing area.
    const quietZone = 4;
    final totalModules = image.moduleCount + quietZone * 2;
    final cell = paintSize.shortestSide / totalModules;
    final originX =
        paintOrigin.dx + (paintSize.width - cell * totalModules) / 2;
    final originY =
        paintOrigin.dy + (paintSize.height - cell * totalModules) / 2;

    /// True when the module centre is under the centred brand badge, which
    /// deliberately occludes a small block of data modules.
    bool underBadge(int row, int col) {
      final centre = image.moduleCount / 2;
      return (row + 0.5 - centre).abs() < 3 && (col + 0.5 - centre).abs() < 3;
    }

    var compared = 0;
    var mismatched = 0;
    final examples = <String>[];

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (underBadge(row, col)) continue;

        final x = originX + (col + quietZone + 0.5) * cell;
        final y = originY + (row + quietZone + 0.5) * cell;
        final px = x.round().clamp(0, width - 1);
        final py = y.round().clamp(0, width - 1);
        final offset = (py * width + px) * 4;
        final luminance =
            (pixels[offset] + pixels[offset + 1] + pixels[offset + 2]) / 3;
        final paintedDark = luminance < 128;

        compared++;
        if (paintedDark != image.isDark(row, col)) {
          mismatched++;
          if (examples.length < 5) {
            examples.add('($row,$col) painted=${paintedDark ? 'dark' : 'light'} '
                'expected=${image.isDark(row, col) ? 'dark' : 'light'}');
          }
        }
      }
    }

    expect(compared, greaterThan(1000));
    expect(
      mismatched,
      0,
      reason: 'the painted matrix must be the encoded matrix '
          '(${image.moduleCount} modules, cell ${cell.toStringAsFixed(2)}px, '
          'painted area ${paintSize.width}x${paintSize.height}). '
          'Mismatches: ${examples.join('; ')}',
    );
  });
}
