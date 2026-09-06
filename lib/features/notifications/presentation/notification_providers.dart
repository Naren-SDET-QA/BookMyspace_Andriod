import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../domain/notification.dart';
import '../domain/notification_repository.dart';
import '../domain/push_notification_types.dart';
import '../infrastructure/push_notification_service.dart';
import '../infrastructure/supabase_notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseNotificationRepository(client);
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final service = PushNotificationService(repository: repo);
  service.initialize();
  return service;
});

final pushPermissionStatusProvider = FutureProvider<PushPermissionStatus>((ref) async {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.getPermissionStatus();
});

final pushTokenProvider = Provider<String?>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.currentDeviceToken;
});

final is1HourReminderEnabledProvider = StateProvider<bool>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.is1HourReminderEnabled;
});

final myNotificationsProvider = FutureProvider<List<Notification>>((ref) {
  return ref.watch(notificationRepositoryProvider).myNotifications();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final markNotificationReadProvider = FutureProvider.autoDispose
    .family<void, String>((ref, notificationId) async {
      final repo = ref.watch(notificationRepositoryProvider);
      await repo.markRead(notificationId);
      ref.invalidate(myNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    });

final markAllNotificationsReadProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.markAllRead();
  ref.invalidate(myNotificationsProvider);
  ref.invalidate(unreadNotificationsCountProvider);
});

final triggerTestReminderProvider = FutureProvider.autoDispose
    .family<void, Booking?>((ref, booking) async {
      final service = ref.watch(pushNotificationServiceProvider);
      await service.trigger1HourReminderNow(booking);
      ref.invalidate(myNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    });

final simulateCloudPushProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.watch(pushNotificationServiceProvider);
  await service.simulateCloudPush();
  ref.invalidate(myNotificationsProvider);
  ref.invalidate(unreadNotificationsCountProvider);
});
