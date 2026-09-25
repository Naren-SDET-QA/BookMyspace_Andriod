import 'analytics_event.dart';

abstract class AnalyticsEventRepository {
  Future<void> track(AnalyticsEvent event);

  Future<List<AnalyticsEvent>> recentEvents({int limit = 50});
}
