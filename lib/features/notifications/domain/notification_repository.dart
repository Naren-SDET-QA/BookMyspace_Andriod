import '../domain/notification.dart';

abstract interface class NotificationRepository {
  Future<List<Notification>> myNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();

  /// Permanently deletes one of my notifications.
  Future<void> delete(String notificationId);

  /// Permanently deletes all of my notifications.
  Future<void> clearAll();
  Future<int> unreadCount();
  Future<void> addNotification(Notification notification);
  Future<void> registerPushToken(
    String token,
    String platform, {
    Map<String, dynamic>? subscriptionData,
  });
  Future<void> unregisterPushToken(String token);

  /// Records an in-app notification for the current user (RLS allows users
  /// to insert rows for themselves; used for booking lifecycle events).
  Future<void> create({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  });
}
