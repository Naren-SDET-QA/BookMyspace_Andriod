import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../owner_bookings/presentation/owner_booking_providers.dart';
import '../../domain/venue_optimizer.dart';
import '../venue_optimizer_providers.dart';

const _low = Color(0xFF10B981);
const _moderate = Color(0xFFF59E0B);
const _high = Color(0xFFEF4444);

Color _bandColor(DemandBand band) => switch (band) {
  DemandBand.low => _low,
  DemandBand.moderate => _moderate,
  DemandBand.high => _high,
};

/// Owner Insights "Venue Optimizer": occupancy, unsold slot value, a
/// time-of-day demand heatmap, read-only pricing rules and recommendations,
/// all computed from the owner's real slots, blocked dates and bookings.
///
/// Uses the shared [ResponsiveInfo] breakpoints: one column for compact
/// and medium widths (phones, portrait tablets), two columns for expanded
/// and extra-wide (landscape tablets, desktop), matching the booking
/// screen.
class VenueOptimizerSection extends ConsumerWidget {
  const VenueOptimizerSection({
    super.key,
    required this.start,
    required this.end,
    this.venueId,
  });

  final DateTime start;
  final DateTime end;
  final String? venueId;

  /// True when the section lays out in two columns at [width].
  static bool isTwoColumn(double width) {
    final info = ResponsiveInfo.fromConstraints(
      BoxConstraints(maxWidth: width),
    );
    return info.isExpanded || info.isExtraWide;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(ownerCapacityProvider);
    final bookings = ref.watch(ownerBookingsProvider);

    Widget error(Object e) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ErrorView(
        message: e.toString(),
        onRetry: () {
          ref.invalidate(ownerCapacityProvider);
          ref.invalidate(ownerBookingsProvider);
        },
      ),
    );

    if (capacity.hasError) return error(capacity.error!);
    if (bookings.hasError) return error(bookings.error!);
    if (!capacity.hasValue || !bookings.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final report = VenueOptimizerReport.build(
      venues: capacity.value!,
      bookings: bookings.value!,
      start: start,
      end: end,
      venueId: venueId,
    );

    return Column(
      key: const Key('venue_optimizer_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(report: report),
        if (!report.hasInventory)
          const _InfoCard(
            key: Key('optimizer_no_inventory'),
            icon: Icons.event_busy_outlined,
            text:
                'No open slots in this range. Add time slots to your venues '
                '(or pick a range without blocked dates) to see occupancy.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final heatmap = _HeatmapCard(report: report);
              final side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PricingCard(),
                  _RecommendationsCard(report: report),
                ],
              );
              if (isTwoColumn(constraints.maxWidth)) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heatmap),
                    const SizedBox(width: 12),
                    Expanded(child: side),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [heatmap, side],
              );
            },
          ),
      ],
    );
  }
}

String _inr(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(v);

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.report});
  final VenueOptimizerReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kpis = [
      _Kpi(
        key: const Key('optimizer_occupancy'),
        label: 'OCCUPANCY',
        value: report.hasInventory
            ? '${report.occupancyPercent.toStringAsFixed(1)}%'
            : '—',
        caption: '${report.occupied} of ${report.capacity} slots',
      ),
      _Kpi(
        key: const Key('optimizer_unsold'),
        label: 'UNSOLD SLOT VALUE',
        value: _inr(report.unsoldValue),
        caption: 'at base price',
        valueColor: scheme.primary,
      ),
      _Kpi(
        key: const Key('optimizer_recommendations'),
        label: 'RECOMMENDATIONS',
        value: '${report.recommendations.length}',
        caption: report.recommendations.isEmpty ? 'none right now' : 'active',
      ),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The tag wraps under the title on narrow screens or
                      // with large text instead of overflowing.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Venue Yield Optimizer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LIVE DATA',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real occupancy from your slots and bookings · '
                        '${report.days} day${report.days == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                // Three across from ~340px; stacked on the narrowest phones
                // or with very large text.
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final across = c.maxWidth / scale >= 340;
                if (!across) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final k in kpis)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: k,
                        ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < kpis.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: kpis[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor,
  });

  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ),
        Text(
          caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.report});
  final VenueOptimizerReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      key: const Key('optimizer_heatmap'),
      title: 'Slot Demand Heatmap',
      subtitle: 'Share of slots booked in each time window',
      children: [
        for (final w in report.windows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${w.spec.name} (${w.spec.range})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${w.fillPercent.round()}% fill',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _bandColor(w.band),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  label:
                      '${w.spec.name} ${w.fillPercent.round()} percent booked',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: w.fillPercent / 100,
                      minHeight: 8,
                      color: _bandColor(w.band),
                      backgroundColor: _bandColor(
                        w.band,
                      ).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${w.hint} · ${w.occupied}/${w.capacity} slots',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PricingCard extends ConsumerWidget {
  const _PricingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(ownerPricingRulesProvider);
    final active = rules.valueOrNull
        ?.where((r) => r.isAdjustment)
        .toList(growable: false);
    return _SectionCard(
      key: const Key('optimizer_pricing'),
      title: 'Dynamic Pricing',
      subtitle: 'Peak / off-peak and weekend price rules',
      children: [
        Container(
          key: const Key('optimizer_pricing_notice'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Automatic peak / off-peak pricing is not active yet, so '
                  'bookings are charged each slot\'s base price. Rules are '
                  'shown here for reference only.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        rules.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text(
            'Pricing rules could not be loaded.',
            style: theme.textTheme.bodySmall,
          ),
          data: (_) => active!.isEmpty
              ? Text(
                  'No price adjustments are set for your venues.',
                  key: const Key('optimizer_no_rules'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sell_outlined, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                r.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  const _RecommendationsCard({required this.report});
  final VenueOptimizerReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      key: const Key('optimizer_recommendations_card'),
      title: 'Recommendations',
      subtitle: 'Based on the demand heatmap above',
      children: [
        if (report.recommendations.isEmpty)
          Text(
            report.occupied == 0
                ? 'No bookings in this range yet. Recommendations appear as '
                      'slots get booked.'
                : 'Demand is balanced across your time windows.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final r in report.recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(r.detail, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

