import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/navigation/domain/nav_tabs.dart';
import 'package:bookmyspace/features/navigation/presentation/nav_tabs_providers.dart';
import 'package:bookmyspace/features/navigation/presentation/screens/assistant_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real router, with the bar composition injected directly.
///
/// Overriding [navTabsProvider] exercises the same shell the app ships while
/// keeping the flag repository out of the picture.
Widget _shellApp({
  required String initialLocation,
  NavTabsConfig? config,
}) {
  return ProviderScope(
    overrides: [
      if (config != null) navTabsProvider.overrideWithValue(config),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
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

NavigationBar _bar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

/// The labels the customer actually reads, in bar order.
List<String> _labels(WidgetTester tester) => _bar(tester)
    .destinations
    .cast<NavigationDestination>()
    .map((destination) => destination.label)
    .toList();

void main() {
  group('NavTab', () {
    test('branch indices are unique and the assistant is last', () {
      final branches = {for (final tab in NavTab.values) tab.branch};
      expect(branches.length, NavTab.values.length);
      expect(NavTab.home.branch, 0);
      expect(NavTab.assistant.branch, 6);
    });

    test('fromId resolves known ids and rejects everything else', () {
      expect(NavTab.fromId('bookings'), NavTab.bookings);
      expect(NavTab.fromId('assistant'), NavTab.assistant);
      expect(NavTab.fromId('teleport'), isNull);
      expect(NavTab.fromId(null), isNull);
      expect(NavTab.fromId(7), isNull);
    });
  });

  group('shipped defaults', () {
    test('keep the existing six destinations and ship the assistant off', () {
      expect(NavTabsConfig.defaults.visible.map((e) => e.tab), [
        NavTab.home,
        NavTab.alerts,
        NavTab.search,
        NavTab.bookings,
        NavTab.courses,
        NavTab.profile,
      ]);
      expect(
        NavTabsConfig.defaults.configFor(NavTab.assistant)?.enabled,
        isFalse,
      );
    });

    test('branchOrder maps each bar position to its branch index', () {
      expect(NavTabsConfig.defaults.branchOrder, [0, 1, 2, 3, 4, 5]);
    });

    test('ordered lists every destination, enabled or not', () {
      expect(NavTabsConfig.defaults.ordered.length, NavTab.values.length);
      // Map/Saved/Chat (from release/v1.0) ship after the assistant.
      expect(NavTabsConfig.defaults.ordered.last.tab, NavTab.chat);
    });
  });

  group('visible', () {
    test('sorts by admin order, not declaration order', () {
      const config = NavTabsConfig([
        NavTabConfig(tab: NavTab.profile, order: 10),
        NavTabConfig(tab: NavTab.home, order: 20),
        NavTabConfig(tab: NavTab.search, order: 5),
      ]);
      expect(config.visible.map((e) => e.tab), [
        NavTab.search,
        NavTab.profile,
        NavTab.home,
      ]);
    });

    test('breaks an order tie on declaration order so the bar stays stable',
        () {
      const config = NavTabsConfig([
        NavTabConfig(tab: NavTab.courses, order: 10),
        NavTabConfig(tab: NavTab.home, order: 10),
      ]);
      expect(config.visible.map((e) => e.tab), [NavTab.home, NavTab.courses]);
    });

    test('hides a disabled destination from the bar but keeps its branch', () {
      const config = NavTabsConfig([
        NavTabConfig(tab: NavTab.home, order: 10),
        NavTabConfig(tab: NavTab.bookings, order: 20, enabled: false),
        NavTabConfig(tab: NavTab.assistant, order: 30),
      ]);
      expect(config.visible.map((e) => e.tab), [NavTab.home, NavTab.assistant]);
      expect(config.branchOrder, [0, 6]);
    });
  });

  group('fromJson', () {
    test('falls back to the shipped defaults for missing or malformed input',
        () {
      final expected =
          NavTabsConfig.defaults.visible.map((e) => e.tab).toList();
      expect(NavTabsConfig.fromJson(null).visible.map((e) => e.tab), expected);
      expect(
          NavTabsConfig.fromJson('nope').visible.map((e) => e.tab), expected);
      expect(
        NavTabsConfig.fromJson({'tabs': 'nope'}).visible.map((e) => e.tab),
        expected,
      );
      expect(
        NavTabsConfig.fromJson({'tabs': <Object>[]}).visible.map((e) => e.tab),
        expected,
      );
      expect(
        NavTabsConfig.fromJson({
          'tabs': [1, 2]
        }).visible.map((e) => e.tab),
        expected,
      );
    });

    test('reads a stored composition, including the assistant opt-in', () {
      final config = NavTabsConfig.fromJson({
        'tabs': [
          {'tab': 'home', 'enabled': true, 'order': 10},
          {'tab': 'assistant', 'enabled': true, 'order': 20},
        ],
      });
      // The two stored entries are honoured, and every destination the config
      // never mentioned keeps its shipped default.
      expect(config.configFor(NavTab.assistant)?.enabled, isTrue);
      expect(config.configFor(NavTab.assistant)?.order, 20);
      // Map/Saved/Chat keep their shipped default (disabled).
      expect(config.visible.length, NavTab.values.length - 3);
      expect(config.visible.first.tab, NavTab.home);
    });

    test('keeps a shipped default for any destination the config omits', () {
      final config = NavTabsConfig.fromJson({
        'tabs': [
          {'tab': 'home', 'order': 10},
        ],
      });
      // A config written before a destination existed must not silently hide it.
      expect(config.tabs.length, NavTab.values.length);
      expect(config.configFor(NavTab.profile)?.enabled, isTrue);
    });

    test('ignores an unknown tab id instead of crashing', () {
      final config = NavTabsConfig.fromJson({
        'tabs': [
          {'tab': 'teleport', 'order': 10},
        ],
      });
      expect(config.tabs.length, NavTab.values.length);
      expect(config.visible.length, 6);
    });

    test('enables a destination unless it explicitly says otherwise', () {
      expect(
        NavTabConfig.fromJson({'tab': 'home'}, NavTab.home).enabled,
        isTrue,
      );
      expect(
        NavTabConfig.fromJson({'tab': 'home', 'enabled': false}, NavTab.home)
            .enabled,
        isFalse,
      );
      expect(
          NavTabConfig.fromJson({'tab': 'home'}, NavTab.home).label, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      final config = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.assistant, enabled: true, order: 15),
      );
      final restored = NavTabsConfig.fromJson(config.toJson());
      expect(
        restored.visible.map((e) => e.tab),
        config.visible.map((e) => e.tab),
      );
      expect(
        restored.visible.map((e) => e.order),
        config.visible.map((e) => e.order),
      );
    });
  });

  group('copyWithTab', () {
    test('replaces an existing destination in place', () {
      final next = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.assistant, enabled: true, order: 70),
      );
      expect(next.tabs.length, NavTab.values.length);
      expect(next.configFor(NavTab.assistant)?.enabled, isTrue);
      expect(next.visible.last.tab, NavTab.assistant);
    });

    test('appends a destination the config never mentioned', () {
      const config = NavTabsConfig([NavTabConfig(tab: NavTab.home, order: 10)]);
      final next = config.copyWithTab(
        const NavTabConfig(tab: NavTab.profile, order: 20),
      );
      expect(next.tabs.map((e) => e.tab), [NavTab.home, NavTab.profile]);
    });

    test('an admin label wins, and clearing it restores the shipped name', () {
      final config = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.bookings, order: 40, label: 'My Trips'),
      );
      expect(config.configFor(NavTab.bookings)?.label, 'My Trips');
      expect(
        config.configFor(NavTab.bookings)?.copyWith(label: '').label,
        isEmpty,
      );
    });
  });

  group('customer shell', () {
    testWidgets('renders the shipped six destinations with no assistant',
        (tester) async {
      await tester.pumpWidget(
        _shellApp(initialLocation: AppRoutes.assistantTab),
      );
      await tester.pumpAndSettle();

      final labels = _labels(tester);
      expect(labels.length, 6);
      expect(labels, isNot(contains('Assistant')));
      expect(labels, contains('Bookings'));
    });

    testWidgets('a hidden destination is still reachable by deep link',
        (tester) async {
      await tester.pumpWidget(
        _shellApp(initialLocation: AppRoutes.assistantTab),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AssistantTabScreen), findsOneWidget);
      // The active branch has no bar position, so the first destination is
      // highlighted rather than asserting.
      expect(_bar(tester).selectedIndex, 0);
    });

    testWidgets('an admin opt-in adds the assistant destination',
        (tester) async {
      final config = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.assistant, enabled: true, order: 70),
      );
      await tester.pumpWidget(
        _shellApp(config: config, initialLocation: AppRoutes.assistantTab),
      );
      await tester.pumpAndSettle();

      expect(_labels(tester).length, 7);
      expect(_labels(tester), contains('Assistant'));
      expect(_bar(tester).selectedIndex, 6);
    });

    testWidgets('an admin can reorder and relabel a destination',
        (tester) async {
      final config = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.profile, order: 1, label: 'Account'),
      );
      await tester.pumpWidget(
        _shellApp(config: config, initialLocation: AppRoutes.assistantTab),
      );
      await tester.pumpAndSettle();

      final labels = _labels(tester);
      expect(labels.first, 'Account');
      expect(labels, isNot(contains('Profile')));
    });

    testWidgets('a disabled destination leaves the bar', (tester) async {
      final config = NavTabsConfig.defaults.copyWithTab(
        const NavTabConfig(tab: NavTab.bookings, enabled: false, order: 40),
      );
      await tester.pumpWidget(
        _shellApp(config: config, initialLocation: AppRoutes.assistantTab),
      );
      await tester.pumpAndSettle();

      final labels = _labels(tester);
      expect(labels.length, 5);
      expect(labels, isNot(contains('Bookings')));
      expect(tester.takeException(), isNull);
    });
  });
}
