import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_event.dart';
import 'package:bookmyspace/features/analytics/domain/analytics_event_repository.dart';
import 'package:bookmyspace/features/analytics/presentation/analytics_providers.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/support/domain/support_ticket.dart';
import 'package:bookmyspace/features/support/domain/support_ticket_repository.dart';
import 'package:bookmyspace/features/support/presentation/support_providers.dart';
import 'package:bookmyspace/features/venue_sections/presentation/venue_section_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../reviews/mock_review_repository.dart';
import 'mock_venue_repository.dart';

class _FakeSupport implements SupportTicketRepository {
  final created = <({String subject, String description, String category})>[];

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    created.add((
      subject: subject,
      description: description,
      category: category,
    ));
    return SupportTicket(
      id: 't1',
      subject: subject,
      description: description,
      category: category,
      priority: priority,
      status: TicketStatus.open,
    );
  }

  @override
  Future<List<SupportTicket>> myTickets() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalytics implements AnalyticsEventRepository {
  final events = <AnalyticsEvent>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event);

  @override
  Future<List<AnalyticsEvent>> recentEvents({int limit = 50}) async => events;
}

const _venue = Venue(
  id: 'v-enq',
  name: 'Sunrise Function Hall',
  city: 'Hyderabad',
  latitude: 17.4,
  longitude: 78.4,
  category: VenueCategory(id: 'c', slug: 'function_hall', name: 'Halls'),
);

void main() {
  testWidgets('logs view_venue_details and files an enquiry ticket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final support = _FakeSupport();
    final analytics = _FakeAnalytics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(
            MockVenueRepository()..seedVenue(_venue),
          ),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
          publishedVenueSectionsProvider.overrideWith(
            (ref, id) async => const [],
          ),
          moduleEnabledProvider.overrideWith((ref, id) => true),
          supportTicketRepositoryProvider.overrideWithValue(support),
          analyticsRepositoryProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const VenueDetailsScreen(venueId: 'v-enq'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      analytics.events.map((e) => e.eventType),
      contains(AnalyticsEventType.viewVenueDetails),
    );
    expect(analytics.events.first.properties['venue_id'], 'v-enq');
    expect(AnalyticsEventType.selectTimeSlot.dbValue, 'select_time_slot');

    final enquiry = find.byKey(const Key('listing_send_enquiry'));
    await tester.scrollUntilVisible(
      enquiry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The peace-of-mind card sits above this action, so the button can be
    // built in the cache while its center is still below a 900px phone.
    await tester.ensureVisible(enquiry);
    await tester.pumpAndSettle();
    await tester.tap(enquiry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('venue_enquiry_sheet')), findsOneWidget);

    // Empty message is rejected.
    await tester.tap(find.byKey(const Key('venue_enquiry_send')));
    await tester.pumpAndSettle();
    expect(support.created, isEmpty);

    await tester.enterText(
      find.byKey(const Key('venue_enquiry_message')),
      'Is it free on Diwali?',
    );
    await tester.tap(find.byKey(const Key('venue_enquiry_send')));
    await tester.pumpAndSettle();

    expect(support.created, hasLength(1));
    expect(support.created.single.subject, contains('Sunrise Function Hall'));
    expect(support.created.single.subject, contains('v-enq'));
    expect(support.created.single.category, 'venue');
    expect(find.byKey(const Key('venue_enquiry_sheet')), findsNothing);
    expect(find.textContaining('Enquiry sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
