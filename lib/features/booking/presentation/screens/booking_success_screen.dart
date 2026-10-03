import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/presentation/widgets/live_brand.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/booking.dart';
import '../booking_providers.dart';
import '../widgets/booking_progress_tracker.dart';
import '../widgets/booking_start_countdown.dart';

/// Dedicated confirmation surface after the server confirms a booking.
///
/// Client checkout success is not enough to reach this screen; callers must
/// pass a booking id whose status is already confirmed (or still pending
/// while the webhook is in flight).
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingByIdProvider(bookingId));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBookings)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return ErrorView(
              message: 'This booking could not be found.',
              onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
            );
          }
          return _ConfirmedBody(booking: booking);
        },
      ),
    );
  }
}

class _ConfirmedBody extends StatelessWidget {
  const _ConfirmedBody({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final (title, message, icon, color) = switch (booking.status) {
      BookingStatus.confirmed => (
        l10n.bookingConfirmed,
        'Your space is reserved. A check-in pass is available from Bookings.',
        Icons.check_circle_rounded,
        AppTheme.success,
      ),
      BookingStatus.awaitingOwnerApproval => (
        booking.ownerDisplayName.isNotEmpty && booking.ownerDisplayName != 'Venue Host'
            ? 'Request sent to ${booking.ownerDisplayName}'
            : 'Request sent to venue owner',
        'The owner is reviewing your exact date and time. Payment will become available once approved.',
        Icons.hourglass_top_rounded,
        theme.colorScheme.primary,
      ),
      BookingStatus.pending => (
        'Payment available',
        'The venue owner accepted your request. Complete payment before the payment window expires.',
        Icons.payments_outlined,
        theme.colorScheme.primary,
      ),
      BookingStatus.ownerRejected => (
        'Request declined',
        booking.rejectionReason ??
            'The venue owner could not accept this request. No payment was taken.',
        Icons.cancel_outlined,
        theme.colorScheme.error,
      ),
      BookingStatus.approvalExpired => (
        'Request expired',
        'The owner approval window ended before a decision. The slot was released and no payment was taken.',
        Icons.timer_off_outlined,
        theme.colorScheme.error,
      ),
      BookingStatus.cancelled => (
        'Booking cancelled',
        'This booking is cancelled. It is not a confirmed reservation.',
        Icons.cancel_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
      _ => (
        'Booking status unavailable',
        'The server returned a status this app does not recognize. No confirmation is shown.',
        Icons.help_outline_rounded,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: LivePulsingBrandMark(size: 64)),
          const SizedBox(height: 12),
          Center(child: Icon(icon, size: 64, color: color)),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BookingProgressTracker(status: booking.status),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text(
                booking.venueName.isNotEmpty
                    ? booking.venueName
                    : booking.bookingRef,
              ),
              subtitle: Text(
                '${booking.status.dbValue} · ${formatInr(booking.totalAmount)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.violet.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          size: 20,
                          color: AppTheme.violet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host & Venue Owner Details',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              booking.ownerOrgName.isNotEmpty
                                  ? booking.ownerOrgName
                                  : (booking.ownerName.isNotEmpty ? booking.ownerName : 'Venue Management'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.violet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Host',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.violet,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (booking.ownerName.isNotEmpty &&
                      booking.ownerName != booking.ownerOrgName) ...[
                    _OwnerDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Owner / Contact',
                      value: booking.ownerName,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (booking.ownerEmail.isNotEmpty) ...[
                    _OwnerDetailRow(
                      icon: Icons.email_outlined,
                      label: 'Owner Email',
                      value: booking.ownerEmail,
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (booking.ownerPhone.isNotEmpty) ...[
                    _OwnerDetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: booking.ownerPhone,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.status == BookingStatus.awaitingOwnerApproval
                                ? 'The booking request was sent directly to this owner for review and slot approval.'
                                : 'For questions regarding this booking, you can contact the owner at the email above.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (booking.status == BookingStatus.confirmed) ...[
            const SizedBox(height: 10),
            BookingStartCountdown(booking: booking),
          ],
          if (booking.receiptNumber != null) ...[
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Receipt ready'),
                subtitle: Text(booking.receiptNumber!),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (booking.canPay) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: buttonStyle,
                onPressed: () =>
                    context.push('/bookings/${booking.id}/pay', extra: booking),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Pay securely'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: buttonStyle,
              onPressed: () => context.go(AppRoutes.bookings),
              child: Text(l10n.viewBookings),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => context.go(AppRoutes.home),
            child: Text(l10n.backToHome),
          ),
        ],
      ),
    );
  }
}

class _OwnerDetailRow extends StatelessWidget {
  const _OwnerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlighted ? AppTheme.violet : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              color: isHighlighted ? AppTheme.violet : theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

