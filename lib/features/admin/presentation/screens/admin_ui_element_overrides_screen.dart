import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/domain/app_element_registry.dart';
import '../../../cms/domain/ui_element_override.dart';
import '../../../cms/presentation/ui_element_override_providers.dart';

/// Universal live element editor: any text, field hint, image, link, color,
/// visibility on ANY screen. Global branding elements (logo, loading
/// animation, wordmark — registry screen `branding`) are listed here but are
/// edited in App Studio → Global Branding, their single source of truth.
class AdminUiElementOverridesScreen extends ConsumerStatefulWidget {
  const AdminUiElementOverridesScreen({super.key});

  @override
  ConsumerState<AdminUiElementOverridesScreen> createState() =>
      _AdminUiElementOverridesScreenState();
}

class _AdminUiElementOverridesScreenState
    extends ConsumerState<AdminUiElementOverridesScreen> {
  final _screenController = TextEditingController(text: 'home');
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _screenController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenKey = _screenController.text.trim().isEmpty
        ? 'home'
        : _screenController.text.trim();
    final overrides = ref.watch(adminUiElementOverridesProvider(screenKey));
    final known = AppElementRegistry.screens[screenKey] ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Live element editor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: AppElementRegistry.screens.containsKey(
                    screenKey,
                  )
                      ? screenKey
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Screen (section)',
                    helperText:
                        'Pick a section or type a custom screen key below. '
                        'Covers every app section: home, search, bookings, '
                        'profile, auth, splash, branding/logo, …',
                  ),
                  items: [
                    for (final s in AppElementRegistry.screenKeys)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _screenController.text = v;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _screenController,
                  decoration: const InputDecoration(
                    labelText: 'Screen key',
                    hintText: 'home, search, branding, splash, profile...',
                    suffixIcon: Icon(Icons.refresh),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search elements',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                if (known.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final e in known)
                          ActionChip(
                            label: Text(e.$2),
                            avatar: Icon(
                              switch (e.$3) {
                                'image' => Icons.image_outlined,
                                'field' => Icons.text_fields_outlined,
                                'color' => Icons.palette_outlined,
                                'toggle' => Icons.toggle_on_outlined,
                                'animation' => Icons.animation_outlined,
                                _ => Icons.title_outlined,
                              },
                              size: 16,
                            ),
                            onPressed: e.isGlobalBranding
                                ? () => context.push(AppRoutes.adminAppStudio)
                                : () => _edit(
                                    screenKey,
                                    presetKey: e.$1,
                                    presetKind: e.$3,
                                  ),
                          ),
                      ],
                    ),
                  ),
              ],
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
              data: (items) {
                final filtered = _query.isEmpty
                    ? items
                    : items
                          .where(
                            (e) =>
                                e.elementKey.toLowerCase().contains(_query) ||
                                (e.text?.toLowerCase().contains(_query) ==
                                    true),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.edit_note_outlined,
                    title: 'No overrides for $screenKey',
                    message:
                        'Add an override to change text, image, link, color or hide an element.',
                    action: FilledButton.icon(
                      onPressed: () => _edit(screenKey),
                      icon: const Icon(Icons.add),
                      label: const Text('Add override'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(
                    adminUiElementOverridesProvider(screenKey),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return OutlinedButton.icon(
                          onPressed: () => _edit(screenKey),
                          icon: const Icon(Icons.add),
                          label: const Text('Add override'),
                        );
                      }
                      final item = filtered[index];
                      final img = item.imageUrl?.trim();
                      return Card(
                        child: ListTile(
                          leading: img != null && img.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: AppNetworkImage(
                                      url: img,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.tune_outlined),
                          title: Text(item.elementKey),
                          subtitle: Text(item.summary),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _edit(screenKey, item: item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(screenKey, item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String screenKey, UiElementOverride item) async {
    if (item.id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete override?'),
        content: Text(
          'Remove `${item.elementKey}` on `$screenKey`? The app falls back to its bundled text/image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(uiElementOverrideRepositoryProvider)
          .delete(item.id);
      ref.invalidate(adminUiElementOverridesProvider(screenKey));
      ref.invalidate(resolvedUiElementOverridesProvider(screenKey));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _edit(
    String screenKey, {
    UiElementOverride? item,
    String? presetKey,
    String? presetKind,
  }) async {
    final key = TextEditingController(
      text: item?.elementKey ?? presetKey ?? '',
    );
    final text = TextEditingController(text: item?.text ?? '');
    final placeholder = TextEditingController(text: item?.placeholder ?? '');
    final image = TextEditingController(text: item?.imageUrl ?? '');
    final link = TextEditingController(text: item?.linkUrl ?? '');
    final color = TextEditingController(text: item?.colorValue ?? '');
    var hidden = item?.hidden ?? false;
    var enabled = item?.enabled ?? true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            item == null
                ? 'Add override — $screenKey'
                : 'Edit ${item.elementKey}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (presetKind != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Editing a ${presetKind.toUpperCase()} element: fill the matching field below (text, image URL, hint, color).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                TextField(
                  controller: key,
                  enabled: item == null,
                  decoration: const InputDecoration(
                    labelText: 'Element key *',
                    hintText: 'hero_title, hero_image, book_button...',
                  ),
                ),
                TextField(
                  controller: text,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Text override (any label / title / field)',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                TextField(
                  controller: placeholder,
                  decoration: const InputDecoration(
                    labelText: 'Field hint override (text-field placeholder)',
                  ),
                ),
                TextField(
                  controller: image,
                  decoration: const InputDecoration(
                    labelText: 'Image URL override (any image / logo)',
                    hintText: 'https://…',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (image.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: AppNetworkImage(
                          url: image.text.trim(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setDialogState(() => image.clear()),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Restore bundled image'),
                  ),
                ),
                TextField(
                  controller: link,
                  decoration: const InputDecoration(
                    labelText: 'Link / route override (optional)',
                    hintText: '/search or https://…',
                  ),
                ),
                TextField(
                  controller: color,
                  decoration: const InputDecoration(
                    labelText: 'Color override (optional, #RRGGBB)',
                  ),
                  onChanged: (_) => setDialogState(() {}),
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
              child: const Text('Save & publish'),
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
              imageUrl: image.text,
              linkUrl: link.text,
              colorValue: color.text,
            );
        ref.invalidate(adminUiElementOverridesProvider(screenKey));
        ref.invalidate(resolvedUiElementOverridesProvider(screenKey));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Published — live in the app now')),
          );
        }
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
    image.dispose();
    link.dispose();
    color.dispose();
  }
}
