import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../booking/domain/booking.dart';
import '../domain/notification.dart' as app_notif;
import '../domain/notification_repository.dart';
import '../domain/push_notification_types.dart';
import 'web_push_bridge.dart';

/// Central Push Notification Service for BookMySpace Flutter (iOS & Web).
///
/// Features:
/// - iOS: APNs native registration, category actions (View Pass, Directions),
///   foreground presentation banner/sound, background fetch, badge management.
/// - Web: Web Push API, Service Worker registration, push event display,
///   notificationclick deep link dispatching.
/// - 1-Hour Pre-Booking Reminder scheduling, triggering & simulation matching Android.
/// - System-level permission requests and status checking.
/// - Deep link routing with GoRouter.
/// - Complete logout cleanup.
class PushNotificationService {
  PushNotificationService({
    required NotificationRepository repository,
    FlutterSecureStorage? storage,
  })  : _repository = repository,
        _storage = storage ?? const FlutterSecureStorage();

  static const String apnsChannelName = 'com.bookmyspace.bookmyspace/apns_push';
  final MethodChannel _apnsChannel = const MethodChannel(apnsChannelName);

  final NotificationRepository _repository;
  final FlutterSecureStorage _storage;

  final StreamController<PushNotificationPayload>
      _notificationReceivedController =
      StreamController<PushNotificationPayload>.broadcast();
  final StreamController<PushNotificationPayload>
      _notificationClickedController =
      StreamController<PushNotificationPayload>.broadcast();

  Stream<PushNotificationPayload> get onNotificationReceived =>
      _notificationReceivedController.stream;
  Stream<PushNotificationPayload> get onNotificationClicked =>
      _notificationClickedController.stream;

  final Map<String, ScheduledReminderInfo> _scheduledReminders = {};
  final Map<String, Timer> _activeTimers = {};

  String? _currentDeviceToken;
  PushPermissionStatus _permissionStatus = PushPermissionStatus.notDetermined;
  bool _initialized = false;
  bool _is1HourReminderEnabled = true;

  String? get currentDeviceToken => _currentDeviceToken;
  PushPermissionStatus get permissionStatus => _permissionStatus;
  bool get is1HourReminderEnabled => _is1HourReminderEnabled;
  List<ScheduledReminderInfo> get activeScheduledReminders =>
      _scheduledReminders.values.toList();

  /// Initializes system push listeners for the current platform (iOS or Web).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Load persisted token and toggle preference
    try {
      _currentDeviceToken = await _storage.read(key: 'push_token');
      final toggleVal = await _storage.read(key: 'pref_1_hour_reminders');
      if (toggleVal != null) {
        _is1HourReminderEnabled = toggleVal == 'true';
      }
    } catch (_) {}

    if (kIsWeb) {
      await _initializeWeb();
    } else if (!kIsWeb && Platform.isIOS) {
      await _initializeIos();
    }

    // Also listen to internal clicked stream to perform deep-link navigation
    onNotificationClicked.listen((payload) {
      handleNotificationRouting(payload.data ?? payload.toMap(),
          action: payload.action);
    });
  }

  // ---------------------------------------------------------------------------
  // iOS APNs Initialization & Native MethodChannel Handling
  // ---------------------------------------------------------------------------

  Future<void> _initializeIos() async {
    _apnsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTokenReceived':
          final token =
              call.arguments is Map ? call.arguments['token'] as String? : null;
          if (token != null && token.isNotEmpty) {
            _currentDeviceToken = token;
            await _storage.write(key: 'push_token', value: token);
            await _repository.registerPushToken(token, 'ios');
          }
          break;

        case 'onNotificationReceived':
          final args = call.arguments is Map
              ? Map<String, dynamic>.from(call.arguments as Map)
              : <String, dynamic>{};
          final payload = PushNotificationPayload.fromMap(args);
          _notificationReceivedController.add(payload);
          // Insert into in-app notifications so it displays in notification feed
          await _recordInAppNotification(payload);
          break;

        case 'onNotificationClicked':
          final args = call.arguments is Map
              ? Map<String, dynamic>.from(call.arguments as Map)
              : <String, dynamic>{};
          final payload = PushNotificationPayload.fromMap(args);
          _notificationClickedController.add(payload);
          break;
      }
    });

    // Check existing iOS permission status and retrieve stored APNs token
    try {
      final statusResult =
          await _apnsChannel.invokeMethod<Map>('getPermissionStatus');
      final statusStr = statusResult?['status'] as String? ?? 'notDetermined';
      _permissionStatus = _parseIosPermissionStatus(statusStr);

      final tokenResult = await _apnsChannel.invokeMethod<Map>('getApnsToken');
      final token = tokenResult?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        _currentDeviceToken = token;
        await _storage.write(key: 'push_token', value: token);
        await _repository.registerPushToken(token, 'ios');
      }

      // Check if cold-started by tapping a notification
      final initialNotif =
          await _apnsChannel.invokeMethod<Map>('getInitialNotification');
      if (initialNotif != null) {
        final payload = PushNotificationPayload.fromMap(
            Map<String, dynamic>.from(initialNotif));
        _notificationClickedController.add(payload);
      }
    } catch (e) {
      debugPrint('⚠️ [APNs] iOS initialization error: $e');
    }
  }

  PushPermissionStatus _parseIosPermissionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'authorized':
      case 'granted':
        return PushPermissionStatus.granted;
      case 'denied':
        return PushPermissionStatus.denied;
      case 'provisional':
        return PushPermissionStatus.provisional;
      default:
        return PushPermissionStatus.notDetermined;
    }
  }

  // ---------------------------------------------------------------------------
  // Web Push API & Service Worker Handling
  // ---------------------------------------------------------------------------

  Future<void> _initializeWeb() async {
    try {
      final status = await WebPushBridge.getPermissionStatus();
      _permissionStatus = _parseWebPermissionStatus(status);

      // Register web message and click listeners
      WebPushBridge.registerMessageListener((data) async {
        final payload = PushNotificationPayload.fromMap(data);
        _notificationReceivedController.add(payload);
        await _recordInAppNotification(payload);
      });

      WebPushBridge.registerClickListener((data, action) {
        final payload = PushNotificationPayload.fromMap({
          ...data,
          if (action != null) 'action': action,
        });
        _notificationClickedController.add(payload);
      });

      if (_permissionStatus == PushPermissionStatus.granted) {
        await _refreshWebSubscription();
      }
    } catch (e) {
      debugPrint('⚠️ [WebPush] Web initialization error: $e');
    }
  }

  PushPermissionStatus _parseWebPermissionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'granted':
        return PushPermissionStatus.granted;
      case 'denied':
        return PushPermissionStatus.denied;
      default:
        return PushPermissionStatus.notDetermined;
    }
  }

  Future<void> _refreshWebSubscription() async {
    try {
      final sub = await WebPushBridge.getSubscription();
      if (sub != null) {
        final endpoint = sub['endpoint'] as String? ??
            'web_push_endpoint_${DateTime.now().millisecondsSinceEpoch}';
        _currentDeviceToken = endpoint;
        await _storage.write(key: 'push_token', value: endpoint);
        await _repository.registerPushToken(endpoint, 'web',
            subscriptionData: sub);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Permission Handling
  // ---------------------------------------------------------------------------

  /// Requests system-level push notification permission from the user.
  Future<PushPermissionStatus> requestPermission() async {
    if (kIsWeb) {
      final res = await WebPushBridge.requestPermission();
      _permissionStatus = _parseWebPermissionStatus(res);
      if (_permissionStatus == PushPermissionStatus.granted) {
        await _refreshWebSubscription();
      }
      return _permissionStatus;
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        final result =
            await _apnsChannel.invokeMethod<Map>('requestPermission');
        final granted = result?['granted'] as bool? ?? false;
        _permissionStatus = granted
            ? PushPermissionStatus.granted
            : PushPermissionStatus.denied;

        if (granted) {
          final tokenResult =
              await _apnsChannel.invokeMethod<Map>('getApnsToken');
          final token = tokenResult?['token'] as String?;
          if (token != null && token.isNotEmpty) {
            _currentDeviceToken = token;
            await _storage.write(key: 'push_token', value: token);
            await _repository.registerPushToken(token, 'ios');
          }
        }
        return _permissionStatus;
      } catch (e) {
        debugPrint('⚠️ [APNs] requestPermission error: $e');
        return PushPermissionStatus.denied;
      }
    } else {
      _permissionStatus = PushPermissionStatus.granted;
      return _permissionStatus;
    }
  }

  /// Refreshes and returns the current permission status.
  Future<PushPermissionStatus> getPermissionStatus() async {
    if (kIsWeb) {
      final status = await WebPushBridge.getPermissionStatus();
      _permissionStatus = _parseWebPermissionStatus(status);
      return _permissionStatus;
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        final result =
            await _apnsChannel.invokeMethod<Map>('getPermissionStatus');
        final statusStr = result?['status'] as String? ?? 'notDetermined';
        _permissionStatus = _parseIosPermissionStatus(statusStr);
        return _permissionStatus;
      } catch (_) {
        return _permissionStatus;
      }
    }
    return PushPermissionStatus.granted;
  }

  // ---------------------------------------------------------------------------
  // 1-Hour Pre-Booking Reminder Engine (Matching Android BookingReminderNotificationManager)
  // ---------------------------------------------------------------------------

  /// Calculates the epoch millisecond timestamp 1 hour prior to booking start time.
  int calculate1HourReminderTimeMillis(String dateStr, String startTimeStr) {
    final now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month, now.day);

    final cleanDate = dateStr.trim();
    final dateFormats = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd MMM yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('MMM dd, yyyy'),
    ];

    bool dateParsed = false;
    for (final df in dateFormats) {
      try {
        final parsed = df.parse(cleanDate);
        targetDate = DateTime(parsed.year, parsed.month, parsed.day);
        dateParsed = true;
        break;
      } catch (_) {}
    }

    if (!dateParsed) {
      if (cleanDate.toLowerCase().contains('tomorrow')) {
        targetDate = targetDate.add(const Duration(days: 1));
      }
    }

    // Parse Start Time (e.g. "10:00 AM", "07:30 PM", "14:00")
    int hour = 9;
    int minute = 0;
    final cleanTime = startTimeStr.trim();
    final timeFormats = [
      DateFormat('hh:mm a'),
      DateFormat('h:mm a'),
      DateFormat('hh:mma'),
      DateFormat('HH:mm'),
    ];

    for (final tf in timeFormats) {
      try {
        final parsed = tf.parse(cleanTime);
        hour = parsed.hour;
        minute = parsed.minute;
        break;
      } catch (_) {}
    }

    final slotStart = DateTime(
        targetDate.year, targetDate.month, targetDate.day, hour, minute);
    // 1 hour prior to slot start
    final oneHourBefore = slotStart.subtract(const Duration(hours: 1));
    return oneHourBefore.millisecondsSinceEpoch;
  }

  /// Schedules a 1-Hour Pre-Booking Reminder for the booking on iOS (APNs local notification trigger)
  /// or Web (Web Push Timer / Service Worker).
  Future<void> schedule1HourReminder(Booking booking) async {
    if (booking.id.isEmpty) return;

    final dateLabel = booking.bookDate.toIso8601String().split('T').first;
    final startLabel =
        booking.startTime.isNotEmpty ? booking.startTime : '10:00 AM';
    final reminderEpochMs =
        calculate1HourReminderTimeMillis(dateLabel, startLabel);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final venueName =
        booking.venueName.isNotEmpty ? booking.venueName : 'BookMySpace Venue';
    final slotLabel = booking.slotLabel.isNotEmpty
        ? booking.slotLabel
        : '${booking.startTime} - ${booking.endTime}'.trim().isNotEmpty
            ? '${booking.startTime} - ${booking.endTime}'
            : 'Reserved Slot';
    final qrToken =
        'BMS-PASS-${booking.id.length > 6 ? booking.id.substring(booking.id.length - 6).toUpperCase() : booking.id.toUpperCase()}';

    final info = ScheduledReminderInfo(
      bookingId: booking.id,
      venueName: venueName,
      slotLabel: slotLabel,
      bookingDate: dateLabel,
      scheduledTriggerEpochMs: reminderEpochMs,
    );
    _scheduledReminders[booking.id] = info;

    final delayMs = reminderEpochMs - nowMs;

    if (delayMs > 0) {
      if (!kIsWeb && Platform.isIOS) {
        // Schedule iOS local notification via APNs method channel
        try {
          await _apnsChannel.invokeMethod('showNotification', {
            'id': 'reminder_${booking.id}',
            'title': '⏰ Booking Starts in 1 Hour: $venueName',
            'body':
                'Reminder: Your slot ($slotLabel) begins in 1 hour. Tap to view your check-in pass.',
            'categoryIdentifier': '1_HOUR_REMINDER',
            'delaySeconds': (delayMs / 1000).clamp(1, 31536000),
            'data': {
              'type': '1_hour_reminder',
              'booking_id': booking.id,
              'venue_name': venueName,
              'slot_time': slotLabel,
              'booking_date': dateLabel,
              'qr_token': qrToken,
            },
          });
        } catch (_) {}
      } else {
        // On Web: schedule a Dart Timer
        _activeTimers[booking.id]?.cancel();
        _activeTimers[booking.id] = Timer(Duration(milliseconds: delayMs), () {
          show1HourReminderNotification(
            bookingId: booking.id,
            venueName: venueName,
            slotTime: slotLabel,
            bookingDate: dateLabel,
            qrCodeToken: qrToken,
          );
        });
      }
    }
  }

  /// Cancels an active 1-Hour reminder for a booking.
  Future<void> cancelReminder(String bookingId) async {
    _scheduledReminders.remove(bookingId);
    _activeTimers[bookingId]?.cancel();
    _activeTimers.remove(bookingId);

    if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('cancelNotification', {
          'id': 'reminder_$bookingId',
        });
      } catch (_) {}
    }
  }

  /// Shows an immediate rich Heads-Up Push Notification indicating a booking starts in 1 hour.
  /// Matches Android's `show1HourReminderNotification` with action buttons "View Pass" & "Directions".
  Future<void> show1HourReminderNotification({
    required String bookingId,
    required String venueName,
    required String slotTime,
    required String bookingDate,
    required String qrCodeToken,
    String? customTitle,
    String? customBody,
  }) async {
    final title = customTitle ?? '⏰ Booking Starts in 1 Hour: $venueName';
    final body = customBody ??
        'Reminder: Your slot ($slotTime) begins in 1 hour. Tap to view your check-in pass.';

    final payloadData = {
      'type': '1_hour_reminder',
      'booking_id': bookingId,
      'venue_name': venueName,
      'slot_time': slotTime,
      'booking_date': bookingDate,
      'qr_token': qrCodeToken,
    };

    if (kIsWeb) {
      await WebPushBridge.showNotification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/favicon.png',
        data: payloadData,
        actions: [
          {'action': 'view_pass', 'title': '🎟️ View Pass'},
          {'action': 'directions', 'title': '🗺️ Directions'},
        ],
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('showNotification', {
          'id': '1_hour_${DateTime.now().millisecondsSinceEpoch}',
          'title': title,
          'body': body,
          'categoryIdentifier': '1_HOUR_REMINDER',
          'data': payloadData,
        });
      } catch (_) {}
    }

    // In-app notification record
    final payload = PushNotificationPayload(
      title: title,
      body: body,
      type: '1_hour_reminder',
      bookingId: bookingId,
      venueName: venueName,
      slotTime: slotTime,
      bookingDate: bookingDate,
      qrCodeToken: qrCodeToken,
      data: payloadData,
    );
    _notificationReceivedController.add(payload);
    await _recordInAppNotification(payload);
  }

  /// Instantly triggers a test 1-Hour Pre-Booking Reminder notification.
  Future<void> trigger1HourReminderNow(Booking? booking) async {
    final target = booking ??
        Booking(
          id: 'bk_live_${(1000 + DateTime.now().millisecond % 9000)}',
          bookingRef: 'BMS-LIVE',
          venueId: 'v1',
          slotId: 'slot_live',
          bookDate: DateTime.now(),
          startTime: '11:00 AM',
          endTime: '12:00 PM',
          slotLabel: '11:00 AM - 12:00 PM',
          amount: 1200,
          taxAmount: 0,
          totalAmount: 1200,
          status: BookingStatus.confirmed,
          venueName: 'Smash Arena International',
        );

    await show1HourReminderNotification(
      bookingId: target.id,
      venueName: target.venueName.isNotEmpty
          ? target.venueName
          : 'Smash Arena International',
      slotTime: target.slotLabel.isNotEmpty
          ? target.slotLabel
          : '11:00 AM - 12:00 PM',
      bookingDate: target.bookDate.toIso8601String().split('T').first,
      qrCodeToken: 'BMS-PASS-${target.id.toUpperCase()}',
      customTitle:
          '⏰ Booking Starts in 1 Hour: ${target.venueName.isNotEmpty ? target.venueName : 'Smash Arena'}',
      customBody:
          'Reminder: Your slot (${target.slotLabel}) begins in 60 minutes. Your QR pass is ready for check-in.',
    );
  }

  /// Simulates receiving a cloud push payload from APNs (iOS) or Web Push (Web).
  Future<void> simulateCloudPush({
    String? customTitle,
    String? customBody,
    Map<String, dynamic>? extraData,
  }) async {
    final title = customTitle ?? '🚀 Cloud Push Alert: Slot in 1 Hour';
    final body = customBody ??
        'BookMySpace Cloud Notification Engine has delivered your 1-hour pre-booking alert for Nexus Workspaces.';

    final payloadData = {
      'type': '1_hour_reminder',
      'booking_id': 'bk_cloud_${(1000 + DateTime.now().millisecond % 9000)}',
      'venue_name': 'Nexus Workspaces',
      'slot_time': '02:00 PM - 04:00 PM',
      'booking_date': 'Today',
      'qr_token': 'BMS-PASS-CLOUD-77',
      ...?extraData,
    };

    if (kIsWeb) {
      await WebPushBridge.showNotification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/favicon.png',
        data: payloadData,
        actions: [
          {'action': 'view_pass', 'title': '🎟️ View Pass'},
          {'action': 'directions', 'title': '🗺️ Directions'},
        ],
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('showNotification', {
          'id': 'cloud_push_${DateTime.now().millisecondsSinceEpoch}',
          'title': title,
          'body': body,
          'categoryIdentifier': '1_HOUR_REMINDER',
          'data': payloadData,
        });
      } catch (_) {}
    }

    final payload = PushNotificationPayload.fromMap({
      'title': title,
      'body': body,
      'data': payloadData,
    });
    _notificationReceivedController.add(payload);
    await _recordInAppNotification(payload);
  }

  /// Shows immediate push notification when spots open for a batch or course.
  Future<void> showBatchSpotAvailablePush({
    required String classId,
    required String className,
    required String instituteName,
    int availableSpots = 3,
  }) async {
    final title = '🎉 Spots Available! $className';
    final body =
        '$availableSpots spot(s) have just opened up for $className at $instituteName. Tap to book your seat before it fills up!';

    final data = {
      'type': 'course_alert',
      'course_id': classId,
      'class_id': classId,
      'class_name': className,
      'institute_name': instituteName,
    };

    if (kIsWeb) {
      await WebPushBridge.showNotification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/favicon.png',
        data: data,
        actions: [
          {'action': 'book_now', 'title': '⚡ Book Seat Now'},
        ],
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('showNotification', {
          'id': 'batch_$classId',
          'title': title,
          'body': body,
          'categoryIdentifier': 'BATCH_AVAILABILITY',
          'data': data,
        });
      } catch (_) {}
    }

    final payload = PushNotificationPayload.fromMap({
      'title': title,
      'body': body,
      'data': data,
    });
    _notificationReceivedController.add(payload);
    await _recordInAppNotification(payload);
  }

  /// Shows confirmation push notification when user subscribes to waitlist.
  Future<void> showBatchWaitlistSubscribedPush({
    required String classId,
    required String className,
    required String instituteName,
  }) async {
    final title = '🔔 Alert Active: $className';
    final body =
        "You're on the priority waitlist for $className at $instituteName. We'll send a push notification the moment seats open.";

    final data = {
      'type': 'alert_registered',
      'course_id': classId,
      'class_id': classId,
      'class_name': className,
      'institute_name': instituteName,
    };

    if (kIsWeb) {
      await WebPushBridge.showNotification(
        title,
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/favicon.png',
        data: data,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('showNotification', {
          'id': 'waitlist_$classId',
          'title': title,
          'body': body,
          'categoryIdentifier': 'GENERAL_ALERT',
          'data': data,
        });
      } catch (_) {}
    }

    final payload = PushNotificationPayload.fromMap({
      'title': title,
      'body': body,
      'data': data,
    });
    _notificationReceivedController.add(payload);
    await _recordInAppNotification(payload);
  }

  // ---------------------------------------------------------------------------
  // Notification Routing (Deep Linking)
  // ---------------------------------------------------------------------------

  /// Performs deep linking navigation when a notification or action button is tapped.
  void handleNotificationRouting(Map<String, dynamic> data, {String? action}) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    final targetAction = action ?? data['action'] as String?;
    final reminderType =
        data['type'] as String? ?? data['reminder_type'] as String? ?? '';
    final bookingId =
        data['booking_id'] as String? ?? data['bookingId'] as String?;
    final venueId = data['venue_id'] as String? ?? data['venueId'] as String?;
    final courseId = data['course_id'] as String? ??
        data['courseId'] as String? ??
        data['class_id'] as String?;

    // 1. Directions action: open venue map
    if (targetAction == 'directions') {
      if (venueId != null && venueId.isNotEmpty) {
        navContext.go(AppRoutes.map, extra: {'venueId': venueId});
      } else {
        navContext.go(AppRoutes.map);
      }
      return;
    }

    // 2. View Pass or 1-Hour pre-booking reminder: open bookings tab with QR pass
    if (targetAction == 'view_pass' ||
        reminderType == '1_hour_reminder' ||
        (bookingId != null && bookingId.isNotEmpty)) {
      navContext.go(AppRoutes.bookings);
      return;
    }

    // 3. Venue alert
    if (venueId != null && venueId.isNotEmpty) {
      navContext.go('/venues/$venueId');
      return;
    }

    // 4. Course / Batch alert
    if (courseId != null && courseId.isNotEmpty) {
      navContext.go('/courses/$courseId');
      return;
    }

    // 5. Default fallback
    navContext.go(AppRoutes.notifications);
  }

  // ---------------------------------------------------------------------------
  // Reminder Toggle & Preferences
  // ---------------------------------------------------------------------------

  Future<void> set1HourReminderEnabled(bool enabled) async {
    _is1HourReminderEnabled = enabled;
    await _storage.write(
        key: 'pref_1_hour_reminders', value: enabled ? 'true' : 'false');
    if (!enabled) {
      // Cancel all active scheduled reminders
      for (final id in _scheduledReminders.keys.toList()) {
        await cancelReminder(id);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Logout Cleanup
  // ---------------------------------------------------------------------------

  /// Performs full cleanup on user logout:
  /// - Unregisters push device token / subscription from Supabase backend
  /// - Removes cached tokens from secure storage
  /// - Cancels active timers and scheduled reminders
  /// - Resets iOS badge count
  Future<void> logoutCleanup() async {
    final token = _currentDeviceToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _repository.unregisterPushToken(token);
      } catch (_) {}
    }

    _currentDeviceToken = null;
    await _storage.delete(key: 'push_token');
    await _storage.delete(key: 'push_platform');

    // Cancel all scheduled timers and reminders
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _scheduledReminders.clear();

    // Clear platform badges and unregister if needed
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _apnsChannel.invokeMethod('clearBadge');
      } catch (_) {}
    } else if (kIsWeb) {
      try {
        await WebPushBridge.unsubscribe();
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  Future<void> _recordInAppNotification(PushNotificationPayload payload) async {
    final notif = app_notif.Notification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'system',
      title: payload.title,
      body: payload.body,
      type: payload.type,
      read: false,
      data: payload.data ?? payload.toMap(),
      createdAt: DateTime.now(),
    );
    try {
      await _repository.addNotification(notif);
    } catch (_) {}
  }
}
