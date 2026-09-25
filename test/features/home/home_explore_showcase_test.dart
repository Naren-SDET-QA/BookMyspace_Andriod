import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:bookmyspace/features/home/presentation/widgets/home_explore_showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Harness {
  final opened = <MainHomeSection>[];
  var exploreAll = 0;

  GoRouter router() {
    Widget page(String name) => Scaffold(body: Text('page:$name'));
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HomeExploreShowcase(
                venues: const [],
                locationLabel: 'Hyderabad',
                onOpenSection: opened.add,
                onExploreAll: () => exploreAll++,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.education,
          builder: (_, __) => page('education'),
        ),
        GoRoute(
          path: AppRoutes.coursesList,
          builder: (_, __) => page('courses'),
        ),
        GoRoute(path: AppRoutes.bookings, builder: (_, __) => page('bookings')),
        GoRoute(path: AppRoutes.saved, builder: (_, __) => page('saved')),
      ],
    );
  }
}

Future<GoRouter> _pump(WidgetTester tester, _Harness h, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = h.router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(360, 800), Size(390, 844), Size(1280, 900)]) {
    testWidgets('lays out without overflow at ${size.width.toInt()}px', (
      tester,
    ) async {
      await _pump(tester, _Harness(), size);
      expect(tester.takeException(), isNull);
      for (final title in [
        'Spaces',
        'Institutes',
        'Classes',
        'PG / Hostels',
        'Stays',
        'Sports',
        'Book Smarter\nLive Better',
        'Your Space Radar',
        'Recent Bookings',
        'Saved Spaces',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.textContaining('near Hyderabad'), findsOneWidget);
    });
  }

  testWidgets('venue tiles open their Home search section', (tester) async {
    final h = _Harness();
    await _pump(tester, h, const Size(390, 844));
    await _tap(tester, 'showcase-spaces');
    await _tap(tester, 'showcase-pg');
    await _tap(tester, 'showcase-stays');
    await _tap(tester, 'showcase-sports');
    expect(h.opened, [
      MainHomeSection.functionHalls,
      MainHomeSection.pgHostels,
      MainHomeSection.lodgeRooms,
      MainHomeSection.sportsTurfs,
    ]);
  });

  testWidgets('Explore Now and Radar View all open search', (tester) async {
    final h = _Harness();
    await _pump(tester, h, const Size(390, 844));
    await _tap(tester, 'showcase-explore-now');
    await _tap(tester, 'showcase-radar-view-all');
    expect(h.exploreAll, 2);
  });

  for (final (key, page) in const [
    ('showcase-institutes', 'education'),
    ('showcase-classes', 'courses'),
    ('showcase-activity-bookings', 'bookings'),
    ('showcase-activity-saved', 'saved'),
  ]) {
    testWidgets('$key opens $page', (tester) async {
      await _pump(tester, _Harness(), const Size(390, 844));
      await _tap(tester, key);
      expect(find.text('page:$page'), findsOneWidget);
    });
  }
}
