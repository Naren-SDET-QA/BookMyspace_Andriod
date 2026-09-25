import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../../../cms/presentation/screens/owner_facility_builder_screen.dart';
import '../../domain/venue_section.dart';
import '../venue_section_providers.dart';

const _translationLanguageLabels = <String, String>{
  'hi': 'हिन्दी',
  'te': 'తెలుగు',
  'ta': 'தமிழ்',
  'kn': 'ಕನ್ನಡ',
};
const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
const _maxImageBytes = 10 * 1024 * 1024;

/// Owner-facing plug-and-play page-section manager for a single venue.
///
/// Every enable/disable, edit, image, reorder, and subsection-visibility
/// change here writes a DRAFT row; nothing reaches the customer-facing venue
/// page until "Publish" is pressed. Only this venue's own owning
/// organisation can reach this screen with a matching venue (RLS enforces
/// the same rule server-side, independent of what the UI shows).
class OwnerVenueSectionsScreen extends ConsumerStatefulWidget {
  const OwnerVenueSectionsScreen({super.key, required this.venue});

  final Venue venue;

  @override
  ConsumerState<OwnerVenueSectionsScreen> createState() =>
      _OwnerVenueSectionsScreenState();
}

class _OwnerVenueSectionsScreenState
    extends ConsumerState<OwnerVenueSectionsScreen> {
  bool _isBusy = false;
  bool _previewMode = false;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync =
        ref.watch(ownerVenueSectionsProvider(widget.venue.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Sections · ${widget.venue.name}'),
        actions: [
          IconButton(
            tooltip: 'Facility builder',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: _isBusy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => OwnerFacilityBuilderScreen(
                                venueId: widget.venue.id,
                                venueName: widget.venue.name,
                              )),
                    ),
          ),
          IconButton(
            icon: Icon(
                _previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _previewMode ? 'Back to editing' : 'Preview draft',
            onPressed: () => setState(() => _previewMode = !_previewMode),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _previewMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isBusy ? null : () => _showAddSectionSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Section'),
              backgroundColor: AppTheme.violet,
              foregroundColor: Colors.white,
            ),
      body: sectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(ownerVenueSectionsProvider(widget.venue.id)),
        ),
        data: (sections) => _previewMode
            ? _PreviewBody(sections: sections)
            : _EditorBody(
                venue: widget.venue,
                sections: sections,
                isBusy: _isBusy,
                onBusyChanged: (v) => setState(() => _isBusy = v),
              ),
      ),
      bottomNavigationBar: sectionsAsync.maybeWhen(
        data: (sections) => sections.isEmpty
            ? null
            : _PublishBar(
                venue: widget.venue, sections: sections, isBusy: _isBusy),
        orElse: () => null,
      ),
    );
  }

  Future<void> _showAddSectionSheet(BuildContext context) async {
    final typesAsync = ref.read(venueSectionTypesProvider);
    final existing =
        ref.read(ownerVenueSectionsProvider(widget.venue.id)).value ?? [];
    final existingTypeIds = existing.map((s) => s.sectionTypeId).toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: typesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load section types: $e'),
            ),
            data: (types) {
              final addable = types
                  .where((t) =>
                      t.allowsMultiple || !existingTypeIds.contains(t.id))
                  .toList();
              if (addable.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Every supported section has already been added to this venue.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text('Add a section',
                      style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Choose from the sections your Admin has made available. It starts disabled from customers until you publish.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...addable.map(
                    (type) => ListTile(
                      leading: Icon(_iconFor(type.icon)),
                      title: Text(type.name),
                      subtitle: type.description.isEmpty
                          ? null
                          : Text(type.description),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _runMutation(() async {
                          await ref.read(addVenueSectionProvider((
                            venueId: widget.venue.id,
                            type: type,
                          )).future);
                        },
                            successMessage:
                                '${type.name} added — remember to publish.');
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _runMutation(
    Future<void> Function() mutation, {
    String? successMessage,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await mutation();
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red[700],
          ));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({
    required this.venue,
    required this.sections,
    required this.isBusy,
    required this.onBusyChanged,
  });

  final Venue venue;
  final List<VenueSection> sections;
  final bool isBusy;
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) {
      return const EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'No sections yet',
        message:
            'Tap "Add Section" to enable an optional page section for this venue — nothing goes live until you publish.',
      );
    }
    final sorted = [...widget.sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      buildDefaultDragHandles: false,
      itemCount: sorted.length,
      onReorder: (oldIndex, newIndex) => _reorder(sorted, oldIndex, newIndex),
      itemBuilder: (context, index) => _SectionCard(
        key: ValueKey(sorted[index].id),
        section: sorted[index],
        index: index,
        isBusy: widget.isBusy,
        onBusyChanged: widget.onBusyChanged,
      ),
    );
  }

  Future<void> _reorder(
      List<VenueSection> sorted, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final reordered = [...sorted];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    widget.onBusyChanged(true);
    try {
      await ref.read(reorderVenueSectionsProvider((
        venueId: widget.venue.id,
        sectionIds: reordered.map((s) => s.id).toList(),
      )).future);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reorder: $error')),
        );
      }
    } finally {
      widget.onBusyChanged(false);
    }
  }
}

class _SectionCard extends ConsumerWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.index,
    required this.isBusy,
    required this.onBusyChanged,
  });

  final VenueSection section;
  final int index;
  final bool isBusy;
  final ValueChanged<bool> onBusyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: _sectionThumbnail(section),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                section.title.isEmpty ? section.type.name : section.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (section.hasUnpublishedChanges)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Unpublished',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${section.type.name}${section.isEnabled ? '' : ' • Disabled'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: section.isEnabled,
              activeThumbColor: AppTheme.violet,
              onChanged: isBusy
                  ? null
                  : (value) => _run(context, ref, () async {
                        await ref.read(updateVenueSectionProvider(
                          section.copyWith(isEnabled: value),
                        ).future);
                      }),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              tooltip: 'Edit section',
              onPressed:
                  isBusy ? null : () => _showEditDialog(context, ref, section),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.red),
              tooltip: 'Remove section',
              onPressed:
                  isBusy ? null : () => _confirmDelete(context, ref, section),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionThumbnail(VenueSection section) {
    if (section.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          section.imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(_iconFor(section.icon ?? section.type.icon)),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(section.icon ?? section.type.icon),
          color: AppTheme.violet),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, VenueSection section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove section?'),
        content: Text(
          'Remove "${section.title.isEmpty ? section.type.name : section.title}" from this venue? Publish afterwards to update the customer-facing page.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(context, ref, () async {
      await ref.read(deleteVenueSectionProvider((
        venueId: section.venueId,
        sectionId: section.id,
      )).future);
    });
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() action) async {
    onBusyChanged(true);
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      onBusyChanged(false);
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, VenueSection section) async {
    final titleController = TextEditingController(text: section.title);
    final contentController = TextEditingController(text: section.content);
    final titleTranslationControllers = {
      for (final lang in _translationLanguageLabels.keys)
        lang:
            TextEditingController(text: section.titleTranslations[lang] ?? ''),
    };
    final contentTranslationControllers = {
      for (final lang in _translationLanguageLabels.keys)
        lang: TextEditingController(
            text: section.contentTranslations[lang] ?? ''),
    };
    var selectedSubsections = section.visibleSubsections.toSet();
    List<int>? pendingImage;
    String pendingExtension = 'jpg';
    var imageRemoved = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${section.type.name}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section.type.supportsTitle) ...[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (section.type.supportsContent) ...[
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Content'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (section.type.supportsImage) ...[
                    _ImagePickerRow(
                      imageUrl: imageRemoved ? '' : section.imageUrl,
                      pendingImage: pendingImage,
                      onPickImage: () async {
                        final picked = await _pickImage();
                        if (picked == null) return;
                        setDialogState(() {
                          pendingImage = picked.bytes;
                          pendingExtension = picked.extension;
                          imageRemoved = false;
                        });
                      },
                      onRemoveImage:
                          (section.imageUrl.isNotEmpty || pendingImage != null)
                              ? () => setDialogState(() {
                                    pendingImage = null;
                                    imageRemoved = true;
                                  })
                              : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (section.type.supportsSubsections) ...[
                    Text('Visible subsections',
                        style: Theme.of(context).textTheme.labelLarge),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: section.type.availableSubsections.map((option) {
                        final selected =
                            selectedSubsections.contains(option.key);
                        return FilterChip(
                          label: Text(option.label),
                          selected: selected,
                          onSelected: (value) => setDialogState(() {
                            if (value) {
                              selectedSubsections.add(option.key);
                            } else {
                              selectedSubsections.remove(option.key);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (section.type.supportsTitle ||
                      section.type.supportsContent) ...[
                    const Divider(),
                    Text('Translations (optional)',
                        style: Theme.of(context).textTheme.labelLarge),
                    ..._translationLanguageLabels.entries.expand((entry) => [
                          const SizedBox(height: 8),
                          if (section.type.supportsTitle)
                            TextField(
                              controller:
                                  titleTranslationControllers[entry.key],
                              decoration: InputDecoration(
                                  labelText: '${entry.value} title'),
                            ),
                          if (section.type.supportsContent) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller:
                                  contentTranslationControllers[entry.key],
                              maxLines: 2,
                              decoration: InputDecoration(
                                  labelText: '${entry.value} content'),
                            ),
                          ],
                        ]),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _run(context, ref, () async {
                  final updated = section.copyWith(
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    titleTranslations: _nonEmpty(titleTranslationControllers),
                    contentTranslations:
                        _nonEmpty(contentTranslationControllers),
                    visibleSubsections: selectedSubsections.toList(),
                    clearImage: imageRemoved,
                  );
                  final saved = await ref
                      .read(updateVenueSectionProvider(updated).future);
                  if (pendingImage != null) {
                    await ref
                        .read(venueSectionRepositoryProvider)
                        .uploadSectionImage(
                          section: saved,
                          bytes: pendingImage!,
                          extension: pendingExtension,
                        );
                  } else if (imageRemoved && section.imagePath.isNotEmpty) {
                    await ref
                        .read(venueSectionRepositoryProvider)
                        .removeSectionImage(
                          saved.copyWith(imagePath: section.imagePath),
                        );
                  }
                });
              },
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
    for (final c in [
      titleController,
      contentController,
      ...titleTranslationControllers.values,
      ...contentTranslationControllers.values,
    ]) {
      c.dispose();
    }
  }

  Future<({List<int> bytes, String extension})?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) return null;
    final extension = (file.extension ?? '').toLowerCase();
    if (file.size > _maxImageBytes) return null;
    if (!_allowedImageExtensions.contains(extension)) return null;
    return (bytes: file.bytes!.toList(), extension: extension);
  }

  Map<String, String> _nonEmpty(
      Map<String, TextEditingController> controllers) {
    return {
      for (final entry in controllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.imageUrl,
    required this.pendingImage,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final String imageUrl;
  final List<int>? pendingImage;
  final Future<void> Function() onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (pendingImage != null) {
      preview = Image.memory(Uint8List.fromList(pendingImage!),
          width: 96, height: 64, fit: BoxFit.cover);
    } else if (imageUrl.isNotEmpty) {
      preview = Image.network(imageUrl,
          width: 96,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined));
    } else {
      preview = const Icon(Icons.image_outlined, size: 28);
    }
    return Row(
      children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 96, height: 64, child: preview)),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.image_outlined, size: 18),
          label: Text(imageUrl.isEmpty && pendingImage == null
              ? 'Add Image'
              : 'Change Image'),
        ),
        if (onRemoveImage != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: onRemoveImage,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove')),
        ],
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.sections});

  final List<VenueSection> sections;

  @override
  Widget build(BuildContext context) {
    final enabled = [...sections.where((s) => s.isEnabled)]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    if (enabled.isEmpty) {
      return const EmptyState(
        icon: Icons.visibility_off_outlined,
        title: 'Nothing to preview',
        message:
            'Enable at least one section to see how the venue page will look.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Draft preview — this shows your unsaved changes, not what customers currently see.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ...enabled.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title.isEmpty ? section.type.name : section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (section.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(section.imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  ],
                  if (section.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(section.content),
                  ],
                  if (section.visibleSubsections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: section.visibleSubsections
                          .map((key) => Chip(
                                label: Text(
                                  section.type.availableSubsections
                                      .firstWhere((o) => o.key == key,
                                          orElse: () => VenueSubsectionOption(
                                              key: key, label: key))
                                      .label,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            )),
      ],
    );
  }
}

class _PublishBar extends ConsumerWidget {
  const _PublishBar(
      {required this.venue, required this.sections, required this.isBusy});

  final Venue venue;
  final List<VenueSection> sections;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasChanges = sections.any((s) => s.hasUnpublishedChanges);
    final lastPublished = sections
        .map((s) => s.publishedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null,
            (latest, dt) => latest == null || dt.isAfter(latest) ? dt : latest);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lastPublished == null
                    ? 'Never published'
                    : 'Last published ${_relative(lastPublished)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            FilledButton.icon(
              onPressed: (isBusy || !hasChanges)
                  ? null
                  : () async {
                      try {
                        await ref.read(
                            publishVenueSectionsProvider(venue.id).future);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Published — customers now see your changes.')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Publish failed: $error')));
                        }
                      }
                    },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(hasChanges ? 'Publish changes' : 'Up to date'),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

IconData _iconFor(String? name) {
  switch (name) {
    case 'info_outline':
      return Icons.info_outline;
    case 'check_circle_outline':
      return Icons.check_circle_outline;
    case 'photo_library_outlined':
      return Icons.photo_library_outlined;
    case 'gavel_outlined':
      return Icons.gavel_outlined;
    case 'help_outline':
      return Icons.help_outline;
    case 'place_outlined':
      return Icons.place_outlined;
    case 'dashboard_customize_outlined':
      return Icons.dashboard_customize_outlined;
    default:
      return Icons.widgets_outlined;
  }
}
