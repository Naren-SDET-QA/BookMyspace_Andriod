import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_providers.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/plugins/ai_provider_plugin.dart';
import 'package:bookmyspace/core/modular/provider_registry.dart';
import 'package:bookmyspace/core/modular/register_default_plugins.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/owner/presentation/owner_providers.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../test/features/courses/mock_course_repository.dart';
import '../../test/features/events/mock_event_repository.dart';
import '../../test/features/notifications/mock_notification_repository.dart';
import '../../test/features/owner_bookings/mock_owner_booking_repository.dart';
import '../../test/features/owner_venues/mock_owner_venue_repository.dart';
import '../../test/features/venues/mock_venue_repository.dart';
import 'e2e_fakes.dart';
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
  slotTaken,
  // Phase 2 business flows.
  flakyAvailability,
  slowHold,
  cancelFails,
  confirmedBooking,
  staleHold,
  payFails,
  payCancelledThenPaid,
  payApprovedWhileVerifying,
  orderFailsOnce,
  ownerSignedIn,
  adminSignedIn;

  static MockScenario parse(String? name) => MockScenario.values.firstWhere(
    (scenario) => scenario.name == name,
    orElse: () => MockScenario.signedOut,
  );
}

/// In-memory backend for mock mode: the shared test mocks, no Supabase.
///
/// One booking [store] backs the customer, payment and owner repositories,
/// so a state change made through one role is what the other role reads —
/// the same way the real tables are shared. Tests keep a reference to
/// inspect what the UI asked the backend to do.
class MockBackend {
  MockBackend({AuthUser? user, List<Booking> seededBookings = const []})
    : store = List<Booking>.of(seededBookings) {
    auth = E2eAuthRepository(
      initialUser: user,
      directory: {
        for (final account in const [
          E2eFixtures.customer,
          E2eFixtures.owner,
          E2eFixtures.admin,
        ])
          account.email: account,
      },
    );
    booking = E2eBookingRepository(store);
    payments = E2ePaymentRepository(store);
    checkout = E2eCheckoutService(onPaid: payments.captureLastOrder);
    ownerBookings = MockOwnerBookingRepository(bookings: store);
    owner = E2eOwnerRepository(auth);
    ownerVenues.venues.add(
      MockVenueRepository.defaultVenues
          .firstWhere((v) => v.id == E2eFixtures.venueId)
          .copyWith(isActive: true),
    );
  }

  factory MockBackend.forScenario(MockScenario scenario) {
    final user = switch (scenario) {
      MockScenario.signedOut ||
      MockScenario.invalidLogin ||
      MockScenario.invalidOtp => null,
      MockScenario.ownerSignedIn => E2eFixtures.owner,
      MockScenario.adminSignedIn => E2eFixtures.admin,
      _ => E2eFixtures.customer,
    };
    final pendingB1 = E2eFixtures.seededBooking(
      E2eFixtures.seededBookingId,
      BookingStatus.pending,
    );
    final seeded = switch (scenario) {
      MockScenario.withBookings ||
      MockScenario.cancelFails ||
      MockScenario.payFails ||
      MockScenario.payCancelledThenPaid ||
      MockScenario.payApprovedWhileVerifying ||
      MockScenario.orderFailsOnce => [pendingB1],
      MockScenario.confirmedBooking => [
        E2eFixtures.seededBooking(
          E2eFixtures.confirmedBookingId,
          BookingStatus.confirmed,
          paymentMethod: 'razorpay',
        ),
      ],
      MockScenario.staleHold => [
        E2eFixtures.seededBooking(
          E2eFixtures.staleHoldBookingId,
          BookingStatus.pending,
          metadata: const {'hold_expires_at': '2020-01-01T00:00:00Z'},
        ),
      ],
      MockScenario.ownerSignedIn => [
        E2eFixtures.seededBooking(
          E2eFixtures.approvalBookingId,
          BookingStatus.pendingOwnerApproval,
          paymentMethod: 'pay_at_venue',
        ),
        E2eFixtures.seededBooking(
          E2eFixtures.confirmedBookingId,
          BookingStatus.confirmed,
          paymentMethod: 'razorpay',
        ),
      ],
      _ => const <Booking>[],
    };
    final backend = MockBackend(user: user, seededBookings: seeded);
    backend.auth.failSignIn = scenario == MockScenario.invalidLogin;
    backend.auth.failVerify = scenario == MockScenario.invalidOtp;
    backend.booking.failAvailability = scenario == MockScenario.networkFailure;
    backend.booking.failAcquire = scenario == MockScenario.slotTaken;
    backend.booking.failCancel = scenario == MockScenario.cancelFails;
    if (scenario == MockScenario.flakyAvailability) {
      backend.booking.failAvailabilityTimes = 1;
    }
    if (scenario == MockScenario.slowHold) {
      backend.booking.acquireDelay = const Duration(milliseconds: 1500);
    }
    if (scenario == MockScenario.orderFailsOnce) {
      backend.payments.failCreateOrderTimes = 1;
    }
    switch (scenario) {
      case MockScenario.payFails:
        backend.checkout.script.add(CheckoutResult.failed);
      case MockScenario.payCancelledThenPaid:
        backend.checkout.script
          ..add(CheckoutResult.cancelled)
          ..add(CheckoutResult.paid);
      case MockScenario.payApprovedWhileVerifying:
        backend.checkout.script.add(CheckoutResult.paid);
        backend.payments.approveAfterStatusReads = 2;
      default:
        break;
    }
    return backend;
  }

  /// Shared booking table for every role.
  final List<Booking> store;

  late final E2eAuthRepository auth;
  late final E2eBookingRepository booking;
  late final E2ePaymentRepository payments;
  late final E2eCheckoutService checkout;
  late final MockOwnerBookingRepository ownerBookings;
  late final E2eOwnerRepository owner;
  final MockVenueRepository venues = MockVenueRepository();
  final MockOwnerVenueRepository ownerVenues = MockOwnerVenueRepository();
  final E2eOwnerAvailabilityRepository ownerAvailability =
      E2eOwnerAvailabilityRepository();

  /// Current status of [bookingId] in the shared store.
  BookingStatus? statusOf(String bookingId) =>
      store.where((b) => b.id == bookingId).firstOrNull?.status;

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
    // Production rebuilds the booking repository per signed-in user
    // (`cacheScope: currentUser.id`), which refreshes the history on an
    // account switch. Keep that dependency; the data stays in [store].
    bookingRepositoryProvider.overrideWith((ref) {
      ref.watch(currentUserProvider);
      // A new instance per user, as in production (see the class docs).
      return E2eUserBookingRepository(booking);
    }),
    paymentRepositoryProvider.overrideWithValue(payments),
    checkoutServiceProvider.overrideWithValue(checkout),
    ownerRepositoryProvider.overrideWithValue(owner),
    ownerBookingRepositoryProvider.overrideWithValue(ownerBookings),
    ownerVenueRepositoryProvider.overrideWithValue(ownerVenues),
    ownerAvailabilityRepositoryProvider.overrideWithValue(ownerAvailability),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    notificationRepositoryProvider.overrideWithValue(
      MockNotificationRepository(),
    ),
    providerRegistryProvider.overrideWith(_offlinePluginRegistry),
  ];
}

/// The production plugin registry, except the flutter_map plugin is not
/// exposed, so map surfaces render nothing and never request OpenStreetMap
/// tiles. E2E must not depend on the network: a tile request still in flight
/// when a test ends fails that test with a SocketException.
ProviderRegistry _offlinePluginRegistry(Ref ref) {
  final features = ref.watch(featureRegistryProvider);
  final plugins = ProviderRegistry(
    features: FeatureRegistry({
      for (final id in FeatureId.values)
        id: id == FeatureId.maps
            ? features.configOf(id).copyWith(enabled: false)
            : features.configOf(id),
    }),
  );
  registerDefaultPlugins(
    plugins,
    aiFactory: () => SupabaseAiProvider(ref.read(supabaseProvider)),
  );
  return plugins;
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
