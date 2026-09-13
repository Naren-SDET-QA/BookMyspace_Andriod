import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../booking/domain/booking.dart';
import '../../domain/qr_check_in.dart';
import '../qr_checkin_providers.dart';
import '../widgets/qr_camera_scanner.dart';
import '../widgets/qr_code_pass_widget.dart';

/// Camera QR scanning and digital entry pass display for venue check-in.
///
/// Two modes: scanning a guest's pass with the live camera, and presenting the
/// signed-in user's own pass. Scanning is performed by [QrCameraScanner] and
/// verified by the server; this screen owns neither the camera nor the verdict.
class QrCheckInScannerScreen extends ConsumerStatefulWidget {
  const QrCheckInScannerScreen({super.key});

  @override
  ConsumerState<QrCheckInScannerScreen> createState() =>
      _QrCheckInScannerScreenState();
}

class _QrCheckInScannerScreenState extends ConsumerState<QrCheckInScannerScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0; // 0: Scan QR Code, 1: My Entry Pass QR
  final TextEditingController _manualInputController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (!mounted || _selectedTab == _tabController.index) return;
    setState(() => _selectedTab = _tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
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
              'Passes are verified on the server',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mode Tabs (0: Scan QR Code, 1: My Entry Pass QR)
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📷 ', style: TextStyle(fontSize: 14)),
                      Text('Scan QR Code',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎫 ', style: TextStyle(fontSize: 14)),
                      Text('My Entry Pass QR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: _selectedTab == 0
                ? _buildScannerTab(theme, qrState)
                : _buildMyPassTab(theme, confirmedBookings),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab(ThemeData theme, QrCheckInState qrState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live camera viewfinder. When the camera cannot run, the widget says
          // why, and the manual entry below is the fallback.
          QrCameraScanner(
            key: const Key('qr_camera_viewfinder'),
            onDetected: _performCheckIn,
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
                            hintText: 'Enter your booking reference',
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
                          // This button shares a Row with the Expanded
                          // input. The app-wide fromHeight style otherwise
                          // contributes an infinite minimum width here.
                          minimumSize: const Size(0, 52),
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
          ...confirmedBookings
              .map((booking) => _buildQrPassCard(theme, booking)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      // No invoice and no downloadable pass exist yet. Show the
                      // reference staff can key in manually rather than claiming
                      // an artifact that was never generated.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Pass reference: #${booking.bookingRef}'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.confirmation_number_outlined,
                        size: 16),
                    label:
                        const Text('Pass Ref', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedCornerShape(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        isCheckedIn ? null : () => _performCheckIn(booking.id),
                    icon: const Icon(Icons.how_to_reg, size: 16),
                    label: Text(
                      isCheckedIn ? 'Verified' : 'Check In Now',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
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
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
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

OutlinedBorder RoundedCornerShape(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
