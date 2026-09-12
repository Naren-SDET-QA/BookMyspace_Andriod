/// Stub implementation of WebPushBridge for non-web platforms (iOS, Android, VM).
class WebPushBridge {
  static bool get isSupported => false;

  static Future<String> requestPermission() async => 'default';

  static Future<String> getPermissionStatus() async => 'default';

  static Future<Map<String, dynamic>?> getSubscription() async => null;

  static Future<bool> showNotification(
    String title, {
    String? body,
    String? icon,
    String? badge,
    Map<String, dynamic>? data,
    List<Map<String, String>>? actions,
  }) async =>
      false;

  static void registerMessageListener(
      void Function(Map<String, dynamic> data) onMessage) {}

  static void registerClickListener(
      void Function(Map<String, dynamic> data, String? action) onClick) {}

  static Future<bool> unsubscribe() async => false;
}
