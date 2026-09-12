import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_providers.dart';
import '../../owner_venues/presentation/providers/owner_venue_providers.dart';
import '../../venues/domain/venue.dart';
import '../domain/owner.dart';
import '../infrastructure/supabase_owner_repository.dart';

/// Owner repository instance.
final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseOwnerRepository(client);
});

/// Current owner profile (null if not an owner).
final currentOwnerProvider = FutureProvider<Owner?>((ref) {
  // Re-evaluate the profile whenever the canonical auth session changes.
  ref.watch(currentUserProvider);
  return ref.watch(ownerRepositoryProvider).currentOwner();
});

/// Sign in with email/password for owners.
final ownerSignInProvider = FutureProvider.autoDispose
    .family<Owner, ({String email, String password})>((ref, params) async {
  return ref.watch(ownerRepositoryProvider).signInWithEmailPassword(
        params.email,
        params.password,
      );
});

/// Create a new owner profile.
final createOwnerProvider = FutureProvider.autoDispose
    .family<Owner, ({String email, String name, String password})>(
        (ref, params) async {
  return ref.watch(ownerRepositoryProvider).createOwner(
        email: params.email,
        name: params.name,
        password: params.password,
      );
});

/// Bookings RLS-visible to the current venue owner.
final ownerVenueBookingsProvider = FutureProvider<List<Booking>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(bookingRepositoryProvider).ownerVenueBookings();
});

class OwnerDashboardSnapshot {
  const OwnerDashboardSnapshot({
    required this.venueCount,
    required this.bookingCount,
    required this.pendingCount,
    required this.confirmedRevenue,
  });

  final int venueCount;
  final int bookingCount;
  final int pendingCount;
  final double confirmedRevenue;
}

final ownerDashboardSnapshotProvider =
    FutureProvider<OwnerDashboardSnapshot>((ref) async {
  final venues = await ref.watch(myVenuesProvider.future);
  final bookings = await ref.watch(ownerVenueBookingsProvider.future);
  final venueIds = venues.map((Venue venue) => venue.id).toSet();
  final scoped = venueIds.isEmpty
      ? bookings
      : bookings.where((booking) => venueIds.contains(booking.venueId)).toList();
  final pending = scoped
      .where((booking) =>
          booking.status == BookingStatus.pending ||
          booking.status == BookingStatus.held)
      .length;
  final revenue = scoped
      .where((booking) => booking.status == BookingStatus.confirmed)
      .fold<double>(0, (sum, booking) => sum + booking.totalAmount);
  return OwnerDashboardSnapshot(
    venueCount: venues.length,
    bookingCount: scoped.length,
    pendingCount: pending,
    confirmedRevenue: revenue,
  );
});
