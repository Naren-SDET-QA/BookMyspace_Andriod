import 'package:bookmyspace/core/errors/app_exceptions.dart' as app_errors;
import 'package:bookmyspace/features/booking/infrastructure/supabase_booking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockFunctionsClient mockFunctions;
  late SupabaseBookingRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockFunctions = MockFunctionsClient();

    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockClient.functions).thenReturn(mockFunctions);

    repository = SupabaseBookingRepository(mockClient);
  });

  group('acquireHold', () {
    test(
      'throws AuthException and never calls the edge function when there '
      'is no current session',
      () async {
        when(() => mockAuth.currentSession).thenReturn(null);

        await expectLater(
          repository.acquireHold(
            venueId: 'venue-1',
            slotId: 'slot-1',
            bookDate: DateTime(2026, 9, 20),
            amount: 1000,
          ),
          throwsA(isA<app_errors.AuthException>()),
        );

        verifyNever(
          () => mockFunctions.invoke(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        );
      },
    );
  });
}
