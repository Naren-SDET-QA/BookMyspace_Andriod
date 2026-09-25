import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/booking.dart';
import '../booking_providers.dart';

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
          'Request sent to venue owner',
          'The owner is reviewing your exact date and time. Payment will become available only after approval.',
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(
              icon,
              size: 64,
              color: color,
            ),
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
            const Spacer(),
            if (booking.canPay) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/bookings/${booking.id}/pay',
                    extra: booking,
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Pay securely'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.bookings),
                child: Text(l10n.viewBookings),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}
