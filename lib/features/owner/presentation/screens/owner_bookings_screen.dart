import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../owner_providers.dart';

class OwnerBookingsScreen extends ConsumerWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(ownerVenueBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venue bookings')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(ownerVenueBookingsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No venue bookings',
                message:
                    'Bookings for spaces you own will appear here after customers reserve them.',
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ownerVenueBookingsProvider);
                  await ref.read(ownerVenueBookingsProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _OwnerBookingTile(booking: items[index]),
                ),
              ),
      ),
    );
  }
}

class _OwnerBookingTile extends StatelessWidget {
  const _OwnerBookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.venueName.isNotEmpty
                        ? booking.venueName
                        : 'Venue booking',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  booking.status.dbValue,
                  style: TextStyle(
                    color: AppTheme.brandDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                booking.bookingRef,
                DateFormat.yMMMd().format(booking.bookDate),
                if (booking.slotLabel.isNotEmpty) booking.slotLabel,
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              formatInr(booking.totalAmount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
