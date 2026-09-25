import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/owner.dart';
import '../owner_providers.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(currentOwnerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ownerDashboard)),
      body: owner.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentOwnerProvider),
        ),
        data: (ownerData) => ownerData == null
            ? const EmptyState(
                icon: Icons.person_add_rounded,
                title: 'Not an owner',
                message: 'Register as an owner to access the dashboard.',
              )
            : _OwnerDashboardBody(owner: ownerData, l10n: l10n),
      ),
    );
  }
}

class _OwnerDashboardBody extends ConsumerWidget {
  const _OwnerDashboardBody({required this.owner, required this.l10n});

  final Owner owner;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ownerDashboardSnapshotProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OwnerCard(owner: owner),
        const SizedBox(height: 16),
        snapshot.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(ownerDashboardSnapshotProvider),
          ),
          data: (data) => Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Venues',
                  value: '${data.venueCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Bookings',
                  value: '${data.bookingCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Pending',
                  value: '${data.pendingCount}',
                ),
              ),
            ],
          ),
        ),
        snapshot.maybeWhen(
          data: (data) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _MetricTile(
              label: 'Confirmed booking total',
              value: '₹${data.confirmedRevenue.toStringAsFixed(0)}',
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        _ReportsCard(),
        const SizedBox(height: 24),
        _QuickAction(
          icon: Icons.add_business_rounded,
          label: 'List New Space 🏛️',
          onTap: () => context.push(AppRoutes.ownerVenueCreate),
        ),
        _QuickAction(
          icon: Icons.dashboard_customize_rounded,
          label: 'Manage Venue Sections 🏷️',
          // Was AppRoutes.ownerCategories: that route rendered the ADMIN-only
          // global category editor, letting any owner mutate every venue's
          // shared category taxonomy. Owners now manage their own venue's
          // plug-and-play sections from the venue list instead.
          onTap: () => context.push(AppRoutes.ownerVenues),
        ),
        _QuickAction(
          icon: Icons.storefront_rounded,
          label: l10n.myVenues,
          onTap: () => context.push(AppRoutes.ownerVenues),
        ),
        _QuickAction(
          icon: Icons.receipt_long_rounded,
          label: 'Venue bookings',
          onTap: () => context.push(AppRoutes.ownerBookings),
        ),
        _QuickAction(
          icon: Icons.notifications_rounded,
          label: l10n.notifications,
          onTap: () => context.push(AppRoutes.notifications),
        ),
        _QuickAction(
          icon: Icons.analytics_rounded,
          label: l10n.analyticsLabel,
          onTap: () => context.push(AppRoutes.analytics),
        ),
        _QuickAction(
          icon: Icons.headset_mic_rounded,
          label: l10n.support,
          onTap: () => context.push(AppRoutes.support),
        ),
        _QuickAction(
          icon: Icons.school_rounded,
          label: 'Institute dashboard',
          onTap: () => context.push(AppRoutes.ownerInstituteDashboard),
        ),
        _QuickAction(
          icon: Icons.menu_book_rounded,
          label: 'My courses',
          onTap: () => context.push(AppRoutes.ownerCourses),
        ),
      ],
    );
  }
}

/// Daily/weekly report card backed by real bookings from `public.bookings`
/// (RLS-scoped to the owner's venues) via [ownerReportSummaryProvider].
class _ReportsCard extends ConsumerWidget {
  const _ReportsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(ownerReportSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize_rounded,
                    size: 20, color: AppTheme.violet),
                const SizedBox(width: 8),
                Text('Reports', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            summary.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Could not load reports: $error',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              data: (data) => LayoutBuilder(builder: (context, constraints) {
                // Two metrics per row on phones, four across on wide
                // tablets/web windows.
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                const gap = 8.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _MetricTile(
                          label: 'Today bookings',
                          value: '${data.todayBookings}'),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricTile(
                          label: 'Today revenue',
                          value: '₹${data.todayRevenue.toStringAsFixed(0)}'),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricTile(
                          label: 'This week bookings',
                          value: '${data.weekBookings}'),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricTile(
                          label: 'This week revenue',
                          value: '₹${data.weekRevenue.toStringAsFixed(0)}'),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner});

  final Owner owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded, color: AppTheme.violet),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    owner.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppTheme.violet),
              const SizedBox(width: 16),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
