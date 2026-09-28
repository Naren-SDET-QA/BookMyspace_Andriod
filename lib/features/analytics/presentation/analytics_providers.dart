import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/analytics_event.dart';
import '../domain/analytics_event_repository.dart';
import '../domain/analytics_repository.dart';
import '../domain/revenue_analytics.dart';
import '../infrastructure/supabase_analytics_repository.dart';
import '../infrastructure/supabase_revenue_analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsEventRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseAnalyticsRepository(client);
});

final recentAnalyticsEventsProvider = FutureProvider<List<AnalyticsEvent>>((
  ref,
) {
  return ref.watch(analyticsRepositoryProvider).recentEvents(limit: 50);
});

final revenueAnalyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return SupabaseRevenueAnalyticsRepository(ref.watch(supabaseProvider));
});

final revenueAnalyticsProvider = FutureProvider.autoDispose
    .family<RevenueAnalytics, ({DateTime start, DateTime end})>((ref, range) {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) throw StateError('Sign in required');
      return ref
          .watch(revenueAnalyticsRepositoryProvider)
          .revenue(start: range.start, end: range.end, admin: user.isAdmin);
    });

/// Fire-and-forget product analytics for customer surfaces.
///
/// No-ops for signed-out visitors (the `analytics_events` insert policy
/// requires `auth.uid() = user_id`) and never surfaces failures to the UI.
final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  return AnalyticsTracker(ref);
});

class AnalyticsTracker {
  AnalyticsTracker(this._ref);

  final Ref _ref;

  void track(
    AnalyticsEventType type, [
    Map<String, dynamic> properties = const {},
  ]) {
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) return;
      final repository = _ref.read(analyticsRepositoryProvider);
      repository
          .track(
            AnalyticsEvent(
              id: '',
              userId: user.id,
              eventType: type,
              properties: properties,
            ),
          )
          .catchError((Object _) {});
    } catch (_) {
      // Analytics must never break the screen (e.g. backend not configured).
    }
  }
}
