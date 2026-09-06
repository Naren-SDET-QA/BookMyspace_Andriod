import '../domain/notification.dart';

abstract interface class NotificationRepository {
  Future<List<Notification>> myNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
  Future<int> unreadCount();
  Future<void> addNotification(Notification notification);
  Future<void> registerPushToken(
    String token,
    String platform, {
    Map<String, dynamic>? subscriptionData,
  });
  Future<void> unregisterPushToken(String token);
}
