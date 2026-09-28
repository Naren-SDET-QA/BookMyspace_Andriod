import 'booking.dart';

/// Per-date availability level (reference BookMySpaceRepository
/// getDateAvailability): free slots 0 -> sold out, <=2 -> limited,
/// <=5 -> filling fast, past date -> past.
enum DateAvailabilityStatus { available, fillingFast, limited, soldOut, past }

class DateAvailability {
  const DateAvailability({
    required this.status,
    required this.freeSlots,
    required this.totalSlots,
  });

  final DateAvailabilityStatus status;
  final int freeSlots;
  final int totalSlots;

  /// Booking must be disabled for sold-out and past dates.
  bool get isBookable =>
      status != DateAvailabilityStatus.soldOut &&
      status != DateAvailabilityStatus.past;

  /// Badge text, or null when no badge should be shown (plenty available).
  String? get label => switch (status) {
    DateAvailabilityStatus.soldOut => 'Sold out',
    DateAvailabilityStatus.limited => 'Limited',
    DateAvailabilityStatus.fillingFast => 'Filling fast',
    DateAvailabilityStatus.past => 'Past',
    DateAvailabilityStatus.available => null,
  };

  /// Evaluates the slots already loaded for [date]. An empty slot list (no
  /// slots configured) is treated as available, matching the reference.
  static DateAvailability evaluate(
    List<SlotAvailability> slots,
    DateTime date, {
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    if (_day(date).isBefore(today)) {
      return DateAvailability(
        status: DateAvailabilityStatus.past,
        freeSlots: 0,
        totalSlots: slots.length,
      );
    }
    final free = slots.where((slot) => slot.isAvailable).length;
    final status = slots.isEmpty
        ? DateAvailabilityStatus.available
        : free == 0
        ? DateAvailabilityStatus.soldOut
        : free <= 2
        ? DateAvailabilityStatus.limited
        : free <= 5
        ? DateAvailabilityStatus.fillingFast
        : DateAvailabilityStatus.available;
    return DateAvailability(
      status: status,
      freeSlots: free,
      totalSlots: slots.length,
    );
  }

  /// Other free slots on the same date, excluding [excludeSlotId]
  /// (reference getAlternativeSlots).
  static List<SlotAvailability> alternatives(
    List<SlotAvailability> slots, {
    String? excludeSlotId,
  }) => slots
      .where(
        (slot) =>
            slot.isAvailable &&
            (excludeSlotId == null || slot.slotId != excludeSlotId),
      )
      .toList(growable: false);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
