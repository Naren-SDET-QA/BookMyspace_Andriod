import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../domain/feature_flag.dart';
import '../module_manifests.dart';
import '../module_providers.dart';

class AdminModulesScreen extends ConsumerStatefulWidget {
  const AdminModulesScreen({super.key});

  @override
  ConsumerState<AdminModulesScreen> createState() => _AdminModulesScreenState();
}

class _AdminModulesScreenState extends ConsumerState<AdminModulesScreen> {
  final Set<String> _saving = <String>{};

  Future<void> _save(
    ModuleManifest manifest,
    FeatureFlag flag, {
    bool? enabled,
    Map<String, dynamic>? config,
  }) async {
    if (!_saving.add(manifest.id)) return;
    setState(() {});
    try {
      await ref.read(featureFlagRepositoryProvider).saveFlag(
            key: manifest.id,
            enabled: enabled ?? flag.enabled,
            platforms: flag.platforms,
            config: config ?? flag.config,
          );
      ref.invalidate(featureFlagsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Module was not saved: $error')),
      );
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
          itemCount: optionalModuleManifests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
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
                          onPressed:
                              saving ? null : () => _editConfig(manifest, flag),
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
