import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';
import '../infrastructure/supabase_booking_repository.dart';
import '../infrastructure/caching_booking_repository.dart';
import '../../../core/offline/offline_providers.dart';
import '../domain/invoice_repository.dart';
import '../infrastructure/supabase_invoice_repository.dart';

/// Booking repository instance.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return CachingBookingRepository(
    SupabaseBookingRepository(client),
    ref.watch(offlineCacheProvider),
    cacheScope: ref.watch(currentUserProvider)?.id,
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return SupabaseInvoiceRepository(ref.watch(supabaseProvider));
});

final invoiceArtifactProvider = FutureProvider.autoDispose
    .family<InvoiceArtifact, String>((ref, bookingId) {
      return ref.watch(invoiceRepositoryProvider).generate(bookingId);
    });

/// Availability of the venue's slots for a given (venueId, date) pair.
final slotAvailabilityProvider = FutureProvider.autoDispose
    .family<List<SlotAvailability>, SlotAvailabilityQuery>((ref, query) {
  return ref
      .watch(bookingRepositoryProvider)
      .availableTimeSlots(venueId: query.venueId, date: query.date);
});

/// The signed-in user's bookings, newest first.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.watch(bookingRepositoryProvider).myBookings();
  try {
    await ref.read(bookingReminderSchedulerProvider).sync(bookings);
  } catch (_) {
    // Local reminders must never block the bookings list or email outbox.
  }
  return bookings;
});

/// Phase 9XM-3: a small, bounded preview of the signed-in user's most
/// recent bookings, for Home's recent-bookings row. Home never needs the
/// complete history, so this avoids triggering the unbounded [myBookings]
/// fetch just to show a short preview.
final recentBookingsProvider = FutureProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).recentBookings(limit: 5);
});

/// Whether the signed-in user has any booking at [venueId] that has passed
/// owner approval (pending payment, confirmed, or completed).
///
/// Backs contact reveal on listing details: the owner's direct phone is
/// masked until the customer has a booking the owner accepted, mirroring the
/// Android reference's "numbers unlock on booking confirmation" rule. Read
/// from the same bounded recent-bookings fetch the screen already uses.
final hasApprovedBookingForVenueProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, venueId) {
  return ref
      .watch(bookingRepositoryProvider)
      .myBookings()
      .then(
        (bookings) => bookings.any(
          (b) =>
              b.venueId == venueId &&
              (b.status == BookingStatus.pending ||
                  b.status == BookingStatus.confirmed ||
                  b.status == BookingStatus.completed),
        ),
      );
});

/// Count of the signed-in user's bookings that genuinely need their
/// attention right now -- awaiting owner approval or a pending payment.
/// Real data only: derived from [recentBookingsProvider]'s bounded preview
/// (the same list Home already fetches), never a fabricated or placeholder
/// number. Backs the Bottom nav's "My Bookings" badge.
final actionableBookingsCountProvider = Provider<int>((ref) {
  final bookings = ref.watch(recentBookingsProvider).valueOrNull ?? const [];
  return bookings
      .where(
        (b) =>
            b.status == BookingStatus.pending ||
            b.status == BookingStatus.awaitingOwnerApproval,
      )
      .length;
});

/// Single booking from the caller's readable set. Never invents a row.
///
/// Phase 9XM-3: fetches the booking directly by id instead of searching
/// [myBookingsProvider]'s in-memory list, so a valid booking remains
/// navigable regardless of whether it happens to be loaded anywhere else
/// (e.g. outside the currently loaded page of [myBookingsPageProvider]).
final bookingByIdProvider =
    FutureProvider.autoDispose.family<Booking?, String>((ref, bookingId) {
  return ref.watch(bookingRepositoryProvider).bookingById(bookingId);
});

/// Phase 9XM-3: page size for [myBookingsPageProvider]'s server-side
/// pagination of My Bookings.
const int myBookingsPageSize = 20;

/// Phase 9XM-3: paginated state for the My Bookings screen. Loaded pages
/// accumulate in [bookings]; [hasMore] is false once a page comes back
/// shorter than [myBookingsPageSize].
class MyBookingsPageState {
  const MyBookingsPageState({
    this.bookings = const [],
    this.isLoadingFirstPage = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Booking> bookings;
  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  MyBookingsPageState copyWith({
    List<Booking>? bookings,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return MyBookingsPageState(
      bookings: bookings ?? this.bookings,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Phase 9XM-3: drives paginated loading for the My Bookings screen.
///
/// Ordering, filters, and ownership/RLS are unchanged from the original
/// unbounded [myBookings] query -- only the fetch is now split into
/// [myBookingsPageSize]-row pages via [BookingRepository.myBookingsPage].
/// A single in-flight guard (`_isFetching`) prevents duplicate concurrent
/// requests from a fast double-scroll or an overlapping refresh.
class MyBookingsPageController extends StateNotifier<MyBookingsPageState> {
  MyBookingsPageController(this._repository)
      : super(const MyBookingsPageState()) {
    _loadFirstPage();
  }

  final BookingRepository _repository;
  bool _isFetching = false;

  Future<void> _loadFirstPage() async {
    if (_isFetching) return;
    _isFetching = true;
    state = state.copyWith(
      isLoadingFirstPage: true,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final page = await _repository.myBookingsPage(
        offset: 0,
        limit: myBookingsPageSize,
      );
      state = MyBookingsPageState(
        bookings: page,
        isLoadingFirstPage: false,
        isLoadingMore: false,
        hasMore: page.length == myBookingsPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingFirstPage: false, error: e);
    } finally {
      _isFetching = false;
    }
  }

  /// Resets to page 1 and discards previously loaded pages -- used by
  /// pull-to-refresh and realtime invalidation, per the requirement that
  /// refresh must reset to page 1 rather than append.
  Future<void> refresh() => _loadFirstPage();

  /// Loads the next page and appends it, unless a fetch is already in
  /// flight, the first page hasn't finished loading yet, or a previous
  /// page already came back short (no more rows).
  Future<void> loadNextPage() async {
    if (_isFetching || state.isLoadingFirstPage || !state.hasMore) return;
    _isFetching = true;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.myBookingsPage(
        offset: state.bookings.length,
        limit: myBookingsPageSize,
      );
      state = state.copyWith(
        bookings: [...state.bookings, ...page],
        isLoadingMore: false,
        hasMore: page.length == myBookingsPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    } finally {
      _isFetching = false;
    }
  }
}

/// Phase 9XM-3: paginated My Bookings provider. `autoDispose` because this
/// state is screen-scoped -- when My Bookings is popped, its loaded pages
/// are discarded, and the next visit starts fresh from page 1 (safe: this
/// is a new provider with no other consumers to preserve continuity for).
final myBookingsPageProvider = StateNotifierProvider.autoDispose<
    MyBookingsPageController, MyBookingsPageState>((ref) {
  return MyBookingsPageController(ref.watch(bookingRepositoryProvider));
});

/// The currently selected booking date (reset per screen visit).
final selectedBookingDateProvider = StateProvider<DateTime?>((ref) => null);

/// The currently selected slot availability (reset per screen visit).
final selectedSlotProvider = StateProvider<SlotAvailability?>((ref) => null);

/// Key for the slot availability family.
class SlotAvailabilityQuery {
  const SlotAvailabilityQuery({required this.venueId, required this.date});

  final String venueId;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is SlotAvailabilityQuery &&
      other.venueId == venueId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(venueId, date);
}
