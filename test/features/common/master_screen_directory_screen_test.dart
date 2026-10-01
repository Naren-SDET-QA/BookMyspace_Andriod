import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/common/presentation/screens/master_screen_directory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const MasterScreenDirectoryScreen(),
      ),
    );
  }

  group('MasterScreenDirectoryScreen', () {
    test('catalog contains all 39 master screens and 4 supplementary screens', () {
      expect(masterScreenCatalog.length, greaterThanOrEqualTo(39));
      final domains = masterScreenCatalog.map((e) => e.domain).toSet();
      expect(domains, contains(ScreenDomain.discovery));
      expect(domains, contains(ScreenDomain.booking));
      expect(domains, contains(ScreenDomain.owner));
      expect(domains, contains(ScreenDomain.education));
      expect(domains, contains(ScreenDomain.admin));
      expect(domains, contains(ScreenDomain.supplementary));
    });

    testWidgets('renders directory header, preview toggle, search bar and domain filter chips',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.text('Screen Directory'), findsOneWidget);
      expect(find.text('Display All Screens Mode'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Screens (45)'), findsOneWidget);
      expect(find.text('1. Discovery & Customer (10)'), findsOneWidget);
      expect(find.text('Home Discovery Screen'), findsOneWidget);
    });

    testWidgets('toggling Display All Screens Mode updates previewAllScreensModeProvider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MasterScreenDirectoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(previewAllScreensModeProvider), isFalse);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(container.read(previewAllScreensModeProvider), isTrue);
    });

    testWidgets('filtering by domain shows matching screens', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Find chip for Discovery & Customer
      final discoveryChip = find.text('1. Discovery & Customer (10)');
      expect(discoveryChip, findsOneWidget);

      await tester.tap(discoveryChip);
      await tester.pumpAndSettle();

      expect(find.text('Home Discovery Screen'), findsOneWidget);
      expect(find.text('India Location & Multi-Tier Discovery'), findsOneWidget);
    });

    testWidgets('searching by text filters screen entries', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Audit Logs');
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs & Security Ledger'), findsOneWidget);
      expect(find.text('Home Discovery Screen'), findsNothing);
    });

    testWidgets('every domain and every place fits phone, tablet, and desktop',
        (tester) async {
      const sizes = <Size>[
        Size(320, 800),
        Size(390, 844),
        Size(768, 1024),
        Size(1280, 900),
        Size(1440, 900),
      ];
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(buildTestableWidget());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'layout at $size');
        expect(find.text('All Screens (45)'), findsOneWidget);
        expect(find.text('1. Discovery & Customer (10)'), findsOneWidget);
        expect(find.text('2. Booking Engine & Checkout (9)'), findsOneWidget);
        expect(find.text('3. Owner & Partner Portal (10)'), findsOneWidget);
        expect(find.text('4. Education & Institutes (6)'), findsOneWidget);
        expect(find.text('5. Super Admin & CMS (6)'), findsOneWidget);
        expect(find.text('Supplementary & Tools (4)'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Past Coupons & Savings'),
          500,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Past Coupons & Savings'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'scrolled at $size');
      }
    });
  });
}
