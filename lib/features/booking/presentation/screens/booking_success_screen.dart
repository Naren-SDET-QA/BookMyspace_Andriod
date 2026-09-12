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
    final confirmed = booking.status == BookingStatus.confirmed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Icon(
              confirmed ? Icons.check_circle_rounded : Icons.hourglass_top,
              size: 64,
              color: confirmed ? AppTheme.success : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              confirmed ? l10n.bookingConfirmed : l10n.awaitingConfirmation,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              confirmed
                  ? 'Your space is reserved. A check-in pass is available from Bookings.'
                  : 'Payment is being confirmed by BookMySpace. This screen updates when the server records the booking.',
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
            const Spacer(),
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
