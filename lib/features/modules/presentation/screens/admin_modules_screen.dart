import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../domain/feature_flag.dart';
import '../../domain/feature_flag_bulk.dart';
import '../module_manifests.dart';
import '../module_providers.dart';

class AdminModulesScreen extends ConsumerStatefulWidget {
  const AdminModulesScreen({super.key});

  static Key presetKey(FeaturePreset preset) =>
      Key('modules-preset-${preset.name}');
  static const enableAllKey = Key('modules-enable-all');
  static const disableNonCoreKey = Key('modules-disable-non-core');
  static const resetDefaultsKey = Key('modules-reset-defaults');
  static const exportKey = Key('modules-export-json');
  static const importKey = Key('modules-import-json');
  static const importFieldKey = Key('modules-import-field');
  static const importValidateKey = Key('modules-import-validate');
  static const applyChangesKey = Key('modules-apply-changes');

  @override
  ConsumerState<AdminModulesScreen> createState() => _AdminModulesScreenState();
}

class _AdminModulesScreenState extends ConsumerState<AdminModulesScreen> {
  final Set<String> _saving = <String>{};
  bool _bulkSaving = false;

  /// Effective state of every configurable module: backend row, else the
  /// manifest default.
  Map<String, FeatureFlag> _effective(Map<String, FeatureFlag> items) => {
    for (final m in optionalModuleManifests) m.id: items[m.id] ?? m.fallback(),
  };

  Map<String, FeatureFlag> get _defaults => {
    for (final m in optionalModuleManifests) m.id: m.fallback(),
  };

  Future<bool> _confirmChanges(
    String title,
    List<FlagChange> changes, {
    String? note,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: _ChangePreview(changes: changes, note: note),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: AdminModulesScreen.applyChangesKey,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Apply ${changes.length}'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Confirms then writes [changes] one flag at a time via `saveFlag`.
  Future<void> _applyBulk(
    String title,
    List<FlagChange> changes, {
    bool alreadyConfirmed = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (changes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to change — already applied.')),
      );
      return;
    }
    if (!alreadyConfirmed && !await _confirmChanges(title, changes)) return;
    if (!mounted) return;
    setState(() => _bulkSaving = true);
    final repo = ref.read(featureFlagRepositoryProvider);
    final failed = <String>[];
    for (final change in changes) {
      try {
        await repo.saveFlag(
          key: change.after.key,
          enabled: change.after.enabled,
          platforms: change.after.platforms,
          config: change.after.config,
        );
      } catch (_) {
        failed.add(change.key);
      }
    }
    ref.invalidate(featureFlagsProvider);
    if (mounted) setState(() => _bulkSaving = false);
    final saved = changes.length - failed.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? '$title: $saved module${saved == 1 ? '' : 's'} updated'
              : '$title: $saved updated, not saved: ${failed.join(', ')}',
        ),
      ),
    );
  }

  Future<void> _export(Map<String, FeatureFlag> effective) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: exportFlagsJson(effective, now: DateTime.now())),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${effective.length} module flags to the clipboard as JSON',
        ),
      ),
    );
  }

  Future<void> _import(Map<String, FeatureFlag> effective) async {
    final changes = await showDialog<List<FlagChange>>(
      context: context,
      builder: (_) => _ImportFlagsDialog(current: effective),
    );
    if (changes == null || !mounted) return;
    await _applyBulk('Import', changes, alreadyConfirmed: true);
  }

  Future<void> _save(
    ModuleManifest manifest,
    FeatureFlag flag, {
    bool? enabled,
    Map<String, dynamic>? config,
  }) async {
    if (!_saving.add(manifest.id)) return;
    setState(() {});
    try {
      await ref
          .read(featureFlagRepositoryProvider)
          .saveFlag(
            key: manifest.id,
            enabled: enabled ?? flag.enabled,
            platforms: flag.platforms,
            config: config ?? flag.config,
          );
      ref.invalidate(featureFlagsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Module was not saved: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving.remove(manifest.id));
      } else {
        _saving.remove(manifest.id);
      }
    }
  }

  Future<void> _editConfig(ModuleManifest manifest, FeatureFlag flag) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(flag.config),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${manifest.name} configuration'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Validated JSON configuration',
              helperText: 'Use settings supported by this module manifest.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save configuration'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map)
        throw const FormatException('configuration must be an object');
      final config = decoded.map<String, dynamic>(
        (key, item) => MapEntry(key.toString(), item),
      );
      await _save(manifest, flag, config: config);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid configuration: ${error.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optional modules'),
        actions: [
          IconButton(
            tooltip: 'Refresh module configuration',
            onPressed: () => ref.invalidate(featureFlagsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: flags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(featureFlagsProvider),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: optionalModuleManifests.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, rawIndex) {
            if (rawIndex == 0) {
              final effective = _effective(items);
              return _BulkActionsCard(
                busy: _bulkSaving,
                onPreset: (preset) => _applyBulk(
                  'Apply "${preset.label}"',
                  planPreset(effective, preset),
                ),
                onEnableAll: () =>
                    _applyBulk('Enable all', planEnableAll(effective)),
                onDisableNonCore: () => _applyBulk(
                  'Disable non-core',
                  planDisableNonCore(effective),
                ),
                onResetDefaults: () => _applyBulk(
                  'Reset to defaults',
                  planResetToDefaults(effective, _defaults),
                ),
                onExport: () => _export(effective),
                onImport: () => _import(effective),
              );
            }
            final index = rawIndex - 1;
            final manifest = optionalModuleManifests[index];
            final flag = items[manifest.id] ?? manifest.fallback();
            final saving = _saving.contains(manifest.id);
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            manifest.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (saving)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch.adaptive(
                            value: flag.enabled,
                            onChanged: (value) =>
                                _save(manifest, flag, enabled: value),
                          ),
                      ],
                    ),
                    Text(
                      manifest.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Platforms: ${flag.platforms.join(', ')}\nConfig: ${jsonEncode(flag.config)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => _editConfig(manifest, flag),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Configure'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BulkActionsCard extends StatelessWidget {
  const _BulkActionsCard({
    required this.busy,
    required this.onPreset,
    required this.onEnableAll,
    required this.onDisableNonCore,
    required this.onResetDefaults,
    required this.onExport,
    required this.onImport,
  });

  final bool busy;
  final ValueChanged<FeaturePreset> onPreset;
  final VoidCallback onEnableAll;
  final VoidCallback onDisableNonCore;
  final VoidCallback onResetDefaults;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Presets & bulk actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Every change is previewed before it is saved. Layout documents '
              '(Home, navigation, catalogue) are never toggled in bulk.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in FeaturePreset.values)
                  Tooltip(
                    message: preset.description,
                    child: ActionChip(
                      key: AdminModulesScreen.presetKey(preset),
                      avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(preset.label),
                      onPressed: busy ? null : () => onPreset(preset),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: AdminModulesScreen.enableAllKey,
                  onPressed: busy ? null : onEnableAll,
                  icon: const Icon(Icons.toggle_on_outlined, size: 18),
                  label: const Text('Enable all'),
                ),
                OutlinedButton.icon(
                  key: AdminModulesScreen.disableNonCoreKey,
                  onPressed: busy ? null : onDisableNonCore,
                  icon: const Icon(Icons.toggle_off_outlined, size: 18),
                  label: const Text('Disable non-core'),
                ),
                OutlinedButton.icon(
                  key: AdminModulesScreen.resetDefaultsKey,
                  onPressed: busy ? null : onResetDefaults,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset to defaults'),
                ),
                TextButton.icon(
                  key: AdminModulesScreen.exportKey,
                  onPressed: busy ? null : onExport,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Export JSON'),
                ),
                TextButton.icon(
                  key: AdminModulesScreen.importKey,
                  onPressed: busy ? null : onImport,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePreview extends StatelessWidget {
  const _ChangePreview({required this.changes, this.note});

  final List<FlagChange> changes;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note ??
              '${changes.length} module${changes.length == 1 ? '' : 's'} '
                  'will be updated:',
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          moduleManifestFor(change.key)?.name ?? change.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          change.summary,
                          textAlign: TextAlign.end,
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

/// Paste → validate → preview diff. Pops with the changes to apply.
class _ImportFlagsDialog extends StatefulWidget {
  const _ImportFlagsDialog({required this.current});

  final Map<String, FeatureFlag> current;

  @override
  State<_ImportFlagsDialog> createState() => _ImportFlagsDialogState();
}

class _ImportFlagsDialogState extends State<_ImportFlagsDialog> {
  final _controller = TextEditingController();
  FlagImportResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    setState(
      () => _result = parseFlagsImport(_controller.text, widget.current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final preview = result != null && result.isValid;
    return AlertDialog(
      title: Text(preview ? 'Review import' : 'Import module flags'),
      content: SizedBox(
        width: 480,
        child: preview
            ? (result.changes.isEmpty
                  ? const Text('The JSON matches the current configuration.')
                  : _ChangePreview(changes: result.changes))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: AdminModulesScreen.importFieldKey,
                    controller: _controller,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Paste exported JSON',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_result != null) setState(() => _result = null);
                    },
                  ),
                  if (result != null && !result.isValid) ...[
                    const SizedBox(height: 8),
                    for (final error in result.errors.take(6))
                      Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (preview && result.changes.isNotEmpty)
          FilledButton(
            key: AdminModulesScreen.applyChangesKey,
            onPressed: () => Navigator.pop(context, result.changes),
            child: Text('Apply ${result.changes.length}'),
          )
        else if (!preview)
          FilledButton(
            key: AdminModulesScreen.importValidateKey,
            onPressed: _validate,
            child: const Text('Validate'),
          ),
      ],
    );
  }
}
