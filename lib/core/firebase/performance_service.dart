import 'package:flutter/foundation.dart';

/// Lightweight local performance trace used when Firebase Performance is not
/// configured in this checkout.
class Trace {
  Trace(this.name);
  final String name;
  final Stopwatch _watch = Stopwatch()..start();
  final Map<String, int> metrics = {};

  void incrementMetric(String key, int value) {
    metrics[key] = (metrics[key] ?? 0) + value;
  }

  Future<void> stop() async {
    if (_watch.isRunning) _watch.stop();
  }
}

class HttpMetric extends Trace {
  HttpMetric(super.name);
}

/// Local no-op-compatible replacement for Firebase Performance.
class PerformanceService {
  PerformanceService._();

  static Future<void> init() async {
    if (kDebugMode) debugPrint('Performance monitoring is using local traces');
  }

  static Trace? startTrace(String name) => Trace(name);

  static void stopTrace(Trace? trace) {
    trace?.stop();
  }

  static void incrementCounter(Trace? trace, String name, int increment) {
    trace?.incrementMetric(name, increment);
  }

  static Trace? startScreenTrace(String screenName) =>
      Trace('screen_view_$screenName');

  static HttpMetric? startHttpTrace(String url, String method) =>
      HttpMetric('$method $url');

  static Future<void> recordMetric(
    String traceName,
    String metricName,
    int value,
  ) async {
    final trace = Trace(traceName);
    trace.incrementMetric(metricName, value);
    await trace.stop();
  }
}
