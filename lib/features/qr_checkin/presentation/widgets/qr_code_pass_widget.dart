import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../domain/qr_check_in.dart';

/// Renders a real, scannable QR pass for venue check-in on Android, iOS and Web.
///
/// The matrix comes from the `qr` package, which implements ISO/IEC 18004
/// properly: byte-mode encoding, Reed-Solomon error correction, format and
/// version information, and mask selection by penalty score. An earlier version
/// of this widget hand-drew a QR-shaped grid instead, with no error correction
/// and no data encoding at all — it looked like a QR code and no reader could
/// decode it.
///
/// The payload is [BookingCheckInPayload.toQrPayloadString] rather than the full
/// booking record, because a 428-byte payload needs a 93x93 module code that no
/// phone camera can resolve at this size. See that method for the measurement.
class QrCodePassWidget extends StatelessWidget {
  const QrCodePassWidget({
    super.key,
    required this.booking,
    this.size = 190.0,
    this.showTokenLabel = true,
  });

  final Booking booking;
  final double size;
  final bool showTokenLabel;

  /// Error correction level for the pass.
  ///
  /// Quartile recovers ~25% of the symbol. That headroom is what pays for the
  /// brand badge cut out of the centre (25 of 2025 modules) and for real-world
  /// glare and screen reflections at a venue desk.
  ///
  /// `qr` 3.x exposes this as the integer 3 rather than a named enum member,
  /// but the value is the ISO/IEC 18004 format-information code for quartile
  /// (0b11), so the level is unchanged.
  static const int _errorCorrectLevel = QrErrorCorrectLevel.Q;

  /// Encodes [data], or returns null when it cannot fit any QR version.
  ///
  /// A pass that cannot be encoded must render an explanation rather than a
  /// plausible-looking grid, so the failure is visible instead of silent.
  ///
  /// The overflow is raised from `QrImage`, not from `QrCode.fromData`:
  /// `fromData` gives up at type number 40 without throwing, and the length
  /// check runs when the matrix is built. Both calls therefore sit inside the
  /// same `try`, and moving either one out would let an oversized pass fall
  /// back to a silently invalid symbol.
  static QrImage? _encode(String data) {
    try {
      return QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: _errorCorrectLevel),
      );
    } on InputTooLongException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = BookingCheckInPayload.fromBooking(booking);
    final image = _encode(payload.toQrPayloadString());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: image == null
              ? const _UnencodablePass()
              : CustomPaint(
                  size: Size(size - 24, size - 24),
                  painter: _QrMatrixPainter(image: image),
                ),
        ),
        if (showTokenLabel) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code, size: 13, color: AppTheme.violet),
              const SizedBox(width: 4),
              Text(
                'TOKEN: ${payload.token}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shown when the pass payload cannot be encoded into any QR version.
class _UnencodablePass extends StatelessWidget {
  const _UnencodablePass();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2, size: 36, color: Colors.black38),
          SizedBox(height: 8),
          Text(
            'This pass could not be generated.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(height: 4),
          Text(
            'Use the booking reference instead.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  _QrMatrixPainter({required this.image});

  final QrImage image;

  /// The ISO/IEC 18004 quiet zone: four light modules on every side. A reader
  /// locates the symbol's edges against this margin, so omitting it is a
  /// common and silent cause of scan failure.
  static const int _quietZone = 4;

  /// Side of the centred brand badge, in modules.
  static const int _badgeModules = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final totalModules = image.moduleCount + _quietZone * 2;
    final cell = size.shortestSide / totalModules;
    final originX = (size.width - cell * totalModules) / 2;
    final originY = (size.height - cell * totalModules) / 2;

    final modulePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;

        // One module plus a hair, so neighbouring cells never leave a seam when
        // the module size lands on a fractional pixel.
        canvas.drawRect(
          Rect.fromLTWH(
            originX + (col + _quietZone) * cell,
            originY + (row + _quietZone) * cell,
            cell + 0.5,
            cell + 0.5,
          ),
          modulePaint,
        );
      }
    }

    _paintBrandBadge(canvas, cell, originX, originY);
  }

  /// A white plate with a brand dot over the centre of the symbol.
  ///
  /// This deliberately occludes data modules. At quartile error correction the
  /// symbol tolerates losing ~25% of its modules; this plate covers 25 of 2025
  /// (1.2%), so the decoder reconstructs the occluded area from the
  /// Reed-Solomon parity.
  void _paintBrandBadge(
    Canvas canvas,
    double cell,
    double originX,
    double originY,
  ) {
    final symbolModules = image.moduleCount;
    final badgeSide = _badgeModules * cell;

    // The symbol starts one quiet zone in from the drawing origin, so the badge
    // has to be offset by that too. Centring it on the drawing origin instead
    // puts it four modules up and to the left of the middle of the code.
    final symbolOriginX = originX + _quietZone * cell;
    final symbolOriginY = originY + _quietZone * cell;

    final badgeLeft =
        symbolOriginX + (symbolModules / 2) * cell - badgeSide / 2;
    final badgeTop = symbolOriginY + (symbolModules / 2) * cell - badgeSide / 2;
    final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeSide, badgeSide);
    final rounded = RRect.fromRectAndRadius(
      badgeRect,
      Radius.circular(cell * 0.6),
    );

    canvas
      ..drawRRect(rounded, Paint()..color = Colors.white)
      ..drawRRect(
        rounded,
        Paint()
          ..color = AppTheme.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(
        badgeRect.center,
        cell * 0.8,
        Paint()
          ..color = AppTheme.brand
          ..style = PaintingStyle.fill,
      );
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) =>
      oldDelegate.image != image;
}
