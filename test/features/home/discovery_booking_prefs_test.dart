import 'package:bookmyspace/features/home/presentation/discovery_booking_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery booking prefs start at today with 2 guests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = container.read(discoveryBookingPrefsProvider);
    final now = DateTime.now();
    expect(prefs.day.year, now.year);
    expect(prefs.day.month, now.month);
    expect(prefs.day.day, now.day);
    expect(prefs.guests, 2);
  });

  test('date and guests are updated only by user actions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(discoveryBookingPrefsProvider.notifier).setGuests(8);
    container
        .read(discoveryBookingPrefsProvider.notifier)
        .setDate(DateTime(2026, 12, 25));
    final prefs = container.read(discoveryBookingPrefsProvider);
    expect(prefs.guests, 8);
    expect(prefs.day, DateTime(2026, 12, 25));
  });

  test('guest count below 1 is ignored', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(discoveryBookingPrefsProvider.notifier).setGuests(0);
    expect(container.read(discoveryBookingPrefsProvider).guests, 2);
  });
}
