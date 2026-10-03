import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/core/widgets/app_navigation_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppNavigationControls', () {
    testWidgets('renders Back and Home buttons with correct tooltips and semantics',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/details',
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/details',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
                title: const Text('Details'),
              ),
              body: const Text('Details Content'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global_back_button')), findsOneWidget);
      expect(find.byKey(const Key('global_home_button')), findsOneWidget);

      final backButton = tester.widget<IconButton>(
        find.byKey(const Key('global_back_button')),
      );
      expect(backButton.tooltip, 'Back');

      final homeButton = tester.widget<IconButton>(
        find.byKey(const Key('global_home_button')),
      );
      expect(homeButton.tooltip, 'Home');
    });

    testWidgets('tapping Home navigates cleanly to canonical AppRoutes.home',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/deep/nested/page',
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Root Home Page')),
          ),
          GoRoute(
            path: '/deep/nested/page',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
              ),
              body: const Text('Nested Screen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Nested Screen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('global_home_button')));
      await tester.pumpAndSettle();

      expect(find.text('Root Home Page'), findsOneWidget);
    });

    testWidgets('tapping Back pops route when canPop is true', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (context, __) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/subpage'),
                child: const Text('Go To Subpage'),
              ),
            ),
          ),
          GoRoute(
            path: '/subpage',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
              ),
              body: const Text('Subpage Content'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go To Subpage'));
      await tester.pumpAndSettle();

      expect(find.text('Subpage Content'), findsOneWidget);

      await tester.tap(find.byKey(const Key('global_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('Go To Subpage'), findsOneWidget);
    });

    testWidgets('Back falls back to Home when deep-linked and canPop is false',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/external/deep/link',
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/external/deep/link',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
              ),
              body: const Text('Deep Linked Screen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Deep Linked Screen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('global_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('on canonical Home screen, Back button is not shown',
        (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
              ),
              body: const Text('Home Screen Body'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global_back_button')), findsNothing);
      expect(find.byKey(const Key('global_home_button')), findsNothing);
    });

    testWidgets('custom callbacks onBack and onHome are invoked when provided',
        (tester) async {
      bool customBackCalled = false;
      bool customHomeCalled = false;

      final router = GoRouter(
        initialLocation: '/custom',
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/custom',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: AppNavigationControls(
                  showBack: true,
                  showHome: true,
                  onBack: () => customBackCalled = true,
                  onHome: () => customHomeCalled = true,
                ),
                leadingWidth: AppNavigationControls.kLeadingWidth,
              ),
              body: const Text('Custom Callback Screen'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('global_back_button')));
      await tester.pump();
      expect(customBackCalled, isTrue);

      await tester.tap(find.byKey(const Key('global_home_button')));
      await tester.pump();
      expect(customHomeCalled, isTrue);
    });

    testWidgets('fits cleanly without overflow across all screen sizes (320 to 1920)',
        (tester) async {
      for (final width in [320.0, 375.0, 390.0, 430.0, 600.0, 768.0, 1024.0, 1440.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: AppRoutes.root,
              redirect: (_, __) => AppRoutes.home,
            ),
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/test',
              builder: (_, __) => Scaffold(
                appBar: AppBar(
                  leading: const AppNavigationControls(),
                  leadingWidth: AppNavigationControls.kLeadingWidth,
                  title: const Text('Title'),
                ),
                body: const SizedBox(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('global_back_button')), findsOneWidget);
        expect(find.byKey(const Key('global_home_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('adapts gracefully in dark theme', (tester) async {
      final router = GoRouter(
        initialLocation: '/dark',
        routes: [
          GoRoute(
            path: AppRoutes.root,
            redirect: (_, __) => AppRoutes.home,
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/dark',
            builder: (_, __) => Scaffold(
              appBar: AppBar(
                leading: const AppNavigationControls(),
                leadingWidth: AppNavigationControls.kLeadingWidth,
                title: const Text('Dark Mode'),
              ),
              body: const SizedBox(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData.dark(),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global_back_button')), findsOneWidget);
      expect(find.byKey(const Key('global_home_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
