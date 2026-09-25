import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

@JS('bookMySpaceWebPush')
external JSObject? get _webPush;

@JS('bookMySpaceWebPush.requestPermission')
external JSPromise<JSString>? _jsRequestPermission();

@JS('bookMySpaceWebPush.getPermissionStatus')
external JSString? _jsGetPermissionStatus();

@JS('bookMySpaceWebPush.getSubscriptionJson')
external JSPromise<JSString>? _jsGetSubscriptionJson();

@JS('bookMySpaceWebPush.showNotificationJson')
external JSPromise<JSBoolean>? _jsShowNotificationJson(
    JSString title, JSString optionsJson);

@JS('bookMySpaceWebPush.unsubscribe')
external JSPromise<JSBoolean>? _jsUnsubscribe();

@JS('bookMySpaceWebPush.setEventListener')
external void _jsSetEventListener(JSFunction callback);

/// Web implementation of WebPushBridge interacting with window.bookMySpaceWebPush.
class WebPushBridge {
  static bool get isSupported => _webPush != null;

  static void Function(Map<String, dynamic> data)? _onMessageCallback;
  static void Function(Map<String, dynamic> data, String? action)?
      _onClickCallback;
  static bool _listenerRegistered = false;

  static Future<String> requestPermission() async {
    try {
      if (_webPush == null) return 'default';
      final promise = _jsRequestPermission();
      if (promise == null) return 'default';
      final result = await promise.toDart;
      return result.toDart;
    } catch (_) {
      return 'default';
    }
  }

  static Future<String> getPermissionStatus() async {
    try {
      if (_webPush == null) return 'default';
      final status = _jsGetPermissionStatus();
      return status?.toDart ?? 'default';
    } catch (_) {
      return 'default';
    }
  }

  static Future<Map<String, dynamic>?> getSubscription() async {
    try {
      if (_webPush == null) return null;
      final promise = _jsGetSubscriptionJson();
      if (promise == null) return null;
      final jsStr = await promise.toDart;
      final str = jsStr.toDart;
      if (str.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(str) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> showNotification(
    String title, {
    String? body,
    String? icon,
    String? badge,
    Map<String, dynamic>? data,
    List<Map<String, String>>? actions,
  }) async {
    try {
      if (_webPush == null) return false;
      final options = {
        if (body != null) 'body': body,
        'icon': icon ?? '/icons/Icon-192.png',
        'badge': badge ?? '/favicon.png',
        if (data != null) 'data': data,
        if (actions != null) 'actions': actions,
      };
      final optionsJson = jsonEncode(options);
      final promise = _jsShowNotificationJson(title.toJS, optionsJson.toJS);
      if (promise == null) return false;
      final res = await promise.toDart;
      return res.toDart;
    } catch (_) {
      return false;
    }
  }

  static void registerMessageListener(
      void Function(Map<String, dynamic> data) onMessage) {
    _onMessageCallback = onMessage;
    _ensureListener();
  }

  static void registerClickListener(
      void Function(Map<String, dynamic> data, String? action) onClick) {
    _onClickCallback = onClick;
    _ensureListener();
  }

  static void _ensureListener() {
    if (_listenerRegistered || _webPush == null) return;
    _listenerRegistered = true;

    final callback = ((JSString eventJson) {
      try {
        final rawStr = eventJson.toDart;
        final map = Map<String, dynamic>.from(jsonDecode(rawStr) as Map);
        final eventType = map['eventType'] as String? ?? 'message';
        final payload = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : map;

        if (eventType == 'click') {
          final action = map['action'] as String?;
          _onClickCallback?.call(payload, action);
        } else {
          _onMessageCallback?.call(payload);
        }
      } catch (_) {}
    }).toJS;

    try {
      _jsSetEventListener(callback);
    } catch (_) {}
  }

  static Future<bool> unsubscribe() async {
    try {
      if (_webPush == null) return false;
      final promise = _jsUnsubscribe();
      if (promise == null) return false;
      final res = await promise.toDart;
      return res.toDart;
    } catch (_) {
      return false;
    }
  }
}
