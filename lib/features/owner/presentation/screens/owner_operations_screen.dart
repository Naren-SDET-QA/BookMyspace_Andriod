import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../owner_bookings/presentation/owner_booking_providers.dart';
import '../../../owner_bookings/presentation/screens/create_offline_booking_screen.dart';
import '../../../owner_bookings/presentation/screens/owner_bookings_screen.dart';
import '../../../owner_venues/presentation/providers/owner_venue_providers.dart';

enum OwnerOperation { availability, bookings, offlineBooking, payments }

/// Phase-1 owner operations entry point backed by PROD repositories/screens.
class OwnerOperationsScreen extends ConsumerWidget {
  const OwnerOperationsScreen({super.key, required this.operation});

  final OwnerOperation operation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (operation == OwnerOperation.bookings) {
      return const OwnerBookingsScreen();
    }
    if (operation == OwnerOperation.offlineBooking) {
      return const CreateOfflineBookingScreen();
    }
    if (operation == OwnerOperation.availability) {
      return _AvailabilityHub(ref: ref);
    }
    return const _OwnerPaymentsScreen();
  }
}

class _AvailabilityHub extends StatelessWidget {
  const _AvailabilityHub({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(myVenuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Add a venue first.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final venue = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(venue.name),
                      subtitle: Text(venue.city),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        AppRoutes.ownerVenueAvailabilityPath(venue.id),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OwnerPaymentsScreen extends ConsumerWidget {
  const _OwnerPaymentsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(ownerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & receipts')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No owner payments yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final booking = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('₹${booking.totalAmount.toStringAsFixed(2)}'),
                      subtitle: Text(
                        '${booking.bookingRef} • ${booking.status.dbValue}',
                      ),
                      trailing: booking.canViewInvoice
                          ? IconButton(
                              tooltip: 'View receipt',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => context.push(
                                AppRoutes.bookingReceipt.replaceFirst(
                                  ':id',
                                  booking.id,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
