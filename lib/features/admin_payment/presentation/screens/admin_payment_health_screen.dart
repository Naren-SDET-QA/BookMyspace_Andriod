import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/payment_health.dart';
import '../providers/admin_payment_providers.dart';
import '../widgets/payment_health_metric_card.dart';

/// Read-only Admin dashboard summarizing real payment operational health
/// (Payment Health). This screen contains no controls that mutate
/// payments, bookings, or webhook state — it is strictly observability.
class AdminPaymentHealthScreen extends ConsumerWidget {
  const AdminPaymentHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final healthAsync = ref.watch(paymentHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPaymentHealth),
        actions: [
          IconButton(
            tooltip: l10n.adminTransactionLedger,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(AppRoutes.adminPaymentsLedger),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(paymentHealthProvider.future),
        child: healthAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(paymentHealthProvider),
          ),
          data: (health) => _PaymentHealthBody(health: health),
        ),
      ),
    );
  }
}

class _PaymentHealthBody extends StatelessWidget {
  const _PaymentHealthBody({required this.health});

  final PaymentHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (health.totalTransactions == 0) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.query_stats_outlined,
            title: l10n.noTransactionsInPeriod,
            message: l10n.noTransactionsInPeriodMessage,
          ),
        ],
      );
    }

    return ResponsiveLayoutBuilder(
      builder: (context, responsive) {
        final columns = responsive.isCompact
            ? 2
            : responsive.isMedium
                ? 3
                : 4;
        return ListView(
          padding: EdgeInsets.all(responsive.horizontalPadding),
          children: [
            _StatusBanner(status: health.status),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                PaymentHealthMetricCard(
                  label: l10n.totalTransactions,
                  value: '${health.totalTransactions}',
                  icon: Icons.receipt_long_outlined,
                  emphasis: true,
                ),
                PaymentHealthMetricCard(
                  label: l10n.capturedPayments,
                  value: '${health.capturedCount}',
                  icon: Icons.check_circle_outline,
                ),
                PaymentHealthMetricCard(
                  label: l10n.pendingPayments,
                  value: '${health.pendingCount}',
                  icon: Icons.hourglass_empty_outlined,
                ),
                PaymentHealthMetricCard(
                  label: l10n.failedPayments,
                  value: '${health.failedCount}',
                  icon: Icons.error_outline,
                ),
                PaymentHealthMetricCard(
                  label: l10n.refundedPayments,
                  value: '${health.refundedCount}',
                  icon: Icons.replay_outlined,
                ),
                PaymentHealthMetricCard(
                  label: l10n.paymentSuccessRate,
                  value: health.successRate != null
                      ? '${health.successRate!.toStringAsFixed(1)}%'
                      : l10n.paymentHealthUnavailable,
                  icon: Icons.trending_up_outlined,
                ),
                PaymentHealthMetricCard(
                  label: l10n.reconciliationExceptions,
                  value: '${health.reconciliationExceptions}',
                  icon: Icons.warning_amber_outlined,
                ),
                PaymentHealthMetricCard(
                  label: l10n.webhookMissing,
                  value: '${health.webhookMissingCount}',
                  icon: Icons.webhook_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(l10n.readOnlyLabel),
                avatar: const Icon(Icons.lock_outline, size: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final PaymentHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color background, Color foreground, IconData icon) =
        switch (status) {
      PaymentHealthStatus.healthy => (
          l10n.paymentHealthHealthy,
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.check_circle_outline,
        ),
      PaymentHealthStatus.warning => (
          l10n.paymentHealthWarning,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.warning_amber_outlined,
        ),
      PaymentHealthStatus.attention => (
          l10n.paymentHealthAttention,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.priority_high_outlined,
        ),
      PaymentHealthStatus.critical => (
          l10n.paymentHealthCritical,
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.report_gmailerrorred_outlined,
        ),
      PaymentHealthStatus.unavailable => (
          l10n.paymentHealthUnavailable,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.help_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
