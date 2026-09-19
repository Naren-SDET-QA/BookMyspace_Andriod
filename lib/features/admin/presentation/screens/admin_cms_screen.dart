import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/domain/cms_banner.dart';
import '../../../cms/presentation/cms_providers.dart';

class AdminCmsScreen extends ConsumerWidget {
  const AdminCmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(adminCmsBannersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home banners'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add banner'),
      ),
      body: banners.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminCmsBannersProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No CMS banners yet. Customer Home keeps the live coupon banner or the neutral “Book verified spaces” message until you add one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final banner = items[index];
              return ListTile(
                tileColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(banner.title),
                subtitle: Text(
                  '${banner.isActive ? 'Active' : 'Hidden'} · ${banner.subtitle}',
                ),
                onTap: () => _edit(context, ref, banner),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CmsBanner? existing,
  ) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final subtitle = TextEditingController(text: existing?.subtitle ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    final ctaText = TextEditingController(text: existing?.ctaText ?? '');
    final ctaRoute = TextEditingController(text: existing?.ctaRoute ?? '');
    final sortOrder = TextEditingController(
      text: (existing?.sortOrder ?? 0).toString(),
    );
    var active = existing?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'New banner' : 'Edit banner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: subtitle,
                      decoration: const InputDecoration(labelText: 'Subtitle'),
                    ),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                      ),
                    ),
                    TextField(
                      controller: ctaText,
                      decoration: const InputDecoration(
                        labelText: 'CTA label (optional)',
                      ),
                    ),
                    TextField(
                      controller: ctaRoute,
                      decoration: const InputDecoration(
                        labelText: 'CTA route (optional)',
                        hintText: '/search or /events',
                      ),
                    ),
                    TextField(
                      controller: sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display order',
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: active,
                      onChanged: (value) => setState(() => active = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.violet,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) return;
    await ref.read(cmsRepositoryProvider).upsertBanner(
          CmsBanner(
            id: existing?.id ?? '',
            title: title.text.trim(),
            subtitle: subtitle.text.trim(),
            imageUrl:
                imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
            ctaText: ctaText.text.trim().isEmpty ? null : ctaText.text.trim(),
            ctaRoute:
                ctaRoute.text.trim().isEmpty ? null : ctaRoute.text.trim(),
            isActive: active,
            sortOrder: int.tryParse(sortOrder.text.trim()) ?? 0,
          ),
        );
    ref.invalidate(adminCmsBannersProvider);
    ref.invalidate(activeCmsBannersProvider);
  }
}
