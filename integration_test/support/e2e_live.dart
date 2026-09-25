import 'package:bookmyspace/app.dart';
import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../robots/base_robot.dart';
import 'e2e_env.dart';

/// Live DEV harness: the production app, repositories and Supabase client,
/// with no mocks and no backend overrides, reachable only for DEV.
abstract final class E2eLive {
  /// Budget for one real round trip (sign-in, search, availability, hold).
  static const networkTimeout = Duration(seconds: 45);

  static Future<void>? _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  /// Refuses to start unless every DEV guard passes, then initialises
  /// Supabase exactly as `main.dart` does, once per test process.
  static Future<void> ensureInitialized() => _initialized ??= _initialize();

  static Future<void> _initialize() async {
    final problem = E2eEnv.liveModeProblem() ?? _appConfigProblem();
    if (problem != null) {
      throw StateError('E2E_MODE=live refused: $problem');
    }
    await initSupabase();
  }

  /// The app reads its backend from [AppConfig], so the guard also checks
  /// what the app itself will connect to, not only the E2E dart-defines.
  static String? _appConfigProblem() {
    if (AppConfig.environment != AppEnvironment.development) {
      return 'APP_ENV must resolve to the development environment.';
    }
    final host = Uri.tryParse(AppConfig.supabaseUrl)?.host.toLowerCase();
    if (host != E2eLiveGuard.devSupabaseHost) {
      return 'the app is configured for "$host", not the DEV project.';
    }
    return null;
  }
}

/// A deterministic DEV seed function hall (`supabase/seed_dev_e2e.sql`,
/// marker `e2e_v1`). Ids are the seed's own `md5(...)::uuid` values:
/// venue `md5('bms-dev-e2e:venue:function_hall:<n>')` and slot
/// `md5('bms-dev-e2e-function_hall-<nn>:slot:1')` (the "Morning" slot).
class LiveSeedVenue {
  const LiveSeedVenue(this.number, this.id, this.slotId);

  final int number;
  final String id;
  final String slotId;

  /// Seeded name: `initcap('function hall') || ' DEV ' || n`.
  String get name => 'Function Hall DEV $number';
}

abstract final class E2eLiveFixtures {
  /// Function halls require an event type before a hold can be taken.
  static const eventType = 'Wedding';

  /// Function Hall DEV 1 carries the seed's history bookings and is never
  /// booked here; 9 and 10 belong to the Playwright live suite.
  static const functionHalls = <LiveSeedVenue>[
    LiveSeedVenue(
      2,
      'b0d395bf-99b1-c3bf-2b38-f75a6267887a',
      'dd4bdc04-0272-d508-66cd-56cc0418a1fb',
    ),
    LiveSeedVenue(
      3,
      '33d0a33a-15a9-67c5-1ad8-d8d021c82f8a',
      'f809415b-980e-dc4a-fc8b-cd2141aaed37',
    ),
    LiveSeedVenue(
      4,
      '4a2283f6-ab33-53ec-8466-bbacd0b97ab0',
      '9c4b5a67-655e-3a82-fd9b-5643ead726c3',
    ),
    LiveSeedVenue(
      5,
      '574427c9-31ea-2bf7-bd7a-2ca0189e9bb6',
      'e8054d2e-9796-9190-606e-99c386aec8da',
    ),
    LiveSeedVenue(
      6,
      '6fb8fef1-54e6-0c7f-4b74-f41a61f96322',
      'fc4b5f61-20c3-542e-203b-ac525ed0ac27',
    ),
    LiveSeedVenue(
      7,
      '6a579134-e7d0-0f14-78c5-34cd734064fe',
      '34257788-a12f-3d48-dcbe-0aa9428d78d5',
    ),
    LiveSeedVenue(
      8,
      'b05335af-4789-adcb-56c6-1180b4c2bd25',
      'f606ef7f-263f-fb81-99e0-c36919b558ac',
    ),
  ];

  /// This runner's venues. Pools are disjoint per platform, so Android,
  /// iOS and web runs never race each other for the same slot.
  static List<LiveSeedVenue> get pool => [
    for (final venue in functionHalls)
      if (_poolNumbers.contains(venue.number)) venue,
  ];

  static List<int> get _poolNumbers {
    if (kIsWeb) return const [8];
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const [2, 3, 4],
      TargetPlatform.iOS => const [5, 6, 7],
      _ => const [8],
    };
  }
}

/// A free seeded (venue, date) pair for this run.
class LiveTarget {
  const LiveTarget(this.venue, this.isoDate);

  final LiveSeedVenue venue;

  /// Booking date as `yyyy-MM-dd`: a Tuesday inside the app's 14-day strip.
  final String isoDate;
}

/// `yyyy-MM-dd` with ASCII digits, as used by `E2eIds.bookingDate`.
String e2eIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Picks the first free (venue, Tuesday) pair of this runner's pool, in a
/// fixed order, through the public read-only `available_time_slots` RPC.
///
/// Seeded venues open on Tuesdays only (operating hours day 1, Monday = 0)
/// and a slot stays taken while a hold is active, so a rerun within about
/// 11 minutes moves on to the next pair instead of failing on its own hold.
Future<LiveTarget> pickLiveTarget() async {
  final today = DateTime.now();
  final tuesdays = <DateTime>[];
  for (var i = 1; i < 14; i++) {
    final date = DateTime(today.year, today.month, today.day + i);
    if (date.weekday == DateTime.tuesday) tuesdays.add(date);
  }
  final tried = <String>[];
  for (final venue in E2eLiveFixtures.pool) {
    for (final date in tuesdays) {
      final isoDate = e2eIsoDate(date);
      final rows = await E2eLive.client.rpc<List<dynamic>>(
        'available_time_slots',
        params: {'p_venue_id': venue.id, 'p_book_date': isoDate},
      );
      Map<String, dynamic>? slot;
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        if (row['slot_id'] == venue.slotId) slot = row;
      }
      if (slot?['is_available'] == true) return LiveTarget(venue, isoDate);
      final reason = slot?['reason'] ?? 'no seeded slot';
      tried.add('${venue.name} $isoDate: $reason');
    }
  }
  throw TestFailure(
    'No free DEV seed slot for this runner. Tried: ${tried.join('; ')}. '
    'Holds from an earlier run expire in about 11 minutes; "no seeded '
    'slot" means the DEV seed (e2e_v1) is not applied.',
  );
}

/// Pumps the production app at sign-in, with no session, against DEV.
Future<void> pumpLiveApp(WidgetTester tester) async {
  await E2eLive.ensureInitialized();
  final auth = E2eLive.client.auth;
  if (auth.currentSession != null) {
    // A session persisted by an earlier run: end it on this device only.
    await auth.signOut();
  }
  if (auth.currentSession != null) {
    throw StateError('Live E2E could not start signed out.');
  }
  await tester.pumpWidget(
    const ProviderScope(
      child: BookMySpaceApp(initialLocation: AppRoutes.login),
    ),
  );
  await BaseRobot(tester).settle();
}

/// The booking id of the checkout route (`/bookings/:id/pay`).
String liveBookingIdFromLocation(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  final uri = GoRouter.of(context).routerDelegate.currentConfiguration.uri;
  final segments = uri.pathSegments;
  if (segments.length != 3 ||
      segments.first != 'bookings' ||
      segments.last != 'pay') {
    throw TestFailure('Expected the checkout route, got "${uri.path}".');
  }
  return segments[1];
}

/// Server truth for the hold: the booking row belongs to the signed-in
/// customer and matches the chosen venue, slot and date. RLS only lets a
/// customer read their own bookings.
Future<void> expectLiveHeldBooking(
  String bookingId, {
  required String userId,
  required LiveTarget target,
}) async {
  final row = await E2eLive.client
      .from('bookings')
      .select('user_id, venue_id, slot_id, book_date, status')
      .eq('id', bookingId)
      .single();
  expect(row['user_id'], userId);
  expect(row['venue_id'], target.venue.id);
  expect(row['slot_id'], target.venue.slotId);
  expect(row['book_date'], target.isoDate);
  expect(row['status'], isIn(const ['held', 'pending']));
}
