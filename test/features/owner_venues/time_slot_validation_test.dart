import 'package:bookmyspace/features/owner_venues/domain/owner_venue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts non-overlapping active slots', () {
    expect(
      validateTimeSlotDrafts(const [
        TimeSlotDraft(
          label: 'Morning',
          startTime: '08:00:00',
          endTime: '14:00:00',
          priceAmount: 1000,
        ),
        TimeSlotDraft(
          label: 'Evening',
          startTime: '16:00:00',
          endTime: '23:30:00',
          priceAmount: 2000,
        ),
      ]),
      isNull,
    );
  });

  test('rejects overlapping active slots', () {
    expect(
      validateTimeSlotDrafts(const [
        TimeSlotDraft(
          label: 'Morning',
          startTime: '08:00:00',
          endTime: '14:00:00',
          priceAmount: 1000,
        ),
        TimeSlotDraft(
          label: 'Full day',
          startTime: '00:00:00',
          endTime: '23:59:00',
          priceAmount: 3000,
        ),
      ]),
      contains('overlap'),
    );
  });

  test('inactive overlapping slots are allowed', () {
    expect(
      validateTimeSlotDrafts(const [
        TimeSlotDraft(
          label: 'Morning',
          startTime: '08:00:00',
          endTime: '14:00:00',
          priceAmount: 1000,
        ),
        TimeSlotDraft(
          label: 'Full day',
          startTime: '00:00:00',
          endTime: '23:59:00',
          priceAmount: 3000,
          isActive: false,
        ),
      ]),
      isNull,
    );
  });

  test('rejects end before start', () {
    expect(
      validateTimeSlotDrafts(const [
        TimeSlotDraft(
          label: 'Broken',
          startTime: '18:00:00',
          endTime: '09:00:00',
          priceAmount: 1,
        ),
      ]),
      isNotNull,
    );
  });
}
