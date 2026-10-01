/// Browser install prompt. Non-web builds have no `beforeinstallprompt`.
class WebInstallPrompt {
  static bool get canPrompt => false;

  static bool get isInstalled => false;

  static Future<String> prompt() async => 'unavailable';
}
