import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final owners = ref.watch(adminOwnersProvider);
    final venues = ref.watch(adminVenuesProvider);
    final tickets = ref.watch(adminSupportTicketsProvider);
    final audit = ref.watch(recentAuditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin console')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminUsersProvider);
          ref.invalidate(adminOwnersProvider);
          ref.invalidate(adminVenuesProvider);
          ref.invalidate(adminSupportTicketsProvider);
          ref.invalidate(recentAuditLogsProvider);
          ref.invalidate(adminPublishedEventsProvider);
          ref.invalidate(adminPublishedCoursesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Platform administration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Counts come from rows your administrator role can read. They are not estimates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  label: 'Users',
                  value: _countLabel(users),
                ),
                _StatChip(
                  label: 'Owners',
                  value: _countLabel(owners),
                ),
                _StatChip(
                  label: 'Venues',
                  value: _countLabel(venues),
                ),
                _StatChip(
                  label: 'Support',
                  value: _countLabel(tickets),
                ),
                _StatChip(
                  label: 'Audit',
                  value: _countLabel(audit),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AdminLink(
              icon: Icons.people_alt_outlined,
              title: 'Users',
              subtitle: 'Profiles and roles visible to administrators',
              onTap: () => context.push(AppRoutes.adminUsers),
            ),
            _AdminLink(
              icon: Icons.storefront_outlined,
              title: 'Owners',
              subtitle: 'Organizations and verification status',
              onTap: () => context.push(AppRoutes.adminOwners),
            ),
            _AdminLink(
              icon: Icons.apartment_outlined,
              title: 'Venues',
              subtitle: 'Active listings readable under current RLS',
              onTap: () => context.push(AppRoutes.adminVenues),
            ),
            _AdminLink(
              icon: Icons.receipt_long_outlined,
              title: 'Bookings',
              subtitle: 'Platform-wide booking list is not granted by RLS',
              onTap: () => context.push(AppRoutes.adminBookings),
            ),
            _AdminLink(
              icon: Icons.payments_outlined,
              title: 'Payments',
              subtitle: 'Platform-wide payment list is not granted by RLS',
              onTap: () => context.push(AppRoutes.adminPayments),
            ),
            _AdminLink(
              icon: Icons.event_outlined,
              title: 'Events',
              subtitle: 'Published events',
              onTap: () => context.push(AppRoutes.adminEvents),
            ),
            _AdminLink(
              icon: Icons.school_outlined,
              title: 'Courses',
              subtitle: 'Published courses',
              onTap: () => context.push(AppRoutes.adminCourses),
            ),
            _AdminLink(
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              subtitle: 'Recorded analytics events',
              onTap: () => context.push(AppRoutes.analytics),
            ),
            _AdminLink(
              icon: Icons.headset_mic_outlined,
              title: 'Support',
              subtitle: 'Support tickets your role can read',
              onTap: () => context.push(AppRoutes.adminSupport),
            ),
            _AdminLink(
              icon: Icons.history_rounded,
              title: 'Audit log',
              subtitle: 'Administrative actions',
              onTap: () => context.push(AppRoutes.adminAudit),
            ),
            _AdminLink(
              icon: Icons.view_carousel_outlined,
              title: 'Home banners',
              subtitle: 'CMS titles and subtitles shown on customer Home',
              onTap: () => context.push(AppRoutes.adminCms),
            ),
            users.maybeWhen(
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(adminUsersProvider),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  static String _countLabel(AsyncValue<List<dynamic>> value) {
    return value.when(
      data: (items) => '${items.length}',
      loading: () => '…',
      error: (_, __) => '—',
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.brand),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
