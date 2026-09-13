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

  @override
  Future<List<Notification>> myNotifications() async {
    final userId = _userId;
    if (userId == null) {
      return const [];
    }

    try {
      final rows = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map((r) => Notification.fromJson(r)).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
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
    final userId = _userId;
    if (userId == null) return;

    try {
      await _client.from('notifications').update({
        'read': true,
        'read_at': DateTime.now().toIso8601String()
      }).eq('user_id', userId);
    } catch (e) {
      // Soft-fail
    }
  }

  @override
  Future<int> unreadCount() async {
    final userId = _userId;
    if (userId == null) {
      return 0;
    }

    try {
      final rows = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);
      return rows.length;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> addNotification(Notification notification) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Let Postgres generate the UUID and bind the row to the current user.
      // Push payloads are not trusted to choose an account or primary key.
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type,
        'data': notification.data,
        'read': notification.read,
        if (notification.readAt != null)
          'read_at': notification.readAt!.toIso8601String(),
        'created_at': notification.createdAt.toIso8601String(),
      });
    } catch (_) {
      // Push delivery should not crash the app if in-app persistence is unavailable.
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
            if (platform == 'ios')
              'apns_token': token
            else
              'web_push_token': token,
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
