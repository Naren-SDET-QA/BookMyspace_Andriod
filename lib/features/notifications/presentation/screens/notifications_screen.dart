import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/notification.dart' as notification_domain;
import '../../domain/push_notification_types.dart';
import '../notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
    final pushService = ref.watch(pushNotificationServiceProvider);
    final is1HourEnabled = ref.watch(is1HourReminderEnabledProvider);
    final permissionAsync = ref.watch(pushPermissionStatusProvider);

    final platformName = kIsWeb
        ? 'Web Push'
        : (!kIsWeb && Platform.isIOS)
            ? 'APNs (iOS)'
            : 'Push';

    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(markAllNotificationsReadProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 80, radius: 14),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (items) {
          final filteredItems = _selectedFilter == 'all'
              ? items
              : _selectedFilter == 'unread'
                  ? items.where((n) => !n.read).toList()
                  : items.where((n) => n.type == _selectedFilter).toList();

          return CustomScrollView(
            slivers: [
              // 1. Push Reminders & System Permission Card (matching Android)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _PushControlCard(
                    platformName: platformName,
                    is1HourEnabled: is1HourEnabled,
                    permissionStatus: permissionAsync.valueOrNull ?? pushService.permissionStatus,
                    deviceToken: pushService.currentDeviceToken,
                    onToggle1Hour: (val) async {
                      ref.read(is1HourReminderEnabledProvider.notifier).state = val;
                      await pushService.set1HourReminderEnabled(val);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? '1-Hour Pre-Booking Reminders Enabled ⏰'
                                  : '1-Hour Reminders Paused',
                            ),
                          ),
                        );
                      }
                    },
                    onRequestPermission: () async {
                      final status = await pushService.requestPermission();
                      ref.invalidate(pushPermissionStatusProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              status.isGranted
                                  ? 'Push notifications enabled successfully! 🔔'
                                  : 'Push permission not granted (${status.name})',
                            ),
                          ),
                        );
                      }
                    },
                    onTest1HourPush: () async {
                      await pushService.trigger1HourReminderNow(null);
                      ref.invalidate(myNotificationsProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Heads-Up Push Notification Sent! 🔔')),
                        );
                      }
                    },
                    onSimulateCloudPush: () async {
                      await pushService.simulateCloudPush();
                      ref.invalidate(myNotificationsProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cloud Push Payload Received & Broadcasted! ☁️'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

              // 2. Filter tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${items.length})',
                          selected: _selectedFilter == 'all',
                          onTap: () => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Unread ($unreadCount)',
                          selected: _selectedFilter == 'unread',
                          onTap: () => setState(() => _selectedFilter = 'unread'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '⚡ 1-Hour Reminders',
                          selected: _selectedFilter == '1_hour_reminder',
                          onTap: () => setState(() => _selectedFilter = '1_hour_reminder'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: '🎟️ Bookings',
                          selected: _selectedFilter == 'booking',
                          onTap: () => setState(() => _selectedFilter = 'booking'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Notifications List
              if (filteredItems.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    message: 'You will see notifications here when they arrive.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _NotificationTile(
                        notification: filteredItems[i],
                        onTap: () async {
                          await ref.read(
                            markNotificationReadProvider(filteredItems[i].id).future,
                          );
                          if (context.mounted) {
                            final data = filteredItems[i].data;
                            if (data != null) {
                              pushService.handleNotificationRouting(data);
                            } else if (filteredItems[i].type == '1_hour_reminder' ||
                                filteredItems[i].type == 'booking') {
                              context.go(AppRoutes.bookings);
                            }
                          }
                        },
                      ),
                      childCount: filteredItems.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PushControlCard extends StatelessWidget {
  const _PushControlCard({
    required this.platformName,
    required this.is1HourEnabled,
    required this.permissionStatus,
    required this.deviceToken,
    required this.onToggle1Hour,
    required this.onRequestPermission,
    required this.onTest1HourPush,
    required this.onSimulateCloudPush,
  });

  final String platformName;
  final bool is1HourEnabled;
  final PushPermissionStatus permissionStatus;
  final String? deviceToken;
  final ValueChanged<bool> onToggle1Hour;
  final VoidCallback onRequestPermission;
  final VoidCallback onTest1HourPush;
  final VoidCallback onSimulateCloudPush;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasToken = deviceToken != null && deviceToken!.isNotEmpty;
    final displayToken = hasToken
        ? (deviceToken!.length > 20
            ? '${deviceToken!.substring(0, 20)}...'
            : deviceToken!)
        : 'token_bms_${platformName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_live';

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.brand,
                  child: const Text('⏰', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$platformName 1-Hour Push Reminders',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Automated pre-slot triggers active',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: is1HourEnabled,
                  onChanged: onToggle1Hour,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Automated high-priority push notifications trigger exactly 1 hour before booked slots start, delivering turn-by-turn venue access and instant QR entry passes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Token preview container with Copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Token: $displayToken',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: deviceToken ?? displayToken));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$platformName Token Copied! 📋')),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Copy Token',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!permissionStatus.isGranted) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRequestPermission,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Enable System Push Notifications'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onTest1HourPush,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('⚡ Test 1-Hr Push', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSimulateCloudPush,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('☁️ Simulate Cloud', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final notification_domain.Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.read;

    final typeIcon = switch (notification.type) {
      '1_hour_reminder' => '⚡',
      'booking' => '🎟️',
      'course_alert' || 'alert_registered' => '🎉',
      'auth' => '🔑',
      _ => '🔔',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isUnread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUnread
              ? AppTheme.brand.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnread
                      ? AppTheme.brand.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.Center,
                child: Text(typeIcon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.brand,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    if (notification.type == '1_hour_reminder' || notification.type == 'booking') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 14, color: AppTheme.brand),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view check-in pass',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
