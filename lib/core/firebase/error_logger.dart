import 'package:flutter/foundation.dart';

import 'performance_service.dart';

/// Centralized error logging that remains usable without optional Firebase
/// Crashlytics/Performance packages or native configuration files.
class ErrorLogger {
  ErrorLogger._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await PerformanceService.init();
    debugPrint('ErrorLogger initialized');
  }

  static void logError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, Object?>? extra,
    bool fatal = false,
  }) {
    debugPrint('ERROR${fatal ? ' (FATAL)' : ''}: $error');
    if (context != null) debugPrint('Context: $context');
    if (extra != null && extra.isNotEmpty) debugPrint('Extra: $extra');
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  static void logException(
    Exception exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, Object?>? extra,
  }) {
    logError(exception, stackTrace, context: context, extra: extra);
  }

  static void logMessage(String message, {String? context}) {
    debugPrint('LOG: $message${context == null ? '' : ' [$context]'}');
  }

  static Future<void> setUserId(String userId) async {}

  static Future<void> clearUserId() async {}

  static Future<void> setCustomKey(String key, Object value) async {}

  static Trace? startScreenTrace(String screenName) =>
      PerformanceService.startScreenTrace(screenName);

  static HttpMetric? startHttpTrace(String url, String method) =>
      PerformanceService.startHttpTrace(url, method.toUpperCase());

  static Future<void> recordMetric(
    String traceName,
    String metricName,
    int value,
  ) =>
      PerformanceService.recordMetric(traceName, metricName, value);
}
