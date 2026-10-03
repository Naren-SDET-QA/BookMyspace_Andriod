import 'package:bookmyspace/features/owner_bookings/infrastructure/supabase_owner_booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('owner decision routing', () {
    test('booking requests go through the approval RPCs', () {
      expect(
        SupabaseOwnerBookingRepository.routesThroughApprovalRpc(
          'awaiting_owner_approval',
        ),
        isTrue,
      );
    });

    test(
      'a request an admin already approved (pending payment) never reaches '
      'the legacy confirm path',
      () {
        // The approval RPC answers ALREADY_PROCESSED; the legacy
        // owner-booking-manage path would have confirmed an unpaid booking.
        expect(
          SupabaseOwnerBookingRepository.routesThroughApprovalRpc('pending'),
          isTrue,
        );
      },
    );

    test('already decided or unknown statuses use the approval RPCs', () {
      for (final status in [
        'owner_rejected',
        'approval_expired',
        'cancelled',
        'confirmed',
        null,
      ]) {
        expect(
          SupabaseOwnerBookingRepository.routesThroughApprovalRpc(status),
          isTrue,
          reason: '$status',
        );
      }
    });

    test('only the legacy pending_owner_approval state uses the edge path', () {
      expect(
        SupabaseOwnerBookingRepository.routesThroughApprovalRpc(
          'pending_owner_approval',
        ),
        isFalse,
      );
    });
  });
}
