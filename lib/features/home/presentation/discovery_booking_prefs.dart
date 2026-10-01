import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Date and guest count the customer set on Home.
///
/// These are *prefills* for Search and the booking flow. They never invent
/// availability or skip listing-template validation: Booking still loads live
/// slots for the date and still requires every required field.
class DiscoveryBookingPrefs {
  const DiscoveryBookingPrefs({
    required this.date,
    this.guests = 2,
    this.checkOut,
    this.rooms = 1,
    this.tenureMonths = 1,
    this.gender,
    this.sharing,
  });

  final DateTime date;
  final int guests;

  /// Hotel check-out. Null means the day after [day]. Not a search filter:
  /// venue search has no stay-range column, and the hold is still one date.
  final DateTime? checkOut;

  /// Hotel room count. Prefills the existing booking "rooms" field.
  final int rooms;

  /// PG stay length in months. Display-only; the rent calculator reads it.
  final int tenureMonths;

  /// PG gender filter token already understood by venue search: `gents`,
  /// `ladies`, or `coliving`. Null means no gender filter.
  final String? gender;

  /// PG sharing token: `single`, `double`, or `triple`.
  final String? sharing;

  DateTime get day => DateTime(date.year, date.month, date.day);

  DateTime get checkOutDay {
    final out = checkOut;
    final fallback = day.add(const Duration(days: 1));
    if (out == null) return fallback;
    final normalized = DateTime(out.year, out.month, out.day);
    if (!normalized.isAfter(day)) return fallback;
    return normalized;
  }

  int get nights {
    final count = checkOutDay.difference(day).inDays;
    return count < 1 ? 1 : count;
  }

  DiscoveryBookingPrefs copyWith({
    DateTime? date,
    int? guests,
    DateTime? checkOut,
    int? rooms,
    int? tenureMonths,
    String? gender,
    String? sharing,
    bool clearGender = false,
    bool clearSharing = false,
  }) {
    return DiscoveryBookingPrefs(
      date: date ?? this.date,
      guests: guests ?? this.guests,
      checkOut: checkOut ?? this.checkOut,
      rooms: rooms ?? this.rooms,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      gender: clearGender ? null : (gender ?? this.gender),
      sharing: clearSharing ? null : (sharing ?? this.sharing),
    );
  }
}

class DiscoveryBookingPrefsNotifier extends Notifier<DiscoveryBookingPrefs> {
  @override
  DiscoveryBookingPrefs build() {
    final now = DateTime.now();
    return DiscoveryBookingPrefs(
      date: DateTime(now.year, now.month, now.day),
    );
  }

  void setDate(DateTime date) {
    state = state.copyWith(
      date: DateTime(date.year, date.month, date.day),
    );
  }

  void setGuests(int guests) {
    if (guests < 1) return;
    state = state.copyWith(guests: guests);
  }

  void setCheckOut(DateTime date) {
    state = state.copyWith(
      checkOut: DateTime(date.year, date.month, date.day),
    );
  }

  void setRooms(int rooms) {
    if (rooms < 1) return;
    state = state.copyWith(rooms: rooms > 8 ? 8 : rooms);
  }

  void setTenureMonths(int months) {
    if (months < 1) return;
    state = state.copyWith(tenureMonths: months > 12 ? 12 : months);
  }

  void setGender(String? gender) {
    if (gender == null || gender.trim().isEmpty) {
      state = state.copyWith(clearGender: true);
      return;
    }
    state = state.copyWith(gender: gender.trim().toLowerCase());
  }

  void setSharing(String? sharing) {
    if (sharing == null || sharing.trim().isEmpty) {
      state = state.copyWith(clearSharing: true);
      return;
    }
    state = state.copyWith(sharing: sharing.trim().toLowerCase());
  }
}

final discoveryBookingPrefsProvider =
    NotifierProvider<DiscoveryBookingPrefsNotifier, DiscoveryBookingPrefs>(
  DiscoveryBookingPrefsNotifier.new,
);
