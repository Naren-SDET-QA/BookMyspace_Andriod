import 'dart:async';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/localization/marketplace_strings.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/home/presentation/discovery_location.dart';
import 'package:bookmyspace/features/marketplace/domain/marketplace_catalog.dart';
import 'package:bookmyspace/features/marketplace/presentation/marketplace_entry_card.dart';
import 'package:bookmyspace/features/marketplace/presentation/marketplace_providers.dart';
import 'package:bookmyspace/features/marketplace/presentation/marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _event = MarketplaceItem(
  id: '00000000-0000-4000-8000-000000000001',
  entity: MarketplaceEntity.event,
  category: MarketplaceCategory.events,
  title: 'Evening music workshop',
  city: 'Hyderabad',
  price: 500,
);

class _Catalog implements MarketplaceRepository {
  final queries = <MarketplaceQuery>[];
  Future<List<MarketplaceItem>> Function(MarketplaceQuery)? respond;
  @override
  Future<List<MarketplaceItem>> search(MarketplaceQuery query) async {
    queries.add(query);
    return respond == null ? [_event] : respond!(query);
  }
}

Widget _app(
  _Catalog repo, {
  Locale locale = const Locale('en'),
  ProviderContainer? container,
  GoRouter? router,
  double textScale = 1,
}) {
  final child = MaterialApp.router(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig:
        router ??
        GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const MarketplaceScreen()),
          ],
        ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
  if (container != null)
    return UncontrolledProviderScope(container: container, child: child);
  return ProviderScope(
    overrides: [
      marketplaceRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(null),
    ],
    child: child,
  );
}

void main() {
  testWidgets('debounces search and requests filters from the repository', (
    tester,
  ) async {
    final repo = _Catalog();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text(_event.title), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('marketplace-search')),
      'music',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.queries.last.text, '');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(repo.queries.last.text, 'music');
    await tester.tap(find.byKey(const Key('marketplace-category-events')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.category, MarketplaceCategory.events);
  });

  testWidgets('loading, recoverable error and empty states use real results', (
    tester,
  ) async {
    final pending = Completer<List<MarketplaceItem>>();
    final repo = _Catalog()..respond = (_) => pending.future;
    await tester.pumpWidget(_app(repo));
    await tester.pump();
    expect(find.text(_event.title), findsNothing);
    pending.completeError(StateError('private database diagnostic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private database diagnostic'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    repo.respond = (_) async => [];
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No plans found'), findsOneWidget);
    expect(find.text(_event.title), findsNothing);
  });

  testWidgets('pagination is bounded and changing city resets the page', (
    tester,
  ) async {
    final repo = _Catalog()
      ..respond = (query) async => List.generate(
        24,
        (index) => MarketplaceItem(
          id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          entity: MarketplaceEntity.venue,
          category: MarketplaceCategory.venues,
          title: 'Venue ${query.offset + index}',
          city: query.city,
          price: 50,
        ),
      );
    final container = ProviderContainer(
      overrides: [
        marketplaceRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(repo, container: container));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next page'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.offset, 24);
    container.read(discoveryLocationProvider.notifier).setCity('Chennai');
    await tester.pumpAndSettle();
    expect(repo.queries.last.offset, 0);
    expect(repo.queries.last.city, 'Chennai');
  });

  testWidgets('entry and item open marketplace and existing detail routes', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: MarketplaceEntryCard()),
        ),
        GoRoute(
          path: '/marketplace',
          builder: (_, __) => const MarketplaceScreen(),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final repo = _Catalog();
    await tester.pumpWidget(_app(repo, router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('marketplace-entry')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(_event.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_event.title));
    await tester.pumpAndSettle();
    expect(find.text('Detail ${_event.id}'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('responsive catalog at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_Catalog(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(_event.title));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Telugu catalog has translated controls', (tester) async {
    await tester.pumpWidget(_app(_Catalog(), locale: const Locale('te')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        AppLocalizations(const Locale('te')).marketplaceText('marketplace'),
      ),
      findsOneWidget,
    );
    expect(find.text('ఈవెంట్లు'), findsWidgets);
  });
}
