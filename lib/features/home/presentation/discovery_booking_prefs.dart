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
  });

  final DateTime date;
  final int guests;

  DateTime get day => DateTime(date.year, date.month, date.day);

  DiscoveryBookingPrefs copyWith({DateTime? date, int? guests}) {
    return DiscoveryBookingPrefs(
      date: date ?? this.date,
      guests: guests ?? this.guests,
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
}

final discoveryBookingPrefsProvider =
    NotifierProvider<DiscoveryBookingPrefsNotifier, DiscoveryBookingPrefs>(
  DiscoveryBookingPrefsNotifier.new,
);
