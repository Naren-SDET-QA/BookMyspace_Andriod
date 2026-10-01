import 'dart:convert';

import 'package:bookmyspace/core/config/settings_controller.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/ai_booking/presentation/widgets/ai_booking_sheet.dart';
import 'package:bookmyspace/features/home/domain/home_appearance.dart';
import 'package:bookmyspace/features/home/presentation/home_appearance_providers.dart';
import 'package:bookmyspace/features/home/presentation/widgets/home_ai_booking_card.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/cms/presentation/cms_providers.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/admin/domain/admin_settings.dart';
import 'package:bookmyspace/features/admin/presentation/admin_settings_providers.dart';
import 'package:bookmyspace/features/home/presentation/recently_viewed.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_layout_switch.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/home/presentation/screens/premium_home_screen.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/offers/domain/coupon.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/mock_auth_repository.dart';

class _MemoryPreferences extends Preferences {
  _MemoryPreferences([Map<String, String>? seed])
    : values = {...?seed},
      super(const FlutterSecureStorage());

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const _venues = [
  Venue(
    id: 'v1',
    name: 'Royal Palace Function Hall',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9,
    longitude: 77.6,
    capacity: 500,
    pricingBaseAmount: 73000,
    avgRating: 4.8,
    ratingCount: 320,
    category: VenueCategory(id: 'c1', slug: 'function_hall', name: 'Halls'),
  ),
  Venue(
    id: 'v2',
    name: 'City Sports Arena',
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9,
    longitude: 77.6,
    capacity: 22,
    pricingBaseAmount: 2500,
    category: VenueCategory(id: 'c2', slug: 'sports_ground', name: 'Sports'),
  ),
];

const _coupons = [
  Coupon(
    id: 'k1',
    code: 'WELCOME10',
    discountType: 'percentage',
    discountValue: 10,
    description: 'on your first booking',
  ),
  Coupon(
    id: 'k2',
    code: 'FESTIVE500',
    discountType: 'flat',
    discountValue: 500,
    description: 'Flat ₹500 off on bookings above ₹10,000',
  ),
];

final _todayCourse = Course(
  id: 'java1',
  instituteId: 'i1',
  title: 'Core Java',
  description: '',
  mode: CourseMode.offline,
  durationWeeks: 12,
  feeAmount: 5000,
  status: 'published',
  instructorName: 'Test Instructor',
  instituteName: 'Test Institute',
  instituteCity: 'Hyderabad',
  batches: [
    CourseBatch(
      id: 'b1',
      courseId: 'java1',
      label: 'Morning',
      startsOn: DateTime.now(),
      capacity: 40,
      enrolledCount: 10,
      timing: '7:30 AM',
    ),
  ],
);

class _Nav {
  final pushed = <String>[];
}

Future<_Nav> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<Coupon> coupons = _coupons,
  Map<String, String>? prefs,
  List<Course>? courses,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nav = _Nav();
  Widget page(String name) => Scaffold(body: Text('page:$name'));
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PremiumHomeScreen()),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, s) {
          nav.pushed.add(s.uri.toString());
          return page('search');
        },
      ),
      GoRoute(path: AppRoutes.education, builder: (_, __) => page('education')),
      GoRoute(path: AppRoutes.coursesList, builder: (_, __) => page('courses')),
      GoRoute(
        path: AppRoutes.staysList,
        builder: (_, s) {
          nav.pushed.add(s.uri.toString());
          return page('stays');
        },
      ),
      GoRoute(
        path: AppRoutes.pgList,
        builder: (_, s) {
          nav.pushed.add(s.uri.toString());
          return page('pg');
        },
      ),
      GoRoute(
        path: AppRoutes.venueDetails,
        builder: (_, s) => page('venue:${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: AppRoutes.bookingFlow,
        builder: (_, s) => page('book:${s.pathParameters['id']}'),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => page('login')),
      GoRoute(
        path: AppRoutes.courseDetails,
        builder: (_, s) => page('course:${s.pathParameters['id']}'),
      ),
      GoRoute(path: AppRoutes.saved, builder: (_, __) => page('saved')),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => page('notifications'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        preferencesProvider.overrideWithValue(_MemoryPreferences(prefs)),
        popularVenuesProvider.overrideWith((ref) async => _venues),
        nearbyVenuesProvider.overrideWith((ref) async => const <Venue>[]),
        venueCategoriesProvider.overrideWith(
          (ref) => Stream.value(const <VenueCategory>[]),
        ),
        activeCouponsProvider.overrideWith((ref) async => coupons),
        activeCmsBannersProvider.overrideWith((ref) async => const []),
        publishedCoursesProvider.overrideWith(
          (ref) async => courses ?? [_todayCourse],
        ),
        moduleEnabledProvider.overrideWith((ref, id) => true),
        homeVisibleBlocksProvider.overrideWith(
          (ref) => HomeAppearance.defaults.visible,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
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
  return nav;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapHorizontal(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal)
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(360, 780), Size(390, 844), Size(1440, 1000)]) {
    testWidgets('renders every section without overflow at ${size.width}', (
      tester,
    ) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('TURN MOMENTS INTO MEMORIES'), findsOneWidget);
      expect(find.byKey(const Key('premium-search')), findsOneWidget);
      // Scroll through the whole page; any overflow would throw.
      final scroll = find.byKey(const Key('premium-home'));
      final seen = <String>{};
      for (var i = 0; i < 6; i++) {
        seen.addAll(
          tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
        );
        await tester.drag(scroll, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(
        seen,
        containsAll([
          'Explore Categories',
          'Popular Near You',
          'Top Offers For You',
        ]),
      );
    });
  }

  testWidgets('coupon labels read "10% OFF", never "off OFF"', (tester) async {
    await _pump(tester, size: const Size(1440, 1000));
    expect(find.textContaining('off OFF'), findsNothing);
    expect(find.text('Get 10% OFF'), findsWidgets);
  });

  testWidgets('offer sections hide when there are no coupons', (tester) async {
    await _pump(tester, coupons: const []);
    expect(find.textContaining('Use code'), findsNothing);
    expect(find.text('Top Offers For You'), findsNothing);
    expect(find.text('Special Offer'), findsNothing);
  });

  testWidgets('search tabs route to the right screens', (tester) async {
    var nav = await _pump(tester);
    await tester.enterText(find.byKey(const Key('premium-where')), 'lawn');
    await _tapKey(tester, 'premium-search');
    expect(find.text('page:search'), findsOneWidget);
    expect(nav.pushed.last, contains('lawn'));

    nav = await _pump(tester);
    await tester.tap(find.byKey(const Key('premium-tab-institutes')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'premium-search');
    expect(find.text('page:education'), findsOneWidget);

    await _pump(tester);
    await tester.tap(find.byKey(const Key('premium-tab-classes')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'premium-search');
    expect(find.text('page:courses'), findsOneWidget);
  });

  testWidgets('hotel and PG categories open stay results', (tester) async {
    const wide = Size(1440, 1000);
    var nav = await _pump(tester, size: wide);
    await _tapKey(tester, 'premium-category-lodge_rooms');
    expect(find.text('page:stays'), findsOneWidget);
    expect(nav.pushed.last, '/stays');

    nav = await _pump(tester, size: wide);
    await _tapKey(tester, 'premium-category-pg_hostels');
    expect(find.text('page:pg'), findsOneWidget);
    expect(nav.pushed.last, '/pg');

    nav = await _pump(tester, size: wide);
    await _tapHorizontal(tester, 'premium-popular-Hostels');
    expect(find.text('page:pg'), findsOneWidget);

    nav = await _pump(tester, size: wide);
    await _tapHorizontal(tester, 'premium-popular-Resorts');
    expect(find.text('page:stays'), findsOneWidget);
    expect(nav.pushed.last, '/stays');

    nav = await _pump(tester, size: wide);
    await tester.tap(find.byKey(const Key('premium-tab-stays')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('premium-where')), 'Hyderabad');
    await tester.tap(find.byKey(const Key('premium-search')));
    await tester.pumpAndSettle();
    expect(find.text('page:stays'), findsOneWidget);
    expect(nav.pushed.last, contains('Hyderabad'));
  });

  testWidgets('category tiles, popular chips and venue cards navigate', (
    tester,
  ) async {
    const wide = Size(1440, 1000);
    var nav = await _pump(tester, size: wide);
    await _tapKey(tester, 'premium-category-sports_turfs');
    expect(find.text('page:search'), findsOneWidget);
    expect(nav.pushed.last, contains('category='));

    await _pump(tester, size: wide);
    await _tapKey(tester, 'premium-category-institutes_classes');
    expect(find.text('page:education'), findsOneWidget);

    nav = await _pump(tester, size: wide);
    await tester.tap(find.byKey(const Key('premium-popular-Party Halls')));
    await tester.pumpAndSettle();
    expect(nav.pushed.last, contains('Party'));

    await _pump(tester);
    await _tapKey(tester, 'premium-venue-v1');
    expect(find.text('page:venue:v1'), findsOneWidget);

    await _pump(tester);
    await _tapKey(tester, 'premium-book-v2');
    expect(find.text('page:book:v2'), findsOneWidget);
  });

  testWidgets('saving a venue while signed out goes to login', (tester) async {
    await _pump(tester);
    await _tapKey(tester, 'premium-fav-v1');
    expect(find.text('page:login'), findsOneWidget);
  });

  testWidgets('recently viewed shows stored venues and opens them', (
    tester,
  ) async {
    await _pump(
      tester,
      prefs: {
        RecentlyViewedNotifier.storageKey: jsonEncode([
          {'id': 'r1', 'name': 'Sunrise Lodge', 'city': 'Bengaluru'},
        ]),
      },
    );
    await _tapKey(tester, 'premium-recent-r1');
    expect(find.text('page:venue:r1'), findsOneWidget);
  });

  test('recently viewed keeps newest first, unique, capped', () async {
    final prefs = _MemoryPreferences();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(recentlyViewedProvider.notifier);
    await container.read(recentlyViewedProvider.future);
    for (var i = 0; i < 15; i++) {
      await notifier.record(_venues[i % 2].copyWith(id: 'v$i', name: 'V$i'));
    }
    await notifier.record(_venues.first.copyWith(id: 'v3', name: 'V3'));
    final list = container.read(recentlyViewedProvider).value!;
    expect(list.first.id, 'v3');
    expect(list.where((v) => v.id == 'v3'), hasLength(1));
    expect(list, hasLength(RecentlyViewedNotifier.maxEntries));
    expect(prefs.values[RecentlyViewedNotifier.storageKey], isNotNull);
  });

  for (final (layout, premium) in const [
    ('premium', true),
    ('glass', false),
    ('modern', false),
    (null, false),
  ]) {
    testWidgets('Home tab shows ${premium ? 'Premium' : 'existing'} Home '
        'for home_layout=$layout', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminSettingsProvider.overrideWith(
              (ref) async => AdminSettings(
                home: {if (layout != null) 'home_layout': layout},
              ),
            ),
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
            preferencesProvider.overrideWithValue(_MemoryPreferences()),
            popularVenuesProvider.overrideWith((ref) async => _venues),
            nearbyVenuesProvider.overrideWith((ref) async => const <Venue>[]),
            venueCategoriesProvider.overrideWith(
              (ref) => Stream.value(const <VenueCategory>[]),
            ),
            activeCouponsProvider.overrideWith((ref) async => _coupons),
            activeCmsBannersProvider.overrideWith((ref) async => const []),
            moduleEnabledProvider.overrideWith((ref, id) => true),
          ],
          child: const MaterialApp(home: HomeLayoutSwitch()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.byType(PremiumHomeScreen),
        premium ? findsOneWidget : findsNothing,
      );
      expect(find.byType(HomeScreen), premium ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('language button lists every language and switches locale', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1440, 1000));
    await tester.tap(find.byKey(const Key('premium-language')));
    await tester.pumpAndSettle();
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        find.byKey(Key('premium-language-${locale.languageCode}')),
        findsOneWidget,
        reason: locale.languageCode,
      );
    }
    await tester.tap(find.byKey(const Key('premium-language-hi')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(PremiumHomeScreen));
    expect(
      ProviderScope.containerOf(context).read(localeProvider).languageCode,
      'hi',
    );
    // The header shows the new language in its own script.
    expect(find.text('हिन्दी'), findsOneWidget);
  });

  testWidgets('AI booking: header button and Home card are present', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1440, 1000));
    expect(find.byType(HomeAiBookingCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('premium-ai')));
    await tester.pumpAndSettle();
    expect(find.byType(AiBookingSheet), findsOneWidget);
  });

  testWidgets('promo carousel: coupon, today\'s class, sports, function hall', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1440, 1000));
    await tester.scrollUntilVisible(
      find.byKey(const Key('premium-promo-carousel')),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    // 1 coupon + class + sports + hall + 1 extra coupon.
    expect(find.text('1/5'), findsOneWidget);
    expect(find.text('Use code WELCOME10'), findsOneWidget);

    // Arrows move between slides.
    await tester.tap(find.byKey(const Key('premium-promo-next')));
    await tester.pumpAndSettle();
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('Core Java'), findsOneWidget);
    expect(find.text('by Test Instructor'), findsOneWidget);
    expect(find.textContaining('7:30 AM'), findsOneWidget);
    expect(find.text('CLASS STARTS TODAY'), findsWidgets);

    // Auto-advance.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('SPORTS'), findsWidgets);

    await tester.tap(find.byKey(const Key('premium-promo-next')));
    await tester.pumpAndSettle();
    expect(find.text('CELEBRATE'), findsWidgets);

    // Tapping the class slide opens the course.
    // (Auto-advance keeps running, so step until the class slide is shown.)
    final classSlide = find.byKey(const Key('premium-slide-class-java1'));
    for (var i = 0; i < 6 && classSlide.hitTestable().evaluate().isEmpty; i++) {
      await tester.tap(find.byKey(const Key('premium-promo-next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(classSlide);
    await tester.pumpAndSettle();
    expect(find.text('page:course:java1'), findsOneWidget);
  });

  testWidgets('no class slide when no batch runs today', (tester) async {
    await _pump(tester, size: const Size(1440, 1000), courses: const []);
    expect(find.byKey(const Key('premium-slide-class-java1')), findsNothing);
  });
}
