import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/domain/ui_element_override.dart';
import '../../../cms/presentation/ui_element_override_providers.dart';

class AdminUiElementOverridesScreen extends ConsumerStatefulWidget {
  const AdminUiElementOverridesScreen({super.key});

  @override
  ConsumerState<AdminUiElementOverridesScreen> createState() =>
      _AdminUiElementOverridesScreenState();
}

class _AdminUiElementOverridesScreenState
    extends ConsumerState<AdminUiElementOverridesScreen> {
  final _screenController = TextEditingController(text: 'home');

  @override
  void dispose() {
    _screenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenKey = _screenController.text.trim().isEmpty
        ? 'home'
        : _screenController.text.trim();
    final overrides = ref.watch(adminUiElementOverridesProvider(screenKey));
    return Scaffold(
      appBar: AppBar(title: const Text('Live element editor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _screenController,
              decoration: const InputDecoration(
                labelText: 'Screen key',
                hintText: 'home, search, profile...',
                suffixIcon: Icon(Icons.refresh),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: overrides.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(adminUiElementOverridesProvider(screenKey)),
              ),
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.edit_note_outlined,
                      title: 'No overrides for $screenKey',
                      message:
                          'Add an override to change copy or hide an element.',
                      action: FilledButton.icon(
                        onPressed: () => _edit(screenKey),
                        icon: const Icon(Icons.add),
                        label: const Text('Add override'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(
                        adminUiElementOverridesProvider(screenKey),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return OutlinedButton.icon(
                              onPressed: () => _edit(screenKey),
                              icon: const Icon(Icons.add),
                              label: const Text('Add override'),
                            );
                          }
                          final item = items[index];
                          return Card(
                            child: ListTile(
                              title: Text(item.elementKey),
                              subtitle: Text(
                                item.hidden
                                    ? 'Hidden'
                                    : item.text ??
                                          item.placeholder ??
                                          'No copy override',
                              ),
                              trailing: IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _edit(screenKey, item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(String screenKey, [UiElementOverride? item]) async {
    final key = TextEditingController(text: item?.elementKey ?? '');
    final text = TextEditingController(text: item?.text ?? '');
    final placeholder = TextEditingController(text: item?.placeholder ?? '');
    var hidden = item?.hidden ?? false;
    var enabled = item?.enabled ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add override' : 'Edit override'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: key,
                  enabled: item == null,
                  decoration: const InputDecoration(labelText: 'Element key'),
                ),
                TextField(
                  controller: text,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Text override'),
                ),
                TextField(
                  controller: placeholder,
                  decoration: const InputDecoration(
                    labelText: 'Placeholder override',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hidden,
                  onChanged: (value) =>
                      setDialogState(() => hidden = value ?? false),
                  title: const Text('Hide element'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (value) =>
                      setDialogState(() => enabled = value ?? true),
                  title: const Text('Enabled'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final keyValue = key.text.trim();
    if (save == true && keyValue.isNotEmpty && mounted) {
      try {
        await ref
            .read(uiElementOverrideRepositoryProvider)
            .save(
              screenKey: screenKey,
              elementKey: keyValue,
              locale: 'en',
              text: text.text,
              placeholder: placeholder.text,
              hidden: hidden,
              enabled: enabled,
            );
        ref.invalidate(adminUiElementOverridesProvider(screenKey));
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save override: $error')),
          );
        }
      }
    }
    key.dispose();
    text.dispose();
    placeholder.dispose();
  }
}
