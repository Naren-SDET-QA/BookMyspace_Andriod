import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_theme.dart';

/// Live camera QR scanning for venue check-in, on Android, iOS and Web.
///
/// The controller is owned here and started explicitly rather than through
/// `MobileScanner`'s `autoStart`, for two reasons:
///
///  * `_MobileScannerState._initializeController` calls `await controller
///    .start()` from `initState` with no surrounding `try`/`catch`, and
///    `MobileScannerController.start` only converts `MobileScannerException`
///    (mobile_scanner 7.4.1, `mobile_scanner.dart:208`). On a host where the
///    plugin is not registered — widget tests, for instance — the
///    `MissingPluginException` escapes as an unhandled asynchronous error.
///  * The screen has to know whether the camera works, because manual reference
///    entry is the fallback and the user must be told which one they are on.
///
/// So `autoStart` is false, `start()` is called from a guarded method, and every
/// outcome becomes something this widget can render.
class QrCameraScanner extends StatefulWidget {
  const QrCameraScanner({
    super.key,
    required this.onDetected,
    this.height = 320,
  });

  /// Called with the decoded payload of a QR code.
  ///
  /// Fired once per distinct payload: the camera re-detects the same code on
  /// every analysed frame while it stays in view, so repeated frames are
  /// filtered before they reach the caller.
  final ValueChanged<String> onDetected;

  /// Height of the viewfinder box.
  final double height;

  @override
  State<QrCameraScanner> createState() => _QrCameraScannerState();
}

class _QrCameraScannerState extends State<QrCameraScanner> {
  /// How long the same payload is suppressed before it may be reported again.
  ///
  /// Long enough that holding one code in front of the lens fires a single
  /// check-in, short enough that deliberately re-scanning after a rejection
  /// works without waiting.
  static const Duration _repeatWindow = Duration(seconds: 3);

  /// How long to wait for the platform to start the camera.
  ///
  /// `MobileScannerController.start` awaits a platform channel. When nothing
  /// answers that channel the future neither completes nor throws — measured
  /// directly against mobile_scanner 7.4.1, where `start()` was still pending
  /// after four seconds with no error and no completion. Widget tests hit this
  /// because no plugin is registered; a real device with a wedged camera
  /// service can too. Without a deadline the viewfinder would sit dark forever
  /// with nothing to tell the user.
  ///
  /// Six seconds leaves room for a cold start on a slow device while still
  /// producing an explanation quickly when something is actually wrong.
  static const Duration _startTimeout = Duration(seconds: 6);

  MobileScannerController? _controller;
  bool _disposed = false;

  /// True when the host has no camera plugin at all, as opposed to a camera
  /// that failed to start. Widget tests and unsupported platforms land here.
  bool _pluginUnavailable = false;

  /// True when the platform accepted the start request and never answered it.
  bool _timedOut = false;

  /// True once [_start] has returned, however it returned.
  bool _startReturned = false;

  String? _lastPayload;
  DateTime _lastEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      // `normal` analyses one frame per detectionTimeoutMs. `noDuplicates`
      // analyses every frame purely to compare values, which is wasted work for
      // a code that is checked in once.
      detectionSpeed: DetectionSpeed.normal,
      // A check-in pass is always a QR code. Restricting the formats lets the
      // native detector skip the other symbologies entirely.
      formats: const [BarcodeFormat.qrCode],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final controller = _controller;
    if (_disposed || controller == null) return;

    try {
      await controller.start().timeout(_startTimeout);
    } on TimeoutException {
      // The platform took the request and never answered. If it recovers later
      // the controller's own state turns the preview live and the notice below
      // disappears on its own.
      if (mounted) setState(() => _timedOut = true);
    } catch (_) {
      // No camera plugin on this host, or the controller was disposed while
      // starting. Either way there is no camera to show, so say so rather than
      // leaving an unexplained dark rectangle.
      if (mounted) setState(() => _pluginUnavailable = true);
    } finally {
      if (mounted) setState(() => _startReturned = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(_disposeController(controller));
    }
    super.dispose();
  }

  /// Disposal must not throw. The plugin may be absent (tests) or already torn
  /// down, and an exception escaping here would surface during the framework's
  /// teardown rather than anywhere useful.
  Future<void> _disposeController(MobileScannerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // Nothing left to release.
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    String? payload;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        payload = raw;
        break;
      }
    }
    if (payload == null) return;

    final now = DateTime.now();
    final isRepeat = payload == _lastPayload &&
        now.difference(_lastEmittedAt) < _repeatWindow;
    if (isRepeat) return;

    _lastPayload = payload;
    _lastEmittedAt = now;
    widget.onDetected(payload);
  }

  /// Why the camera is not usable, or null when there is nothing to report yet.
  ///
  /// `MobileScannerController.start` converts camera failures into
  /// `value.error` rather than throwing, so the state has to be read back
  /// instead of relying on the return of `start()`.
  String? _failureReason(MobileScannerState state) {
    if (_pluginUnavailable) {
      return 'Camera scanning is not available here. '
          'Enter the booking reference below.';
    }

    final error = state.error;
    if (error != null) {
      return switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'Camera access was denied. Allow it in your device settings, '
              'or enter the booking reference below.',
        MobileScannerErrorCode.unsupported =>
          'This device cannot scan QR codes. '
              'Enter the booking reference below.',
        _ => 'The camera could not be started. '
            'Enter the booking reference below.',
      };
    }

    if (_timedOut) {
      return 'The camera did not start. '
          'Enter the booking reference below.';
    }

    // Still starting. The dark preview is expected, so say nothing yet.
    if (!_startReturned || state.isStarting) return null;

    // start() returned cleanly with no error and no running camera — something
    // failed in a way the plugin did not describe.
    return 'The camera could not be started. '
        'Enter the booking reference below.';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return SizedBox(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ValueListenableBuilder<MobileScannerState>(
          valueListenable: controller,
          builder: (context, state, _) {
            // Liveness comes from the controller rather than from the absence
            // of a message. A sweeping reticle over a preview that is not
            // delivering frames would claim scanning is happening.
            final isLive = state.isRunning;
            final failure = isLive ? null : _failureReason(state);

            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF121212)),

                if (!_pluginUnavailable)
                  MobileScanner(
                    controller: controller,
                    onDetect: _handleDetection,
                    fit: BoxFit.cover,
                    // MobileScanner renders its own error text by default. This
                    // widget explains the failure in its own words instead.
                    errorBuilder: (context, error) =>
                        const ColoredBox(color: Color(0xFF121212)),
                    placeholderBuilder: (context) =>
                        const ColoredBox(color: Color(0xFF121212)),
                  ),

                _ScannerReticle(isLive: isLive),

                if (failure != null) _ScannerNotice(message: failure),

                if (isLive)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _CameraControls(controller: controller),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Corner brackets framing the scan area, with a laser line that animates only
/// while the camera is actually delivering frames.
class _ScannerReticle extends StatefulWidget {
  const _ScannerReticle({required this.isLive});

  final bool isLive;

  @override
  State<_ScannerReticle> createState() => _ScannerReticleState();
}

class _ScannerReticleState extends State<_ScannerReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isLive) _sweep.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ScannerReticle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive == oldWidget.isLive) return;

    if (widget.isLive) {
      _sweep.repeat(reverse: true);
    } else {
      // A sweeping line over a camera that is not running implies scanning is
      // happening. Stop it and park it at the top.
      _sweep
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          painter: _ReticlePainter(
            progress: _sweep.value,
            showLaser: widget.isLive,
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.progress, required this.showLaser});

  final double progress;
  final bool showLaser;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final reticleSize = (w < h ? w : h) * 0.65;
    final left = (w - reticleSize) / 2;
    final top = (h - reticleSize) / 2;

    final bracketPaint = Paint()
      ..color = AppTheme.brand
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    void corner(Offset origin, double dx, double dy) {
      canvas
        ..drawLine(origin, origin.translate(cornerLen * dx, 0), bracketPaint)
        ..drawLine(origin, origin.translate(0, cornerLen * dy), bracketPaint);
    }

    corner(Offset(left, top), 1, 1);
    corner(Offset(left + reticleSize, top), -1, 1);
    corner(Offset(left, top + reticleSize), 1, -1);
    corner(Offset(left + reticleSize, top + reticleSize), -1, -1);

    if (!showLaser) return;

    final scanY = top + (reticleSize * progress);
    canvas
      ..drawLine(
        Offset(left + 8, scanY),
        Offset(left + reticleSize - 8, scanY),
        Paint()
          ..color = const Color(0xFF00E676)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      )
      ..drawRect(
        Rect.fromLTWH(left + 8, scanY - 20, reticleSize - 16, 20),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF00E676).withValues(alpha: 0.25),
              const Color(0xFF00E676).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(left + 8, scanY - 20, reticleSize - 16, 20),
          ),
      );
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.showLaser != showLaser;
}

/// Explains why there is no camera preview.
class _ScannerNotice extends StatelessWidget {
  const _ScannerNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white38,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Torch and camera-flip controls, shown only for the capabilities the running
/// camera actually reports.
class _CameraControls extends StatelessWidget {
  const _CameraControls({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final hasTorch = state.torchState != TorchState.unavailable;
        final hasMultipleCameras = (state.availableCameras ?? 0) > 1;
        if (!hasTorch && !hasMultipleCameras) return const SizedBox.shrink();

        final torchOn = state.torchState == TorchState.on ||
            state.torchState == TorchState.auto;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasTorch)
              _ScannerCircleButton(
                icon: torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                label: 'Torch',
                isActive: torchOn,
                onTap: () => unawaited(controller.toggleTorch()),
              ),
            if (hasTorch && hasMultipleCameras) const SizedBox(width: 20),
            if (hasMultipleCameras)
              _ScannerCircleButton(
                icon: Icons.cameraswitch_outlined,
                label: 'Flip',
                isActive: true,
                onTap: () => unawaited(controller.switchCamera()),
              ),
          ],
        );
      },
    );
  }
}

class _ScannerCircleButton extends StatelessWidget {
  const _ScannerCircleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.brand
                  : Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
