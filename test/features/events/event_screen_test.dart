import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/events/presentation/screens/event_detail_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_event_repository.dart';

List<Override> _overrides(MockEventRepository events) => [
      eventRepositoryProvider.overrideWithValue(events),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    ];

Widget _detailApp(MockEventRepository repo) {
  return ProviderScope(
    overrides: _overrides(repo),
    child: const MaterialApp(
      home: EventDetailScreen(eventId: 'e1'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget _listApp(MockEventRepository repo) {
  return ProviderScope(
    overrides: _overrides(repo),
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: AppRoutes.eventsList,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
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
  testWidgets('event list shows empty state', (tester) async {
    await tester.pumpWidget(_listApp(MockEventRepository()));
    await tester.pumpAndSettle();
    expect(find.text('No upcoming events'), findsOneWidget);
  });

  testWidgets('event list shows cards and opens detail', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.pumpWidget(_listApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Hyderabad Music Night'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);

    await tester.tap(find.text('Hyderabad Music Night'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.textContaining('Register Now'), findsOneWidget);
  });

  testWidgets('event list error retries', (tester) async {
    final repo = MockEventRepository()..failUpcoming = true;
    await tester.pumpWidget(_listApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    repo
      ..failUpcoming = false
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Hyderabad Music Night'), findsOneWidget);
  });

  testWidgets('shows event details and the register button', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad Music Night'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.textContaining('Register Now'), findsOneWidget);
    expect(find.text('200 seats left'), findsOneWidget);
  });

  testWidgets('registering calls the repository', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Register Now'));
    await tester.pumpAndSettle();

    expect(repo.lastRegisterEventId, 'e1');
    expect(find.text('Cancel Registration'), findsOneWidget);
  });

  testWidgets('registered event can cancel', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [
        MockEventRepository.sampleEvent(
          userRegistered: true,
          registeredCount: 5,
        ),
      ];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Registered'), findsOneWidget);
    await tester.tap(find.text('Cancel Registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.lastCancelEventId, 'e1');
  });

  testWidgets('sold-out event disables registration', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [
        MockEventRepository.sampleEvent(capacity: 10, registeredCount: 10),
      ];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Sold Out'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
