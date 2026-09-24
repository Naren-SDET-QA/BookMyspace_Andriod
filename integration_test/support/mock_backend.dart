import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../test/features/auth/mock_auth_repository.dart';
import '../../test/features/booking/mock_booking_repository.dart';
import '../../test/features/courses/mock_course_repository.dart';
import '../../test/features/events/mock_event_repository.dart';
import '../../test/features/notifications/mock_notification_repository.dart';
import '../../test/features/payments/mock_payment_repository.dart';
import '../../test/features/venues/mock_venue_repository.dart';
import 'e2e_fixtures.dart';

/// Named, deterministic mock scenarios. Playwright selects one with the
/// `?scenario=<name>` query parameter on the web mock build.
enum MockScenario {
  signedOut,
  signedIn,
  withBookings,
  invalidLogin,
  invalidOtp,
  networkFailure,
  slotTaken;

  static MockScenario parse(String? name) => MockScenario.values.firstWhere(
    (scenario) => scenario.name == name,
    orElse: () => MockScenario.signedOut,
  );
}

/// In-memory backend for mock mode: the shared test mocks, no Supabase.
///
/// Tests keep a reference to inspect what the UI asked the backend to do.
class MockBackend {
  MockBackend({bool signedIn = false, List<String> seededBookingIds = const []})
    : auth = MockAuthRepository(
        initialUser: signedIn ? E2eFixtures.customer : null,
      ),
      booking = MockBookingRepository(
        bookings: [
          for (final id in seededBookingIds)
            MockBookingRepository.sampleBooking(id: id),
        ],
      );

  factory MockBackend.forScenario(MockScenario scenario) {
    final signedIn = switch (scenario) {
      MockScenario.signedOut ||
      MockScenario.invalidLogin ||
      MockScenario.invalidOtp => false,
      _ => true,
    };
    final backend = MockBackend(
      signedIn: signedIn,
      seededBookingIds: scenario == MockScenario.withBookings
          ? const [E2eFixtures.seededBookingId]
          : const [],
    );
    backend.auth.failSignIn = scenario == MockScenario.invalidLogin;
    backend.auth.failVerify = scenario == MockScenario.invalidOtp;
    backend.booking.failAvailability =
        scenario == MockScenario.networkFailure;
    backend.booking.failAcquire = scenario == MockScenario.slotTaken;
    return backend;
  }

  final MockAuthRepository auth;
  final MockBookingRepository booking;
  final MockVenueRepository venues = MockVenueRepository();
  final MockPaymentRepository payments = MockPaymentRepository();
  final FakeCheckoutService checkout = FakeCheckoutService();

  static const authConfiguration = AuthConfiguration(
    authenticationEnabled: true,
    signupEnabled: true,
    emailLoginEnabled: true,
    emailOtpEnabled: true,
    phoneLoginEnabled: true,
    phoneOtpEnabled: true,
    passwordLoginEnabled: true,
  );

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    authConfigurationProvider.overrideWith((ref) async => authConfiguration),
    venueRepositoryProvider.overrideWithValue(venues),
    bookingRepositoryProvider.overrideWithValue(booking),
    paymentRepositoryProvider.overrideWithValue(payments),
    checkoutServiceProvider.overrideWithValue(checkout),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    notificationRepositoryProvider.overrideWithValue(
      MockNotificationRepository(),
    ),
  ];
}

/// The production router and screens, driven by [MockBackend].
///
/// Mirrors `BookMySpaceApp`: the router is rebuilt from the current auth
/// state, so sign-in and sign-out redirect exactly as in the real app.
class E2eMockApp extends ConsumerWidget {
  const E2eMockApp({
    super.key,
    required this.backend,
    this.initialLocation = AppRoutes.shell,
  });

  final MockBackend backend;
  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.hasValue
        ? authState.value
        : backend.auth.currentUser;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
        currentUser: user,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

Widget buildMockApp(
  MockBackend backend, {
  String initialLocation = AppRoutes.shell,
}) {
  return ProviderScope(
    overrides: backend.overrides,
    child: E2eMockApp(backend: backend, initialLocation: initialLocation),
  );
}
