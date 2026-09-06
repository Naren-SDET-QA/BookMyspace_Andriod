/// Stub implementation of WebSpeechBridge for non-web platforms (iOS, Android, VM).
class WebSpeechBridge {
  static bool get isSupported => false;

  static Future<bool> startListening({String? language}) async => false;

  static Future<bool> stopListening() async => false;

  static Future<bool> abort() async => false;

  static void registerEventListener(void Function(Map<String, dynamic> event) onEvent) {}
}
