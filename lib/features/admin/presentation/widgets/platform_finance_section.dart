import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../admin_settings_providers.dart';

const _financeKey = 'platform_finance';

/// Commission percent currently configured (0 when unset).
final platformCommissionPercentProvider = FutureProvider<double>((ref) async {
  final row = await ref
      .watch(supabaseProvider)
      .from('module_feature_configs')
      .select('metadata')
      .eq('module_key', _financeKey)
      .isFilter('venue_id', null)
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();
  final metadata = row?['metadata'];
  if (metadata is! Map) return 0;
  return double.tryParse('${metadata['commission_percent'] ?? 0}') ?? 0;
});

typedef CommissionSummary = ({
  int bookings,
  double gross,
  double commission,
  double reversed,
});

/// Last 30 days, confirmed bookings only (server: admin_commission_summary).
final commissionSummaryProvider =
    FutureProvider.autoDispose<CommissionSummary>((ref) async {
  final raw = await ref
      .watch(supabaseProvider)
      .rpc<dynamic>('admin_commission_summary');
  final row = raw is List && raw.isNotEmpty ? raw.first : raw;
  double n(Object? v) => double.tryParse('${v ?? 0}') ?? 0;
  if (row is! Map) {
    return (bookings: 0, gross: 0.0, commission: 0.0, reversed: 0.0);
  }
  return (
    bookings: n(row['bookings']).toInt(),
    gross: n(row['gross']),
    commission: n(row['commission']),
    reversed: n(row['reversed']),
  );
});

/// Admin settings card: platform commission percent + 30-day summary.
class PlatformFinanceSection extends ConsumerStatefulWidget {
  const PlatformFinanceSection({super.key});

  @override
  ConsumerState<PlatformFinanceSection> createState() =>
      _PlatformFinanceSectionState();
}

class _PlatformFinanceSectionState
    extends ConsumerState<PlatformFinanceSection> {
  final _percent = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_percent.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (value == null || value < 0 || value > 100) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a percent between 0 and 100')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(adminSettingsRepositoryProvider)
          .saveSection(_financeKey, {'commission_percent': value});
      ref.invalidate(platformCommissionPercentProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Commission saved. Applies to bookings confirmed from now.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = ref.watch(platformCommissionPercentProvider).valueOrNull;
    if (percent != null && !_seeded) {
      _seeded = true;
      _percent.text = percent == percent.roundToDouble()
          ? percent.toStringAsFixed(0)
          : percent.toString();
    }
    final summary = ref.watch(commissionSummaryProvider);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform commission', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Recorded on every confirmed booking at the rate in force at '
              'confirmation; reversed if the booking is cancelled or refunded.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('admin-commission-percent'),
                    controller: _percent,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Commission %',
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            summary.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'Summary unavailable',
                style: theme.textTheme.bodySmall,
              ),
              data: (s) => Text(
                'Last 30 days: ${s.bookings} bookings · '
                'gross ${formatInr(s.gross)} · '
                'commission ${formatInr(s.commission)}'
                '${s.reversed > 0 ? ' · reversed ${formatInr(s.reversed)}' : ''}',
                key: const Key('admin-commission-summary'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
