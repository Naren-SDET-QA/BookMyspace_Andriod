import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

@JS('bookMySpaceSpeech')
external JSObject? get _speech;

@JS('bookMySpaceSpeech.isSupported')
external JSBoolean? _jsIsSupported();

@JS('bookMySpaceSpeech.startListening')
external JSPromise<JSBoolean>? _jsStartListening(JSString? lang);

@JS('bookMySpaceSpeech.stopListening')
external JSPromise<JSBoolean>? _jsStopListening();

@JS('bookMySpaceSpeech.abort')
external JSPromise<JSBoolean>? _jsAbort();

@JS('bookMySpaceSpeech.setEventListener')
external void _jsSetEventListener(JSFunction callback);

/// Web implementation of WebSpeechBridge interacting with window.bookMySpaceSpeech.
class WebSpeechBridge {
  static bool get isSupported {
    try {
      if (_speech == null) return false;
      final sup = _jsIsSupported();
      return sup?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static void Function(Map<String, dynamic> event)? _onEventCallback;
  static bool _listenerRegistered = false;

  static void registerEventListener(
      void Function(Map<String, dynamic> event) onEvent) {
    _onEventCallback = onEvent;
    if (_listenerRegistered) return;
    try {
      if (_speech == null) return;
      _jsSetEventListener((JSString jsonStr) {
        try {
          final decoded = json.decode(jsonStr.toDart) as Map<String, dynamic>;
          _onEventCallback?.call(decoded);
        } catch (_) {}
      }.toJS);
      _listenerRegistered = true;
    } catch (_) {}
  }

  static Future<bool> startListening({String? language}) async {
    try {
      if (_speech == null) return false;
      final promise = _jsStartListening(language?.toJS);
      if (promise == null) return false;
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopListening() async {
    try {
      if (_speech == null) return false;
      final promise = _jsStopListening();
      if (promise == null) return false;
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> abort() async {
    try {
      if (_speech == null) return false;
      final promise = _jsAbort();
      if (promise == null) return false;
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }
}
