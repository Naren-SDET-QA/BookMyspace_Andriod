import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../domain/qr_check_in.dart';
import '../presentation/qr_checkin_providers.dart';
import '../widgets/qr_code_pass_widget.dart';

/// Screen providing CameraX-style QR scanning and digital entry pass display.
///
/// Matches Android's [QrCheckInScannerScreen.kt] in layout, tabs, viewfinder
/// simulation, live Supabase link, and check-in status-update lifecycle.
class QrCheckInScannerScreen extends ConsumerStatefulWidget {
  const QrCheckInScannerScreen({super.key});

  @override
  ConsumerState<QrCheckInScannerScreen> createState() =>
      _QrCheckInScannerScreenState();
}

class _QrCheckInScannerScreenState extends ConsumerState<QrCheckInScannerScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Scan QR Code, 1: My Entry Pass QR
  final TextEditingController _manualInputController = TextEditingController();
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrState = ref.watch(qrCheckInNotifierProvider);
    final confirmedBookings = ref.watch(qrPassBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('qr_scanner_back_btn'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Venue QR Check-In',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Supabase DB Live Link • Fast Entry Verification',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Supabase Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Tabs (0: Scan QR Code, 1: My Entry Pass QR)
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: TabController(
                length: 2,
                vsync: this,
                initialIndex: _selectedTab,
              )..addListener(() {
                  if (mounted) {
                    setState(() {
                      // tab changed
                    });
                  }
                }),
              onTap: (index) => setState(() => _selectedTab = index),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📷 ', style: TextStyle(fontSize: 14)),
                      Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎫 ', style: TextStyle(fontSize: 14)),
                      Text('My Entry Pass QR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: _selectedTab == 0
                ? _buildScannerTab(theme, qrState, confirmedBookings)
                : _buildMyPassTab(theme, confirmedBookings),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab(
    ThemeData theme,
    QrCheckInState qrState,
    List<Booking> confirmedBookings,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera Viewfinder Box
          Card(
            key: const Key('qr_camera_viewfinder'),
            shape: RoundedCornerShape(20),
            color: const Color(0xFF121212),
            elevation: 4,
            child: SizedBox(
              height: 320,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated laser scanning line & reticle
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(double.infinity, 320),
                        painter: _ViewfinderReticlePainter(
                          progress: _scanLineAnimation.value,
                          isTorchOn: qrState.isTorchOn,
                        ),
                      );
                    },
                  ),

                  // Overlay prompt
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        qrState.isFrontCamera
                            ? 'Front Camera Active'
                            : 'Align QR pass within the square frame',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Scanner Controls (Torch, Flip Camera, Sample Scan)
                  Positioned(
                    bottom: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScannerCircleButton(
                          icon: qrState.isTorchOn ? Icons.flash_on : Icons.flash_off,
                          label: 'Torch',
                          isActive: qrState.isTorchOn,
                          onTap: () => ref
                              .read(qrCheckInNotifierProvider.notifier)
                              .toggleTorch(),
                        ),
                        const SizedBox(width: 16),
                        _ScannerCircleButton(
                          icon: Icons.flip_camera_ios,
                          label: 'Flip',
                          isActive: qrState.isFrontCamera,
                          onTap: () => ref
                              .read(qrCheckInNotifierProvider.notifier)
                              .toggleCamera(),
                        ),
                        const SizedBox(width: 16),
                        _ScannerCircleButton(
                          icon: Icons.qr_code_scanner,
                          label: 'Test Scan',
                          isActive: true,
                          onTap: () {
                            if (confirmedBookings.isNotEmpty) {
                              _performCheckIn(confirmedBookings.first.id);
                            } else {
                              _performCheckIn('BMS-883921');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Manual Code Input Card
          Card(
            shape: RoundedCornerShape(16),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Or Enter Booking Ref / QR Pass ID',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('manual_qr_input_field'),
                          controller: _manualInputController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            hintText: 'e.g. bk_1001 or BMS-883921',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('submit_manual_qr_btn'),
                        onPressed: qrState.isLoading
                            ? null
                            : () {
                                final text = _manualInputController.text.trim();
                                if (text.isNotEmpty) {
                                  _performCheckIn(text);
                                }
                              },
                        style: FilledButton.styleFrom(
                          shape: RoundedCornerShape(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: qrState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Check In',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPassTab(ThemeData theme, List<Booking> confirmedBookings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Present this QR Pass at venue entry desk for quick check-in:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (confirmedBookings.isEmpty)
          Card(
            shape: RoundedCornerShape(16),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Active Confirmed Bookings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Once you reserve a court or venue, your digital QR pass will automatically appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...confirmedBookings.map((booking) => _buildQrPassCard(theme, booking)),
      ],
    );
  }

  Widget _buildQrPassCard(ThemeData theme, Booking booking) {
    final isCheckedIn = booking.status == BookingStatus.completed;

    return Card(
      key: Key('qr_pass_card_${booking.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedCornerShape(20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.venueName.isNotEmpty
                            ? booking.venueName
                            : 'Space Booking',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat.yMMMd().format(booking.bookDate)} • ${booking.slotLabel.isNotEmpty ? booking.slotLabel : "${booking.displayStart} - ${booking.displayEnd}"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? const Color(0xFFE8F5E9)
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCheckedIn ? '✓ CHECKED IN' : 'READY TO SCAN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isCheckedIn
                          ? const Color(0xFF2E7D32)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // High Contrast 2D QR Code Pass
            QrCodePassWidget(
              booking: booking,
              size: 200,
              showTokenLabel: false,
            ),
            const SizedBox(height: 12),

            Text(
              'PASS REF: #${booking.bookingRef}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Supabase Verification Key: ${booking.id}',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invoice & QR pass ready for #${booking.bookingRef}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Pass Info', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedCornerShape(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isCheckedIn
                        ? null
                        : () => _performCheckIn(booking.id),
                    icon: const Icon(Icons.how_to_reg, size: 16),
                    label: Text(
                      isCheckedIn ? 'Verified' : 'Check In Now',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedCornerShape(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performCheckIn(String code) async {
    final notifier = ref.read(qrCheckInNotifierProvider.notifier);
    final res = await notifier.checkInWithCode(code);
    _showResultDialog(res);
  }

  void _showResultDialog(CheckInResult res) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              res.success ? Icons.check_circle : Icons.error,
              color: res.success ? const Color(0xFF2E7D32) : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              res.success ? 'Check-In Verified!' : 'Check-In Issue',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              res.message,
              style: const TextStyle(fontSize: 14),
            ),
            if (res.booking != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.booking!.venueName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ref: #${res.booking!.bookingRef}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Status: CONFIRMED & CHECKED IN',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    if (res.checkedInAt != null)
                      Text(
                        'Time: ${DateFormat.jm().format(res.checkedInAt!)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(qrCheckInNotifierProvider.notifier).dismissResult();
            },
            child: const Text('Done'),
          ),
        ],
      ),
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
                  : Colors.black.withOpacity(0.6),
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

class _ViewfinderReticlePainter extends CustomPainter {
  _ViewfinderReticlePainter({
    required this.progress,
    required this.isTorchOn,
  });

  final double progress;
  final bool isTorchOn;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final reticleSize = (w < h ? w : h) * 0.65;
    final left = (w - reticleSize) / 2;
    final top = (h - reticleSize) / 2;
    final rect = Rect.fromLTWH(left, top, reticleSize, reticleSize);

    // Torch glow background simulation
    if (isTorchOn) {
      final torchPaint = Paint()
        ..color = Colors.amber.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), torchPaint);
    }

    // Corner bracket markers
    final bracketPaint = Paint()
      ..color = AppTheme.brand
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;

    // Top-Left
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLen), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(left + reticleSize, top), Offset(left + reticleSize - cornerLen, top), bracketPaint);
    canvas.drawLine(Offset(left + reticleSize, top), Offset(left + reticleSize, top + cornerLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, top + reticleSize), Offset(left + cornerLen, top + reticleSize), bracketPaint);
    canvas.drawLine(Offset(left, top + reticleSize), Offset(left, top + reticleSize - cornerLen), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(left + reticleSize, top + reticleSize), Offset(left + reticleSize - cornerLen, top + reticleSize), bracketPaint);
    canvas.drawLine(Offset(left + reticleSize, top + reticleSize), Offset(left + reticleSize, top + reticleSize - cornerLen), bracketPaint);

    // Laser scanning line
    final scanY = top + (reticleSize * progress);
    final laserPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(left + 8, scanY),
      Offset(left + reticleSize - 8, scanY),
      laserPaint,
    );

    // Laser glow gradient
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00E676).withOpacity(0.25),
          const Color(0xFF00E676).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(left + 8, scanY - 20, reticleSize - 16, 20));

    canvas.drawRect(
      Rect.fromLTWH(left + 8, scanY - 20, reticleSize - 16, 20),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderReticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isTorchOn != isTorchOn;
  }
}

ShapeBorder RoundedCornerShape(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

