import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_state.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../booking/mock_booking_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../offers/mock_coupon_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_auth_repository.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';

const _l10nDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

List<Override> _repoOverrides(MockAuthRepository repo) {
  return [
    authRepositoryProvider.overrideWithValue(repo),
    venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
    couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
    bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
  ];
}

void main() {
  test('restores an existing session into authNotifier and currentUser', () {
    final repo = MockAuthRepository(
      initialUser: const AuthUser(id: 'u1', email: 'restored@test.com'),
    );
    final container = ProviderContainer(overrides: _repoOverrides(repo));
    addTearDown(() {
      container.dispose();
      repo.dispose();
    });

    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
    expect(container.read(currentUserProvider)?.email, 'restored@test.com');
    expect(
      container.read(authNotifierProvider).user?.id,
      container.read(currentUserProvider)?.id,
    );
  });

  test('Google success propagates to authNotifier and currentUser', () async {
    final repo = MockAuthRepository();
    final container = ProviderContainer(overrides: _repoOverrides(repo));
    addTearDown(() {
      container.dispose();
      repo.dispose();
    });

    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    expect(container.read(currentUserProvider), isNull);

    await repo.signInWithGoogle();
    await Future<void>.microtask(() {});

    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
    expect(container.read(currentUserProvider)?.id, 'mock-user');
    expect(container.read(currentUserProvider)?.email, 'mock@test.com');
  });

  test('Apple success propagates to authNotifier and currentUser', () async {
    final repo = MockAuthRepository();
    final container = ProviderContainer(overrides: _repoOverrides(repo));
    addTearDown(() {
      container.dispose();
      repo.dispose();
    });

    await repo.signInWithApple();
    await Future<void>.microtask(() {});

    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
    expect(container.read(currentUserProvider)?.id, 'mock-user');
  });

  test('sign-out clears authNotifier and currentUser together', () async {
    final repo = MockAuthRepository(
      initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
    );
    final container = ProviderContainer(overrides: _repoOverrides(repo));
    addTearDown(() {
      container.dispose();
      repo.dispose();
    });

    expect(container.read(currentUserProvider)?.id, 'u1');
    await container.read(authNotifierProvider.notifier).signOut();
    await Future<void>.microtask(() {});

    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    expect(container.read(currentUserProvider), isNull);
    expect(repo.currentUser, isNull);
  });

  testWidgets('Google success navigates off login using canonical session',
      (tester) async {
    final repo = MockAuthRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.shell,
          builder: (context, state) => const Text('signed-in-shell'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _repoOverrides(repo),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: _l10nDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('signed-in-shell'), findsOneWidget);
    expect(repo.currentUser?.email, 'mock@test.com');
    repo.dispose();
  });

  testWidgets('signed-out users are redirected away from protected routes',
      (tester) async {
    AuthState auth = const AuthUnauthenticated();
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    final router = createAppRouter(
      initialLocation: AppRoutes.shell,
      refreshListenable: refresh,
      authStateReader: () => auth,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _repoOverrides(MockAuthRepository()),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: _l10nDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
  });

  testWidgets('signed-in users are redirected off login onto the shell',
      (tester) async {
    AuthState auth = const AuthAuthenticated(
      user: AuthUser(id: 'u1', email: 'a@b.com'),
    );
    final refresh = ValueNotifier(0);
    addTearDown(refresh.dispose);
    final router = createAppRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: refresh,
      authStateReader: () => auth,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _repoOverrides(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: _l10nDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.shell);
  });

  testWidgets('session restoration keeps protected routes accessible',
      (tester) async {
    const user = AuthUser(id: 'u1', email: 'a@b.com');
    final router = createAppRouter(
      initialLocation: AppRoutes.home,
      currentUser: user,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _repoOverrides(MockAuthRepository(initialUser: user)),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: _l10nDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
  });
}
