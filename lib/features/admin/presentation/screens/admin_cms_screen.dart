import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/domain/cms_banner.dart';
import '../../../cms/presentation/cms_providers.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../home/presentation/home_category_catalog.dart';

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
                  '${banner.isActive ? 'Active' : 'Hidden'}'
                  '${banner.slot != null && banner.slot!.isNotEmpty ? ' · slot: ${banner.slot}' : ''}'
                  ' · ${banner.subtitle}',
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
    var iconName = existing?.iconName;
    final accentColor =
        TextEditingController(text: existing?.accentColor ?? '');
    final gradientStart =
        TextEditingController(text: existing?.gradientStartColor ?? '');
    final gradientEnd =
        TextEditingController(text: existing?.gradientEndColor ?? '');
    final badgeColor = TextEditingController(text: existing?.badgeColor ?? '');
    // Real category slots only -- no fabricated 6th/7th option.
    final slotOptions = <String?>[
      null,
      for (final section in MainHomeSection.values) section.imageSlot,
    ];
    var slot = existing?.slot;
    if (slot != null && !slotOptions.contains(slot)) {
      // Preserve an existing custom slot value even if it doesn't match
      // one of today's category slots, rather than silently dropping it.
      slotOptions.add(slot);
    }
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
                    DropdownButtonFormField<String?>(
                      initialValue: slot,
                      decoration: const InputDecoration(
                        labelText: 'Target slot (optional)',
                        helperText:
                            'Leave blank for the generic offer carousel. '
                            'Pick a category slot to override that '
                            'category\'s home-screen image.',
                      ),
                      items: [
                        for (final s in slotOptions)
                          DropdownMenuItem<String?>(
                            value: s,
                            child: Text(s ?? 'None (generic banner)'),
                          ),
                      ],
                      onChanged: (value) => setState(() => slot = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    if (imageUrl.text.trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: AppNetworkImage(
                            url: imageUrl.text.trim(),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (slot != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => imageUrl.clear()),
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label: const Text('Restore fallback image'),
                        ),
                      ),
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Category visual style (optional)',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue:
                          CmsCategoryStyle.iconAllowlist.containsKey(iconName)
                              ? iconName
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Icon (optional)',
                        helperText:
                            'Curated set only -- leave blank to keep the '
                            "category's default emoji.",
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Default emoji'),
                        ),
                        for (final entry
                            in CmsCategoryStyle.iconAllowlist.entries)
                          DropdownMenuItem<String?>(
                            value: entry.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(entry.value, size: 18),
                                const SizedBox(width: 8),
                                Text(entry.key),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => iconName = value),
                    ),
                    const SizedBox(height: 8),
                    _HexColorField(
                        controller: accentColor,
                        label: 'Accent color (optional, #RRGGBB)',
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _HexColorField(
                        controller: gradientStart,
                        label: 'Gradient start (optional, #RRGGBB)',
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _HexColorField(
                        controller: gradientEnd,
                        label: 'Gradient end (optional, #RRGGBB)',
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _HexColorField(
                        controller: badgeColor,
                        label: 'Badge color (optional, #RRGGBB)',
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Live preview',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    _CategoryStylePreview(
                      title: title.text.trim().isEmpty
                          ? 'Preview'
                          : title.text.trim(),
                      style: CmsCategoryStyle.resolve(
                        MainHomeSection.functionHalls,
                        CmsBanner(
                          id: existing?.id ?? '',
                          title: title.text,
                          subtitle: subtitle.text,
                          isActive: true, // preview always shows the draft
                          iconName: iconName,
                          accentColor: accentColor.text,
                          gradientStartColor: gradientStart.text,
                          gradientEndColor: gradientEnd.text,
                          badgeColor: badgeColor.text,
                        ),
                      ),
                    ),
                    const Divider(height: 24),
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
            slot: slot,
            iconName: iconName,
            accentColor: accentColor.text.trim().isEmpty
                ? null
                : accentColor.text.trim(),
            gradientStartColor: gradientStart.text.trim().isEmpty
                ? null
                : gradientStart.text.trim(),
            gradientEndColor: gradientEnd.text.trim().isEmpty
                ? null
                : gradientEnd.text.trim(),
            badgeColor:
                badgeColor.text.trim().isEmpty ? null : badgeColor.text.trim(),
          ),
        );
    // Publish: this write is what makes the change live -- the customer
    // Home screen picks it up because activeCmsBannersProvider is
    // invalidated right here, which cascades into
    // activeCmsBannersBySlotProvider and re-renders the category cards
    // with the new image/icon/colors (cache-busted via updated_at) on
    // Web, iOS, and Android alike, within this same app session.
    ref.invalidate(adminCmsBannersProvider);
    ref.invalidate(activeCmsBannersProvider);
  }
}

/// A #RRGGBB text field with inline validation -- shows an error message
/// for a non-empty, malformed value, but never blocks Save: an invalid
/// value is simply ignored at render time (CmsCategoryStyle.resolve falls
/// back to the theme default), it's just surfaced here so the admin
/// notices before publishing rather than wondering why nothing changed.
class _HexColorField extends StatelessWidget {
  const _HexColorField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    final invalid =
        text.isNotEmpty && CmsCategoryStyle.tryParseHex(text) == null;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        errorText: invalid ? 'Not a valid hex color, e.g. #7C3AED' : null,
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

/// Live preview of a category card's resolved visual style, reflecting the
/// dialog's current DRAFT values (not yet saved/published).
class _CategoryStylePreview extends StatelessWidget {
  const _CategoryStylePreview({required this.title, required this.style});

  final String title;
  final CmsCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            style.gradientStart.withValues(alpha: 0.35),
            style.gradientEnd.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: style.accentColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          if (style.icon != null)
            Icon(style.icon, color: style.accentColor)
          else
            Icon(Icons.image_outlined, color: style.accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: style.badgeColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
