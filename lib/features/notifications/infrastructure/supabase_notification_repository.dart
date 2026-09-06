import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/notification.dart';
import '../domain/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  String? get _userId => _client.auth.currentUser?.id;

  // Local fallback notifications list matching Android BookMySpaceRepository sample data
  final List<Notification> _localNotifications = [
    Notification(
      id: 'notif_1',
      userId: 'system',
      title: 'Booking Confirmed! 🎟️',
      body: 'Your badminton court slot at Velocity Pro Sports Arena is confirmed for 20 Aug at 7:00 AM.',
      type: 'booking',
      read: false,
      data: {
        'booking_id': 'bk_demo_1',
        'venue_name': 'Velocity Pro Sports Arena',
        'slot_time': '07:00 AM - 08:00 AM',
        'qr_token': 'BMS-PASS-DEMO1',
      },
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Notification(
      id: 'notif_2',
      userId: 'system',
      title: '1-Hour Pre-Slot Reminder ⚡',
      body: 'Your upcoming court booking starts in 1 hour. Tap to view and scan your check-in pass.',
      type: '1_hour_reminder',
      read: false,
      data: {
        'booking_id': 'bk_demo_2',
        'venue_name': 'Velocity Pro Sports Arena',
        'slot_time': '10:00 AM - 11:00 AM',
        'qr_token': 'BMS-PASS-DEMO2',
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Notification(
      id: 'notif_3',
      userId: 'system',
      title: 'Referral Bonus Added! 💰',
      body: 'Sneha signed up using your link. ₹500 referral credit will unlock after their first booking.',
      type: 'general',
      read: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<List<Notification>> myNotifications() async {
    final userId = _userId;
    if (userId == null) {
      return List.unmodifiable(_localNotifications);
    }

    try {
      final rows = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      final remoteList = rows.map((r) => Notification.fromJson(r)).toList();
      if (remoteList.isEmpty) {
        return List.unmodifiable(_localNotifications);
      }
      return remoteList;
    } catch (_) {
      // Fallback to local notifications
      return List.unmodifiable(_localNotifications);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    // Update local list
    final idx = _localNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _localNotifications[idx] = _localNotifications[idx].copyWith(
        read: true,
        readAt: DateTime.now(),
      );
    }

    final userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      // Soft-fail: local is already updated
    }
  }

  @override
  Future<void> markAllRead() async {
    for (int i = 0; i < _localNotifications.length; i++) {
      _localNotifications[i] = _localNotifications[i].copyWith(
        read: true,
        readAt: DateTime.now(),
      );
    }

    final userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
    } catch (e) {
      // Soft-fail
    }
  }

  @override
  Future<int> unreadCount() async {
    final userId = _userId;
    if (userId == null) {
      return _localNotifications.where((n) => !n.read).length;
    }

    try {
      final rows = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);
      return rows.length;
    } catch (_) {
      return _localNotifications.where((n) => !n.read).length;
    }
  }

  @override
  Future<void> addNotification(Notification notification) async {
    // Prepend to local memory list so it is instantly reactive
    _localNotifications.insert(0, notification);

    final userId = _userId;
    if (userId == null) return;

    try {
      await _client.from('notifications').insert(notification.toJson());
    } catch (_) {
      // Soft-fail if remote table unavailable
    }
  }

  @override
  Future<void> registerPushToken(
    String token,
    String platform, {
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      await _storage.write(key: 'push_token', value: token);
      await _storage.write(key: 'push_platform', value: platform);

      final userId = _userId;
      if (userId == null || token.isEmpty) return;

      // Upsert device token in Supabase
      try {
        await _client.from('device_tokens').upsert({
          'user_id': userId,
          'token': token,
          'platform': platform,
          'subscription_data': subscriptionData,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Fallback: try update user profile column if device_tokens table doesn't exist
        try {
          await _client.from('users').update({
            if (platform == 'ios') 'apns_token': token else 'web_push_token': token,
            'push_platform': platform,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
        } catch (_) {
          // Soft-fail, token is cached locally
        }
      }
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    try {
      await _storage.delete(key: 'push_token');
      await _storage.delete(key: 'push_platform');

      final userId = _userId;
      if (userId == null || token.isEmpty) return;

      try {
        await _client
            .from('device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      } catch (_) {
        // Soft-fail
      }
    } catch (_) {
      // Ignore errors on logout cleanup
    }
  }
}
