import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/notifications/domain/notification.dart'
    as app_notif;
import 'package:bookmyspace/features/notifications/domain/notification_repository.dart';
import 'package:bookmyspace/features/notifications/domain/push_notification_types.dart';
import 'package:bookmyspace/features/notifications/infrastructure/push_notification_service.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the service hands to the backend so the fan-out behaviour can
/// be asserted without a Supabase client.
class _FakeNotificationRepository implements NotificationRepository {
  final List<app_notif.Notification> added = <app_notif.Notification>[];
  final List<({String token, String platform})> registered = [];
  final List<String> unregistered = [];

  @override
  Future<List<app_notif.Notification>> myNotifications() async =>
      List<app_notif.Notification>.unmodifiable(added);

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<int> unreadCount() async => added.where((n) => !n.read).length;

  @override
  Future<void> addNotification(app_notif.Notification notification) async {
    added.add(notification);
  }

  @override
  Future<void> registerPushToken(
    String token,
    String platform, {
    Map<String, dynamic>? subscriptionData,
  }) async {
    registered.add((token: token, platform: platform));
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    unregistered.add(token);
  }
}

Booking _booking({
  String id = 'bk-1',
  DateTime? bookDate,
  String startTime = '18:00',
  String endTime = '19:00',
  String venueName = 'Indiranagar Rooftop Arena',
  String slotLabel = 'Evening Prime',
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-100001',
    venueId: 'venue-1',
    slotId: 'slot-1',
    bookDate: bookDate ?? DateTime.now().add(const Duration(days: 3)),
    startTime: startTime,
    endTime: endTime,
    status: BookingStatus.confirmed,
    amount: 1500,
    taxAmount: 270,
    totalAmount: 1770,
    venueName: venueName,
    slotLabel: slotLabel,
  );
}

void main() {
  late _FakeNotificationRepository repository;
  late PushNotificationService service;
  late Map<String, String> storage;

  setUp(() {
    storage = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(storage);
    repository = _FakeNotificationRepository();
    service = PushNotificationService(repository: repository);
  });

  group('capability reporting is honest', () {
    // These tests run on a host that is neither iOS, Android nor Web, so no
    // platform branch is taken. That is precisely the situation the old code
    // got wrong: it fell through to PushPermissionStatus.granted, which is how
    // Android appeared to have a working permission flow it never had.

    test('does not claim a permission that was never probed', () async {
      await service.initialize();

      expect(service.permissionStatus, PushPermissionStatus.notDetermined);
      expect(
        await service.getPermissionStatus(),
        PushPermissionStatus.notDetermined,
      );
    });

    test('reports the unprobed status rather than a hardcoded grant', () async {
      await service.initialize();

      final status = await service.getPermissionStatus();

      expect(status, service.permissionStatus);
      expect(status.isGranted, isFalse);
    });

    test('requestPermission does not invent a grant either', () async {
      await service.initialize();

      final status = await service.requestPermission();

      expect(status.isGranted, isFalse);
      expect(status, PushPermissionStatus.notDetermined);
    });

    test('names no transport that this build does not have', () async {
      await service.initialize();

      expect(service.transportLabel, isNot(contains('FCM')));
      expect(service.transportLabel, isNot(contains('APNs')));
      expect(service.isRemotePushConfigured, isFalse);
      expect(service.isLocalNotificationsOnly, isFalse);
    });
  });

  group('1-hour reminder scheduling', () {
    test('fires one hour before the slot starts', () async {
      final bookDate = DateTime.now().add(const Duration(days: 3));
      final booking = _booking(bookDate: bookDate, startTime: '18:00');

      await service.schedule1HourReminder(booking);

      expect(service.activeScheduledReminders, hasLength(1));
      final reminder = service.activeScheduledReminders.single;
      expect(reminder.bookingId, booking.id);
      expect(reminder.venueName, 'Indiranagar Rooftop Arena');
      expect(
        reminder.scheduledTriggerEpochMs,
        DateTime(bookDate.year, bookDate.month, bookDate.day, 17)
            .millisecondsSinceEpoch,
      );

      await service.cancelReminder(booking.id);
    });

    test('ignores a booking with no id', () async {
      await service.schedule1HourReminder(_booking(id: ''));

      expect(service.activeScheduledReminders, isEmpty);
    });

    test('cancelReminder clears the scheduled entry', () async {
      final booking = _booking();

      await service.schedule1HourReminder(booking);
      expect(service.activeScheduledReminders, hasLength(1));

      await service.cancelReminder(booking.id);
      expect(service.activeScheduledReminders, isEmpty);
    });

    test('parses the documented date and time formats', () {
      final expected =
          DateTime(2026, 9, 16, 9).millisecondsSinceEpoch;

      expect(
        service.calculate1HourReminderTimeMillis('2026-09-16', '10:00 AM'),
        expected,
      );
      expect(
        service.calculate1HourReminderTimeMillis('2026-09-16', '10:00'),
        expected,
      );
      expect(
        service.calculate1HourReminderTimeMillis('16 Sep 2026', '10:00 AM'),
        expected,
      );
      expect(
        service.calculate1HourReminderTimeMillis('2026-09-16', '07:30 PM'),
        DateTime(2026, 9, 16, 18, 30).millisecondsSinceEpoch,
      );
    });
  });

  group('in-app fan-out and cleanup', () {
    test('records an in-app notification even with no system surface',
        () async {
      await service.initialize();

      await service.show1HourReminderNotification(
        bookingId: 'bk-9',
        venueName: 'Nexus Workspaces',
        slotTime: '02:00 PM - 04:00 PM',
        bookingDate: '2026-09-16',
        qrCodeToken: 'BMS-PASS-9',
      );

      expect(repository.added, hasLength(1));
      expect(repository.added.single.type, '1_hour_reminder');
      expect(repository.added.single.title, contains('Nexus Workspaces'));
      expect(repository.added.single.data?['qr_token'], 'BMS-PASS-9');
    });

    test('disabling reminders persists and cancels pending ones', () async {
      await service.schedule1HourReminder(_booking());
      expect(service.activeScheduledReminders, hasLength(1));

      await service.set1HourReminderEnabled(false);

      expect(service.is1HourReminderEnabled, isFalse);
      expect(storage['pref_1_hour_reminders'], 'false');
      expect(service.activeScheduledReminders, isEmpty);
    });

    test('logoutCleanup clears the token, reminders and stored keys',
        () async {
      await service.initialize();
      await service.schedule1HourReminder(_booking());

      await service.logoutCleanup();

      expect(service.currentDeviceToken, isNull);
      expect(service.activeScheduledReminders, isEmpty);
      expect(storage.containsKey('push_token'), isFalse);
      expect(storage.containsKey('push_platform'), isFalse);
    });
  });

  group('payload parsing', () {
    test('accepts both the nested and the flat shape', () {
      final nested = PushNotificationPayload.fromMap({
        'title': 'Slot soon',
        'body': 'Starts in 1 hour',
        'data': {'booking_id': 'bk-1', 'type': '1_hour_reminder'},
      });
      expect(nested.bookingId, 'bk-1');
      expect(nested.type, '1_hour_reminder');

      final flat = PushNotificationPayload.fromMap({
        'title': 'Slot soon',
        'body': 'Starts in 1 hour',
        'booking_id': 'bk-2',
        'action': 'view_pass',
      });
      expect(flat.bookingId, 'bk-2');
      expect(flat.action, 'view_pass');
    });
  });
}
