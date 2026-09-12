import '../../booking/domain/booking.dart';
import '../../venues/domain/venue.dart';

class VenueBlockedDate {
  const VenueBlockedDate({
    required this.date,
    this.id,
    this.reason,
  });

  final String? id;
  final DateTime date;
  final String? reason;
}

class TimeSlotDraft {
  const TimeSlotDraft({
    this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    this.isActive = true,
  });

  final String? id;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isActive;
}

String? validateTimeSlotDrafts(List<TimeSlotDraft> slots) {
  final active = slots.where((slot) => slot.isActive).toList();
  final timePattern = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
  for (final slot in active) {
    if (slot.label.trim().isEmpty) return 'Each time slot needs a label.';
    if (!timePattern.hasMatch(slot.startTime) ||
        !timePattern.hasMatch(slot.endTime)) {
      return 'Time slots must use a valid start and end time.';
    }
    if (slot.endTime.compareTo(slot.startTime) <= 0) {
      return 'A time slot end must be after its start.';
    }
  }
  for (var i = 0; i < active.length; i++) {
    for (var j = i + 1; j < active.length; j++) {
      final a = active[i];
      final b = active[j];
      if (a.startTime.compareTo(b.endTime) < 0 &&
          a.endTime.compareTo(b.startTime) > 0) {
        return 'Active time slots cannot overlap.';
      }
    }
  }
  return null;
}

/// Contract for owner venue management repository.
abstract interface class OwnerVenueRepository {
  /// Get all venues belonging to the current owner.
  Future<List<Venue>> myVenues();

  /// Create a new venue.
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
    String? address,
    String? pincode,
    List<VenueImage>? images,
    List<String>? facilities,
    String? videoUrl,
    String? tour3dUrl,
  });

  /// Update an existing venue.
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
    String? address,
    String? pincode,
    List<VenueImage>? images,
    List<String>? facilities,
    String? videoUrl,
    String? tour3dUrl,
  });

  /// Soft-delete a venue.
  Future<void> deleteVenue(String venueId);

  Future<String> uploadVenueImage({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  });

  Future<void> deleteStoredImage(String pathOrUrl);

  Future<List<TimeSlot>> listTimeSlots(String venueId);

  Future<void> replaceTimeSlots(String venueId, List<TimeSlotDraft> slots);

  Future<List<VenueBlockedDate>> listBlockedDates(String venueId);

  Future<void> replaceBlockedDates(
    String venueId,
    List<VenueBlockedDate> dates,
  );
}
