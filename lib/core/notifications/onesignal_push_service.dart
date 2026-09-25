import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../features/notifications/domain/device_token_repository.dart';
import '../config/app_config.dart';
import '../router/app_router.dart';
import 'push_channels.dart';
import 'push_route_resolver.dart';

/// Handles OneSignal push notification registration, permission requests,
/// and foreground/background/terminated message handling.
///
/// Replaces the previous direct FCM implementation. Preserves the parts of
/// that implementation the notification architecture depends on:
///  - the same server pipeline (`notifications` -> `push_outbox` ->
///    `send-push-outbox`), which now calls OneSignal's Create Notification
///    API instead of FCM HTTP v1 -- see
///    `supabase/functions/_shared/onesignal.ts`;
///  - the same [DeviceTokenRepository] contract, so `public.device_tokens`
///    keeps a local, RLS-protected record of this device's registration
///    for observability. The `token` column now holds this device's
///    OneSignal push-subscription id instead of an FCM registration token;
///  - the same [PushRouteResolver]-driven notification-tap routing and
///    [PushChannels] Android channel taxonomy, applied to foreground
///    messages exactly as before (see the class doc on [init] for why
///    foreground display is still handled locally rather than left to
///    OneSignal's own default display).
///
/// Admin-controlled: nothing touches the OneSignal SDK until
/// [setEnabled] is called with `true` (driven by Admin settings -> Push
/// Notifications / OneSignal, see `AdminSettings.pushNotificationsEnabled`)
/// AND a valid [AppConfig.oneSignalAppId] is configured via
/// `--dart-define=ONESIGNAL_APP_ID=...` / `--dart-define-from-file`.
/// While OFF (the default) OneSignal is never initialised, no permission
/// is requested, no External ID login happens and no subscription id is
/// registered, so existing app behaviour is unchanged. Only the public App
/// ID is ever used here; the OneSignal REST API key stays server-side in
/// Supabase Edge Function secrets.
class OneSignalPushService {
  OneSignalPushService._({PushSdk? sdk, String? appId})
    : _sdkOverride = sdk,
      _appIdOverride = appId;

  /// Test seam: a service backed by a fake [PushSdk] and explicit App ID.
  @visibleForTesting
  factory OneSignalPushService.forTesting({
    required PushSdk sdk,
    required String appId,
  }) => OneSignalPushService._(sdk: sdk, appId: appId);

  static final OneSignalPushService instance = OneSignalPushService._();

  final PushSdk? _sdkOverride;
  final String? _appIdOverride;
  late final PushSdk _sdk = _sdkOverride ?? _OneSignalSdk(this);
  String get _appId => _appIdOverride ?? AppConfig.oneSignalAppId;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final _appIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// True when [appId] looks like a OneSignal App ID (a UUID).
  static bool isValidAppId(String appId) => _appIdPattern.hasMatch(appId);

  bool _enabled = false;
  bool _sdkInitialized = false;

  /// True only when an admin enabled push and the SDK was initialised.
  bool get isActive => _enabled && _sdkInitialized;

  /// Whether the SDK has ever been initialised in this process.
  bool get isSdkInitialized => _sdkInitialized;

  bool get _ready => isActive;

  DeviceTokenRepository? _tokenRepository;
  String? _signedInUserId;

  // Kept as a field (rather than a closure created inline) so the exact
  // same callback reference can be passed to removeObserver in
  // onSignedOut -- addObserver/removeObserver match by reference.
  void Function(String? subscriptionId)? _subscriptionObserver;

  /// Applies the admin Push Notifications switch.
  ///
  /// ON: initialises OneSignal with the configured App ID (once per
  /// process) and, if a user is already signed in, registers them.
  /// OFF: if push was active, deregisters this device, logs out of the
  /// External ID and opts the subscription out. OneSignal cannot be
  /// un-initialised mid-process, so a fully uninitialised state resumes on
  /// the next cold start (when the switch is read as OFF before any init).
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      if (_enabled && _sdkInitialized) return;
      _enabled = true;
      final appId = _appId;
      if (!isValidAppId(appId)) {
        debugPrint(
          'OneSignalPushService: push enabled by admin but ONESIGNAL_APP_ID '
          'is missing or invalid; push stays disabled.',
        );
        _enabled = false;
        return;
      }
      try {
        if (!_sdkInitialized) {
          await _sdk.initialize(appId);
          _sdkInitialized = true;
        } else {
          _sdk.optIn();
        }
      } catch (e) {
        debugPrint('OneSignalPushService.setEnabled failed: $e');
        _enabled = false;
        return;
      }
      final repository = _tokenRepository;
      final userId = _signedInUserId;
      if (repository != null && userId != null) {
        await _register(repository, userId);
      }
    } else {
      final wasActive = isActive;
      if (wasActive) {
        await _unregister();
        try {
          _sdk.optOut();
        } catch (e) {
          debugPrint('OneSignalPushService optOut failed: $e');
        }
      }
      _enabled = false;
    }
  }

  /// Called at most once per process, by [setEnabled] when an admin has
  /// turned push ON. Initializes the OneSignal SDK and wires the
  /// foreground-display and
  /// notification-click listeners. Does NOT request permission or
  /// associate a user with this device -- that happens in [onSignedIn],
  /// matching the previous FCM implementation's ordering (permission is
  /// only requested once someone is actually signed in).
  ///
  /// Foreground messages are intentionally displayed via
  /// [FlutterLocalNotificationsPlugin] on our own [PushChannels], the same
  /// as the previous FCM implementation, rather than left to OneSignal's
  /// default foreground display. OneSignal's own display only picks a
  /// per-type Android channel when the server payload's
  /// `android_channel_id` is configured against a channel created in the
  /// OneSignal dashboard; reproducing that mapping in code alone is not
  /// possible, so background/terminated notifications (which OneSignal
  /// always displays natively) fall back to OneSignal's default channel
  /// until that dashboard configuration is added -- see the production
  /// setup notes for this task.
  Future<void> _initializeOneSignal(String appId) async {
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    }
    OneSignal.initialize(appId);
    try {
      await _initLocalNotifications();

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // Suppress OneSignal's own display and show our own local
        // notification instead, so foreground pushes keep using
        // PushChannels/PushRouteResolver exactly as before.
        event.preventDefault();
        _showLocalNotification(event.notification);
      });

      OneSignal.Notifications.addClickListener((event) {
        _navigateTo(
          PushRouteResolver.resolve(
            event.notification.additionalData ?? const <String, dynamic>{},
          ),
        );
      });
    } catch (e) {
      debugPrint('OneSignalPushService listener setup failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _navigateTo(route);
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in PushChannels.all) {
      await androidPlugin?.createNotificationChannel(channel);
    }
    await androidPlugin?.requestNotificationsPermission();
  }

  void _showLocalNotification(OSNotification notification) {
    final data = notification.additionalData ?? const <String, dynamic>{};
    final title = notification.title ?? 'BookMySpace';
    final body = notification.body ?? '';
    final channelId = PushChannels.channelIdForType(
      data['notification_type'] ?? data['type'],
    );
    final route = PushRouteResolver.resolve(data);
    unawaited(
      _localNotifications.show(
        notification.notificationId.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            PushChannels.nameFor(channelId),
            channelDescription: PushChannels.descriptionFor(channelId),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: route,
      ),
    );
  }

  void _navigateTo(String route) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    try {
      // Shell destinations (e.g. /bookings) must use go, not push, or a
      // second stack is created and query params like highlight= are dropped.
      GoRouter.of(context).go(route);
    } catch (e) {
      debugPrint('OneSignalPushService navigation failed: $e');
    }
  }

  /// Requests notification permission, associates this device with
  /// [userId] via OneSignal's External ID (`OneSignal.login`) so server
  /// sends can target `include_aliases.external_id: [userId]`, and
  /// registers the resulting push-subscription id against [userId] in our
  /// own `device_tokens` table via [repository] for observability. Also
  /// observes subscription-id changes (OneSignal's equivalent of FCM token
  /// refresh) so a rotated subscription id stays registered. Called on
  /// sign-in with the just-authenticated user's id.
  Future<void> onSignedIn(DeviceTokenRepository repository, String userId) async {
    _tokenRepository = repository;
    if (userId.isEmpty) return;
    _signedInUserId = userId;
    if (!_ready) return;
    await _register(repository, userId);
  }

  Future<void> _register(DeviceTokenRepository repository, String userId) async {
    try {
      await _sdk.requestPermission();

      // Associates this device's push subscription(s) with our own user id
      // on OneSignal's backend. This -- not local bookkeeping -- is what
      // send-push-outbox actually targets, and what prevents a previous
      // account's pushes from continuing to arrive after a different user
      // signs in on the same device (see onSignedOut for the logout half).
      _sdk.login(userId);

      final currentId = _sdk.subscriptionId;
      if (currentId != null && currentId.isNotEmpty) {
        await repository.registerToken(
          token: currentId,
          platform: _platformName(),
        );
      }

      _removeSubscriptionObserver();
      _subscriptionObserver = (id) {
        if (id != null && id.isNotEmpty) {
          unawaited(
            repository.registerToken(token: id, platform: _platformName()),
          );
        }
      };
      _sdk.addSubscriptionObserver(_subscriptionObserver!);
    } catch (e) {
      debugPrint('OneSignalPushService.onSignedIn failed: $e');
    }
  }

  /// Deregisters this device's OneSignal subscription id and logs the
  /// device out of OneSignal's External ID association. Called on
  /// sign-out (while the Supabase session is still valid, so RLS still
  /// permits deleting the `device_tokens` row) so a shared device does not
  /// keep receiving push notifications for the previous account.
  /// A no-op for the SDK while push is disabled by admin.
  Future<void> onSignedOut() async {
    try {
      await _unregister();
    } finally {
      _tokenRepository = null;
      _signedInUserId = null;
    }
  }

  Future<void> _unregister() async {
    final repository = _tokenRepository;
    try {
      if (_ready && repository != null) {
        final id = _sdk.subscriptionId;
        if (id != null && id.isNotEmpty) await repository.deregisterToken(id);
      }
      if (_ready) _sdk.logout();
    } catch (e) {
      debugPrint('OneSignalPushService.onSignedOut failed: $e');
    } finally {
      _removeSubscriptionObserver();
    }
  }

  void _removeSubscriptionObserver() {
    final observer = _subscriptionObserver;
    if (observer != null && _sdkInitialized) {
      try {
        _sdk.removeSubscriptionObserver(observer);
      } catch (e) {
        debugPrint('OneSignalPushService removeObserver failed: $e');
      }
    }
    _subscriptionObserver = null;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}

/// Minimal seam over the OneSignal SDK calls this service makes, so the
/// admin enable/disable behaviour can be unit-tested without the native
/// platform channel.
abstract class PushSdk {
  Future<void> initialize(String appId);
  Future<void> requestPermission();
  void login(String externalId);
  void logout();
  void optIn();
  void optOut();
  String? get subscriptionId;
  void addSubscriptionObserver(void Function(String? id) observer);
  void removeSubscriptionObserver(void Function(String? id) observer);
}

class _OneSignalSdk implements PushSdk {
  _OneSignalSdk(this._service);

  final OneSignalPushService _service;
  final Map<
    void Function(String? id),
    void Function(OSPushSubscriptionChangedState state)
  >
  _observers = {};

  @override
  Future<void> initialize(String appId) =>
      _service._initializeOneSignal(appId);

  @override
  Future<void> requestPermission() async {
    await OneSignal.Notifications.requestPermission(true);
  }

  @override
  void login(String externalId) => OneSignal.login(externalId);

  @override
  void logout() => OneSignal.logout();

  @override
  void optIn() => OneSignal.User.pushSubscription.optIn();

  @override
  void optOut() => OneSignal.User.pushSubscription.optOut();

  @override
  String? get subscriptionId => OneSignal.User.pushSubscription.id;

  @override
  void addSubscriptionObserver(void Function(String? id) observer) {
    void wrapped(OSPushSubscriptionChangedState state) =>
        observer(state.current.id);
    _observers[observer] = wrapped;
    OneSignal.User.pushSubscription.addObserver(wrapped);
  }

  @override
  void removeSubscriptionObserver(void Function(String? id) observer) {
    final wrapped = _observers.remove(observer);
    if (wrapped != null) {
      OneSignal.User.pushSubscription.removeObserver(wrapped);
    }
  }
}
