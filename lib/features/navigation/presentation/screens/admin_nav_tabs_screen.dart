import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/nav_tabs.dart';
import '../nav_tab_labels.dart';
import '../nav_tabs_providers.dart';

/// Admin editor for the customer bottom navigation bar.
///
/// Admins choose which destinations customers see, in what order, and under
/// what label. Hiding a destination never deletes its route: deep links, the
/// assistant and in-app buttons still reach every screen, so a lean bar never
/// strands a customer mid-flow.
///
/// Writes go through the plug-and-play flag repository, so a publish reaches
/// iOS, Android and web without a new build.
class AdminNavTabsScreen extends ConsumerStatefulWidget {
  const AdminNavTabsScreen({super.key});

  @override
  ConsumerState<AdminNavTabsScreen> createState() => _AdminNavTabsScreenState();
}

class _AdminNavTabsScreenState extends ConsumerState<AdminNavTabsScreen> {
  NavTabsConfig? _draft;
  bool _saving = false;

  NavTabsConfig _current(NavTabsConfig source) => _draft ?? source;

  void _update(NavTabConfig updated) {
    final NavTabsConfig base = _draft ?? ref.read(navTabsProvider);
    setState(() => _draft = base.copyWithTab(updated));
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(navTabsControllerProvider).save(draft);
      if (!mounted) return;
      setState(() => _draft = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottom navigation published')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reorder(List<NavTabConfig> ordered, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return;
    final a = ordered[index];
    final b = ordered[target];
    _update(a.copyWith(order: b.order));
    _update(b.copyWith(order: a.order));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = _current(ref.watch(navTabsProvider));
    final ordered = config.ordered;
    final visibleCount = config.visible.length;
    final canPublish = !_saving && _draft != null && visibleCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bottom navigation'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _draft = NavTabsConfig.defaults),
            child: const Text('Reset'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: canPublish ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Choose which destinations appear in the customer bottom bar, in '
            'what order, and under what label. Hiding a destination never '
            'removes its screen — deep links and in-app buttons still reach it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (visibleCount == 0)
            _Notice(
              icon: Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              text: 'Enable at least one destination before publishing.',
            )
          else if (visibleCount < 2)
            _Notice(
              icon: Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              text: 'A single destination leaves customers no way to switch '
                  'screens.',
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < ordered.length; i++)
            _TabEditor(
              key: ValueKey(ordered[i].tab),
              entry: ordered[i],
              preview: navTabLabel(ordered[i], l10n),
              isFirst: i == 0,
              isLast: i == ordered.length - 1,
              onChanged: _update,
              onMove: (delta) => _reorder(ordered, i, delta),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _TabEditor extends StatelessWidget {
  const _TabEditor({
    super.key,
    required this.entry,
    required this.preview,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
    required this.onMove,
  });

  final NavTabConfig entry;

  /// What the customer will actually read, so the editor cannot mislead.
  final String preview;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<NavTabConfig> onChanged;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(entry.tab.selectedIcon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: isFirst ? null : () => onMove(-1),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: isLast ? null : () => onMove(1),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                Switch(
                  value: entry.enabled,
                  onChanged: (value) =>
                      onChanged(entry.copyWith(enabled: value)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: entry.label,
              decoration: const InputDecoration(
                labelText: 'Label override (optional)',
                helperText: 'Empty keeps the name translated in every language',
                isDense: true,
              ),
              onChanged: (value) => onChanged(entry.copyWith(label: value)),
            ),
          ],
        ),
      ),
    );
  }
}
