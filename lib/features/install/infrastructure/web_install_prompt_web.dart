import 'dart:js_interop';

@JS('bookMySpaceInstall')
external JSObject? get _install;

@JS('bookMySpaceInstall.promptAvailable')
external JSBoolean? _jsPromptAvailable();

@JS('bookMySpaceInstall.isStandalone')
external JSBoolean? _jsIsStandalone();

@JS('bookMySpaceInstall.prompt')
external JSPromise<JSString>? _jsPrompt();

/// Talks to `window.bookMySpaceInstall` in web/index.html, which holds the
/// deferred `beforeinstallprompt` event until the customer taps Install.
class WebInstallPrompt {
  static bool get canPrompt {
    try {
      if (_install == null) return false;
      return _jsPromptAvailable()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool get isInstalled {
    try {
      if (_install == null) return false;
      return _jsIsStandalone()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> prompt() async {
    try {
      if (_install == null) return 'unavailable';
      final pending = _jsPrompt();
      if (pending == null) return 'unavailable';
      final outcome = await pending.toDart;
      final value = outcome.toDart;
      if (value.isEmpty) return 'unavailable';
      return value;
    } catch (_) {
      return 'unavailable';
    }
  }
}
