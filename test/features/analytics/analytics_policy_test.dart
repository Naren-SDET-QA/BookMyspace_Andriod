import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_event.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_event_repository.dart';
import 'package:bookmyspace/features/analytics/presentation/analytics_providers.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../offers/mock_coupon_repository.dart';
import '../venues/mock_venue_repository.dart';

class _FakeAnalyticsRepository implements AnalyticsEventRepository {
  @override
  Future<List<AnalyticsEvent>> recentEvents({int limit = 50}) async => const [];

  @override
  Future<void> track(AnalyticsEvent event) async {}
}

Widget _app({required Set<AppRole> roles}) {
  const user = AuthUser(id: 'u1', email: 'a@b.com');
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: user),
      ),
      analyticsRepositoryProvider.overrideWithValue(_FakeAnalyticsRepository()),
      currentUserRolesProvider.overrideWith((ref) async => roles),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
      bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: AppRoutes.analytics,
        currentUser: user,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  test('analytics event types persist as snake_case', () {
    expect(AnalyticsEventType.bookingConfirmed.dbValue, 'booking_confirmed');
    expect(
      AnalyticsEventType.fromDb('support_ticket_resolved'),
      AnalyticsEventType.supportTicketResolved,
    );
  });

  testWidgets('customer is denied analytics', (tester) async {
    await tester.pumpWidget(_app(roles: {AppRole.customer}));
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('venue owner can open analytics', (tester) async {
    await tester.pumpWidget(_app(roles: {AppRole.venueOwner}));
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsNothing);
  });

  testWidgets('administrator can open analytics', (tester) async {
    await tester.pumpWidget(_app(roles: {AppRole.administrator}));
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsNothing);
  });
}
