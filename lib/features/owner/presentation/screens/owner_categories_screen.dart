import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';

const _supportedLanguageLabels = <String, String>{
  'en': 'English',
  'te': 'తెలుగు',
  'hi': 'हिन्दी',
  'kn': 'ಕನ್ನಡ',
  'ta': 'தமிழ்',
};
const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
const _maxImageBytes = 10 * 1024 * 1024;

/// Category management for venue owners and administrators.
///
/// Every mutation is sent to Supabase. The realtime providers refresh this
/// screen and customer discovery surfaces after the database accepts it.
class OwnerCategoriesScreen extends ConsumerStatefulWidget {
  const OwnerCategoriesScreen({super.key});

  @override
  ConsumerState<OwnerCategoriesScreen> createState() =>
      _OwnerCategoriesScreenState();
}

class _OwnerCategoriesScreenState extends ConsumerState<OwnerCategoriesScreen> {
  String _searchQuery = '';
  String _filterMode = 'ALL';
  final Set<String> _expandedCategoryIds = <String>{};
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allVenueCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Space Categories Management 🏷️'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Categories',
            onPressed: () {
              ref.invalidate(allVenueCategoriesProvider);
              ref.invalidate(venueCategoriesProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
        backgroundColor: AppTheme.brand,
        foregroundColor: Colors.white,
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(allVenueCategoriesProvider),
        ),
        data: (categories) => _buildCategoryBody(context, theme, categories),
      ),
    );
  }

  Widget _buildCategoryBody(
    BuildContext context,
    ThemeData theme,
    List<VenueCategory> categories,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = categories.where((category) {
      final matchesQuery = query.isEmpty ||
          category.name.toLowerCase().contains(query) ||
          category.slug.toLowerCase().contains(query);
      final matchesFilter = switch (_filterMode) {
        'ACTIVE' => category.isActive,
        'DISABLED' => !category.isActive,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList(growable: false);
    final activeCount =
        categories.where((category) => category.isActive).length;
    final disabledCount = categories.length - activeCount;
    final canReorder = query.isEmpty && _filterMode == 'ALL';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search categories by name or slug...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: 'Clear Search',
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _filterMode == 'ALL',
                      label: Text('All (${categories.length})'),
                      onSelected: (_) => setState(() => _filterMode = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _filterMode == 'ACTIVE',
                      label: Text('Active ($activeCount)'),
                      avatar: const Icon(Icons.check_circle_rounded,
                          size: 16, color: Colors.green),
                      onSelected: (_) => setState(() => _filterMode = 'ACTIVE'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _filterMode == 'DISABLED',
                      label: Text('Disabled ($disabledCount)'),
                      avatar: const Icon(Icons.cancel_rounded,
                          size: 16, color: Colors.red),
                      onSelected: (_) =>
                          setState(() => _filterMode = 'DISABLED'),
                    ),
                    if (canReorder) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Long press to reorder',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories found',
                  message:
                      'Try adjusting your search query or add a new category.',
                )
              : canReorder
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: filtered.length,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) => _reorderCategories(
                        categories,
                        oldIndex,
                        newIndex,
                      ),
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        return _categoryTile(
                          context,
                          theme,
                          category,
                          index,
                          showDragHandle: true,
                          key: ValueKey(category.id),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _categoryTile(
                        context,
                        theme,
                        filtered[index],
                        index,
                        showDragHandle: false,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _categoryTile(
    BuildContext context,
    ThemeData theme,
    VenueCategory category,
    int index, {
    required bool showDragHandle,
    Key? key,
  }) {
    final isExpanded = _expandedCategoryIds.contains(category.id);
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedCornerShapeBorder(
        side: BorderSide(
          color: category.isActive
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.6)
              : Colors.red.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: showDragHandle
                ? ReorderableDragStartListener(
                    index: index,
                    child: _categoryIcon(category),
                  )
                : _categoryIcon(category),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: category.isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: category.isActive
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.isActive ? 'ACTIVE' : 'DISABLED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: category.isActive
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Slug: ${category.slug} • Section: ${category.parentSection ?? "general"} • Order: ${category.displayOrder}',
              style: TextStyle(
                  fontSize: 12, color: theme.textTheme.bodySmall?.color),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                  tooltip: 'Show Subsections',
                  onPressed: () => setState(() {
                    if (isExpanded) {
                      _expandedCategoryIds.remove(category.id);
                    } else {
                      _expandedCategoryIds.add(category.id);
                    }
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  tooltip: 'Edit Category',
                  onPressed: _isBusy
                      ? null
                      : () => _showEditCategoryDialog(context, category),
                ),
                Switch(
                  value: category.isActive,
                  activeThumbColor: AppTheme.brand,
                  onChanged: _isBusy
                      ? null
                      : (value) => _setCategoryActive(category, value),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: Colors.red),
                  tooltip: 'Delete Category',
                  onPressed:
                      _isBusy ? null : () => _confirmDeleteCategory(category),
                ),
              ],
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SubsectionsEditor(category: category),
            ),
        ],
      ),
    );
  }

  Widget _categoryIcon(VenueCategory category) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: category.isActive
            ? AppTheme.brand.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: category.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                category.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  category.icon?.isNotEmpty == true ? category.icon! : '🏷️',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            )
          : Text(
              category.icon?.isNotEmpty == true ? category.icon! : '🏷️',
              style: const TextStyle(fontSize: 22),
            ),
    );
  }

  Future<void> _reorderCategories(
    List<VenueCategory> categories,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...categories];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await _runMutation(() async {
      await ref.read(venueRepositoryProvider).reorderCategories(
            reordered.map((category) => category.id).toList(),
          );
    });
  }

  Future<void> _setCategoryActive(VenueCategory category, bool value) async {
    await _runMutation(() async {
      await ref
          .read(venueRepositoryProvider)
          .setCategoryActive(category.id, value);
    },
        successMessage:
            '${category.name} is now ${value ? "Active" : "Disabled"}');
  }

  Future<void> _confirmDeleteCategory(VenueCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Delete "${category.name}" and all of its subsections? This cannot be undone, and categories used by listings cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(() async {
      await ref.read(venueRepositoryProvider).deleteCategory(category.id);
    }, successMessage: 'Category deleted');
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconController = TextEditingController(text: '🏷️');
    final orderController = TextEditingController(text: '0');
    final nameTranslationControllers = _translationControllers();
    final descriptionTranslationControllers = _translationControllers();
    var selectedSection = 'general';
    var selectedLanguages = <String>{'en'};
    var slugManuallyEdited = false;
    var isActive = true;
    List<int>? pendingImage;
    String pendingExtension = 'jpg';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = VenueCategory(
            id: 'preview',
            name: nameController.text.trim().isEmpty
                ? 'New Category'
                : nameController.text.trim(),
            slug: slugController.text.trim().isEmpty
                ? 'new-category'
                : slugController.text.trim(),
            icon: iconController.text.trim().isEmpty
                ? '🏷️'
                : iconController.text.trim(),
            description: descriptionController.text.trim(),
            isActive: isActive,
            parentSection: selectedSection,
          );
          return AlertDialog(
            title: const Text('Add Space Category 🏷️'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: _CategoryForm(
                  nameController: nameController,
                  slugController: slugController,
                  descriptionController: descriptionController,
                  iconController: iconController,
                  orderController: orderController,
                  selectedSection: selectedSection,
                  selectedLanguages: selectedLanguages,
                  nameTranslationControllers: nameTranslationControllers,
                  descriptionTranslationControllers:
                      descriptionTranslationControllers,
                  isActive: isActive,
                  imageUrl: '',
                  pendingImage: pendingImage,
                  preview: preview,
                  onNameChanged: (value) {
                    if (!slugManuallyEdited)
                      slugController.text = _slugify(value);
                    setDialogState(() {});
                  },
                  onSlugChanged: (_) => slugManuallyEdited = true,
                  onSectionChanged: (value) =>
                      setDialogState(() => selectedSection = value),
                  onLanguagesChanged: (value) =>
                      setDialogState(() => selectedLanguages = value),
                  onActiveChanged: (value) =>
                      setDialogState(() => isActive = value),
                  onPickImage: () async {
                    final picked = await _pickImage();
                    if (picked == null) return;
                    setDialogState(() {
                      pendingImage = picked.bytes;
                      pendingExtension = picked.extension;
                    });
                  },
                  onRemoveImage: pendingImage == null
                      ? null
                      : () => setDialogState(() => pendingImage = null),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final slug = slugController.text.trim().toLowerCase();
                  final order = int.tryParse(orderController.text.trim());
                  final validationError =
                      _validateForm(name, slug, order, selectedLanguages);
                  if (validationError != null) {
                    _showMessage(validationError);
                    return;
                  }
                  Navigator.pop(dialogContext);
                  await _runMutation(() async {
                    final created =
                        await ref.read(venueRepositoryProvider).addCategory(
                              name: name,
                              slug: slug,
                              icon: iconController.text.trim().isEmpty
                                  ? null
                                  : iconController.text.trim(),
                              parentSection: selectedSection,
                              isActive: isActive,
                            );
                    final updated = created.copyWith(
                      description: descriptionController.text.trim(),
                      displayOrder: order ?? 0,
                      supportedLanguages: selectedLanguages.toList()..sort(),
                      nameTranslations: _nonEmptyTranslations(
                        nameTranslationControllers,
                        allowedLanguages: selectedLanguages,
                      ),
                      descriptionTranslations: _nonEmptyTranslations(
                        descriptionTranslationControllers,
                        allowedLanguages: selectedLanguages,
                      ),
                    );
                    final saved = await ref
                        .read(venueRepositoryProvider)
                        .updateCategory(updated);
                    if (pendingImage != null) {
                      await ref
                          .read(venueRepositoryProvider)
                          .uploadCategoryImage(
                            category: saved,
                            bytes: pendingImage!,
                            extension: pendingExtension,
                          );
                    }
                  }, successMessage: 'Category "$name" created successfully');
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
    _disposeControllers([
      nameController,
      slugController,
      descriptionController,
      iconController,
      orderController,
      ...nameTranslationControllers.values,
      ...descriptionTranslationControllers.values,
    ]);
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, VenueCategory category) async {
    final nameController = TextEditingController(text: category.name);
    final slugController = TextEditingController(text: category.slug);
    final descriptionController =
        TextEditingController(text: category.description);
    final iconController = TextEditingController(text: category.icon ?? '🏷️');
    final orderController =
        TextEditingController(text: '${category.displayOrder}');
    final nameTranslationControllers =
        _translationControllers(category.nameTranslations);
    final descriptionTranslationControllers =
        _translationControllers(category.descriptionTranslations);
    var selectedSection = category.parentSection ?? 'general';
    var selectedLanguages = category.supportedLanguages.toSet();
    if (selectedLanguages.isEmpty) selectedLanguages = {'en'};
    var isActive = category.isActive;
    List<int>? pendingImage;
    String pendingExtension = 'jpg';
    var imageRemoved = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = VenueCategory(
            id: category.id,
            name: nameController.text.trim().isEmpty
                ? category.name
                : nameController.text.trim(),
            slug: slugController.text.trim(),
            icon: iconController.text.trim(),
            description: descriptionController.text.trim(),
            imageUrl: imageRemoved ? '' : category.imageUrl,
            isActive: isActive,
            parentSection: selectedSection,
          );
          return AlertDialog(
            title: Text('Edit ${category.name} 🏷️'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: _CategoryForm(
                  nameController: nameController,
                  slugController: slugController,
                  descriptionController: descriptionController,
                  iconController: iconController,
                  orderController: orderController,
                  selectedSection: selectedSection,
                  selectedLanguages: selectedLanguages,
                  nameTranslationControllers: nameTranslationControllers,
                  descriptionTranslationControllers:
                      descriptionTranslationControllers,
                  isActive: isActive,
                  imageUrl: imageRemoved ? '' : category.imageUrl,
                  pendingImage: pendingImage,
                  preview: preview,
                  onNameChanged: (_) => setDialogState(() {}),
                  onSlugChanged: (_) => setDialogState(() {}),
                  onSectionChanged: (value) =>
                      setDialogState(() => selectedSection = value),
                  onLanguagesChanged: (value) =>
                      setDialogState(() => selectedLanguages = value),
                  onActiveChanged: (value) =>
                      setDialogState(() => isActive = value),
                  onPickImage: () async {
                    final picked = await _pickImage();
                    if (picked == null) return;
                    setDialogState(() {
                      pendingImage = picked.bytes;
                      pendingExtension = picked.extension;
                      imageRemoved = false;
                    });
                  },
                  onRemoveImage: (category.imageUrl.isNotEmpty ||
                          category.imagePath.isNotEmpty ||
                          pendingImage != null)
                      ? () => setDialogState(() {
                            pendingImage = null;
                            imageRemoved = true;
                          })
                      : null,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final slug = slugController.text.trim().toLowerCase();
                  final order = int.tryParse(orderController.text.trim());
                  final validationError =
                      _validateForm(name, slug, order, selectedLanguages);
                  if (validationError != null) {
                    _showMessage(validationError);
                    return;
                  }
                  Navigator.pop(dialogContext);
                  await _runMutation(() async {
                    final updated = category.copyWith(
                      name: name,
                      slug: slug,
                      icon: iconController.text.trim().isEmpty
                          ? '🏷️'
                          : iconController.text.trim(),
                      description: descriptionController.text.trim(),
                      parentSection: selectedSection,
                      isActive: isActive,
                      displayOrder: order ?? category.displayOrder,
                      supportedLanguages: selectedLanguages.toList()..sort(),
                      nameTranslations: _nonEmptyTranslations(
                        nameTranslationControllers,
                        allowedLanguages: selectedLanguages,
                      ),
                      descriptionTranslations: _nonEmptyTranslations(
                        descriptionTranslationControllers,
                        allowedLanguages: selectedLanguages,
                      ),
                      clearImage: imageRemoved,
                      clearImagePath: imageRemoved,
                    );
                    final saved = await ref
                        .read(venueRepositoryProvider)
                        .updateCategory(updated);
                    if (imageRemoved && category.imagePath.isNotEmpty) {
                      await ref
                          .read(venueRepositoryProvider)
                          .removeCategoryImage(
                            saved.copyWith(imagePath: category.imagePath),
                          );
                    } else if (pendingImage != null) {
                      await ref
                          .read(venueRepositoryProvider)
                          .uploadCategoryImage(
                            category: saved,
                            bytes: pendingImage!,
                            extension: pendingExtension,
                          );
                    }
                  }, successMessage: 'Category "$name" updated successfully');
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
    _disposeControllers([
      nameController,
      slugController,
      descriptionController,
      iconController,
      orderController,
      ...nameTranslationControllers.values,
      ...descriptionTranslationControllers.values,
    ]);
  }

  Future<void> _runMutation(
    Future<void> Function() mutation, {
    String? successMessage,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await mutation();
      ref.invalidate(allVenueCategoriesProvider);
      ref.invalidate(venueCategoriesProvider);
      if (successMessage != null) _showMessage(successMessage);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<({List<int> bytes, String extension})?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) {
      if (result != null)
        _showMessage('The selected image could not be read.', isError: true);
      return null;
    }
    final extension = (file.extension ?? '').toLowerCase();
    if (file.size > _maxImageBytes) {
      _showMessage('Images must be 10 MB or smaller.', isError: true);
      return null;
    }
    if (!_allowedImageExtensions.contains(extension)) {
      _showMessage('Use JPG, PNG, WEBP, or GIF images.', isError: true);
      return null;
    }
    return (bytes: file.bytes!.toList(), extension: extension);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ));
  }
}

class _SubsectionsEditor extends ConsumerWidget {
  const _SubsectionsEditor({required this.category});

  final VenueCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsectionsAsync =
        ref.watch(allVenueSubsectionsProvider(category.id));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
      ),
      child: subsectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(allVenueSubsectionsProvider(category.id)),
        ),
        data: (subsections) =>
            _SubsectionList(category: category, subsections: subsections),
      ),
    );
  }
}

class _SubsectionList extends ConsumerStatefulWidget {
  const _SubsectionList({required this.category, required this.subsections});

  final VenueCategory category;
  final List<VenueSubsection> subsections;

  @override
  ConsumerState<_SubsectionList> createState() => _SubsectionListState();
}

class _SubsectionListState extends ConsumerState<_SubsectionList> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final subsections = widget.subsections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subsections (${subsections.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _showSubsectionDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Subsection'),
            ),
          ],
        ),
        if (subsections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No subsections yet.'),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subsections.length,
            buildDefaultDragHandles: false,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final subsection = subsections[index];
              return ListTile(
                key: ValueKey(subsection.id),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle_rounded),
                ),
                title: Text(subsection.name),
                subtitle: Text(
                    '${subsection.slug} • Order: ${subsection.displayOrder}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Subsection',
                      onPressed: _busy
                          ? null
                          : () => _showSubsectionDialog(subsection),
                    ),
                    Switch(
                      value: subsection.isActive,
                      onChanged: _busy
                          ? null
                          : (value) => _setActive(subsection, value),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      tooltip: 'Delete Subsection',
                      onPressed: _busy ? null : () => _delete(subsection),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final reordered = [...widget.subsections];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await _run(() async {
      await ref.read(venueRepositoryProvider).reorderSubsections(
            widget.category.id,
            reordered.map((subsection) => subsection.id).toList(),
          );
    });
  }

  Future<void> _setActive(VenueSubsection subsection, bool value) async {
    await _run(() async {
      await ref
          .read(venueRepositoryProvider)
          .updateSubsection(subsection.copyWith(isActive: value));
    });
  }

  Future<void> _delete(VenueSubsection subsection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subsection?'),
        content: Text('Delete "${subsection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() =>
        ref.read(venueRepositoryProvider).deleteSubsection(subsection.id));
  }

  Future<void> _showSubsectionDialog([VenueSubsection? subsection]) async {
    final isEditing = subsection != null;
    final nameController = TextEditingController(text: subsection?.name ?? '');
    final slugController = TextEditingController(text: subsection?.slug ?? '');
    final descriptionController =
        TextEditingController(text: subsection?.description ?? '');
    final orderController =
        TextEditingController(text: '${subsection?.displayOrder ?? 0}');
    final nameTranslationControllers =
        _translationControllers(subsection?.nameTranslations);
    final descriptionTranslationControllers =
        _translationControllers(subsection?.descriptionTranslations);
    var selectedLanguages =
        (subsection?.supportedLanguages ?? const ['en']).toSet();
    if (selectedLanguages.isEmpty) selectedLanguages = {'en'};
    var isActive = subsection?.isActive ?? true;
    var slugManuallyEdited = isEditing;
    List<int>? pendingImage;
    String pendingExtension = 'jpg';
    var imageRemoved = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Subsection' : 'Add Subsection'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: _SubsectionForm(
                nameController: nameController,
                slugController: slugController,
                descriptionController: descriptionController,
                orderController: orderController,
                selectedLanguages: selectedLanguages,
                nameTranslationControllers: nameTranslationControllers,
                descriptionTranslationControllers:
                    descriptionTranslationControllers,
                isActive: isActive,
                imageUrl: imageRemoved ? '' : subsection?.imageUrl ?? '',
                pendingImage: pendingImage,
                onNameChanged: (value) {
                  if (!slugManuallyEdited)
                    slugController.text = _slugify(value);
                  setDialogState(() {});
                },
                onSlugChanged: (_) => slugManuallyEdited = true,
                onLanguagesChanged: (value) =>
                    setDialogState(() => selectedLanguages = value),
                onActiveChanged: (value) =>
                    setDialogState(() => isActive = value),
                onPickImage: () async {
                  final picked = await _pickImage();
                  if (picked == null) return;
                  setDialogState(() {
                    pendingImage = picked.bytes;
                    pendingExtension = picked.extension;
                    imageRemoved = false;
                  });
                },
                onRemoveImage: ((subsection?.imageUrl.isNotEmpty ?? false) ||
                        (subsection?.imagePath.isNotEmpty ?? false) ||
                        pendingImage != null)
                    ? () => setDialogState(() {
                          pendingImage = null;
                          imageRemoved = true;
                        })
                    : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final slug = slugController.text.trim().toLowerCase();
                final order = int.tryParse(orderController.text.trim());
                final validationError =
                    _validateForm(name, slug, order, selectedLanguages);
                if (validationError != null) {
                  _showMessage(validationError);
                  return;
                }
                Navigator.pop(dialogContext);
                await _run(() async {
                  final repo = ref.read(venueRepositoryProvider);
                  final saved = isEditing
                      ? await repo.updateSubsection(
                          subsection.copyWith(
                            name: name,
                            slug: slug,
                            description: descriptionController.text.trim(),
                            isActive: isActive,
                            displayOrder: order ?? subsection.displayOrder,
                            supportedLanguages: selectedLanguages.toList()
                              ..sort(),
                            nameTranslations: _nonEmptyTranslations(
                              nameTranslationControllers,
                              allowedLanguages: selectedLanguages,
                            ),
                            descriptionTranslations: _nonEmptyTranslations(
                              descriptionTranslationControllers,
                              allowedLanguages: selectedLanguages,
                            ),
                            clearImage: imageRemoved,
                            clearImagePath: imageRemoved,
                          ),
                        )
                      : await repo.addSubsection(
                          categoryId: widget.category.id,
                          name: name,
                          slug: slug,
                          description: descriptionController.text.trim(),
                          isActive: isActive,
                          displayOrder: order ?? 0,
                          supportedLanguages: selectedLanguages.toList()
                            ..sort(),
                          nameTranslations: _nonEmptyTranslations(
                            nameTranslationControllers,
                            allowedLanguages: selectedLanguages,
                          ),
                          descriptionTranslations: _nonEmptyTranslations(
                            descriptionTranslationControllers,
                            allowedLanguages: selectedLanguages,
                          ),
                        );
                  if (imageRemoved &&
                      subsection != null &&
                      subsection.imagePath.isNotEmpty) {
                    await repo.removeSubsectionImage(
                      saved.copyWith(imagePath: subsection.imagePath),
                    );
                  } else if (pendingImage != null) {
                    await repo.uploadSubsectionImage(
                      subsection: saved,
                      bytes: pendingImage!,
                      extension: pendingExtension,
                    );
                  }
                });
              },
              child: Text(isEditing ? 'Save Changes' : 'Create'),
            ),
          ],
        ),
      ),
    );
    _disposeControllers([
      nameController,
      slugController,
      descriptionController,
      orderController,
      ...nameTranslationControllers.values,
      ...descriptionTranslationControllers.values,
    ]);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(venueSubsectionsProvider(widget.category.id));
      ref.invalidate(allVenueSubsectionsProvider(widget.category.id));
      ref.invalidate(allVenueCategoriesProvider);
      ref.invalidate(venueCategoriesProvider);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final fileSize = file.size > 0 ? file.size : file.bytes!.length;
    if (fileSize > _maxImageBytes) {
      _showMessage('Images must be 10 MB or smaller.', isError: true);
      return null;
    }
    if (!_allowedImageExtensions.contains(extension)) {
      _showMessage('Use JPG, PNG, WEBP, or GIF images.', isError: true);
      return null;
    }
    return (bytes: file.bytes!.toList(), extension: extension);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ));
  }
}

class _CategoryForm extends StatelessWidget {
  const _CategoryForm({
    required this.nameController,
    required this.slugController,
    required this.descriptionController,
    required this.iconController,
    required this.orderController,
    required this.selectedSection,
    required this.selectedLanguages,
    required this.nameTranslationControllers,
    required this.descriptionTranslationControllers,
    required this.isActive,
    required this.imageUrl,
    required this.pendingImage,
    required this.onNameChanged,
    required this.onSlugChanged,
    required this.onSectionChanged,
    required this.onLanguagesChanged,
    required this.onActiveChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    this.preview,
  });

  final TextEditingController nameController;
  final TextEditingController slugController;
  final TextEditingController descriptionController;
  final TextEditingController iconController;
  final TextEditingController orderController;
  final String selectedSection;
  final Set<String> selectedLanguages;
  final Map<String, TextEditingController> nameTranslationControllers;
  final Map<String, TextEditingController> descriptionTranslationControllers;
  final bool isActive;
  final String imageUrl;
  final List<int>? pendingImage;
  final VenueCategory? preview;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onSlugChanged;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<Set<String>> onLanguagesChanged;
  final ValueChanged<bool> onActiveChanged;
  final Future<void> Function() onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final parentItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
          value: 'general', child: Text('General / Other Space')),
      const DropdownMenuItem(
          value: 'venues', child: Text('Function Halls / Venues')),
      const DropdownMenuItem(value: 'hotels', child: Text('Hotels & Rooms')),
      const DropdownMenuItem(value: 'pgs', child: Text('PG & Hostels')),
      const DropdownMenuItem(
          value: 'classes', child: Text('Institutes & Classes')),
      const DropdownMenuItem(value: 'sports', child: Text('Sports & Turfs')),
    ];
    if (!parentItems.any((item) => item.value == selectedSection)) {
      parentItems.add(
        DropdownMenuItem(
          value: selectedSection,
          child: Text(selectedSection.replaceAll('_', ' ')),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name *'),
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: slugController,
          decoration: const InputDecoration(
            labelText: 'SEO Slug *',
            hintText: 'e.g. function-halls',
            prefixText: '/',
          ),
          onChanged: onSlugChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          maxLength: 200,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: iconController,
          decoration: const InputDecoration(labelText: 'Icon / Emoji'),
        ),
        const SizedBox(height: 12),
        _ImagePickerRow(
          imageUrl: imageUrl,
          pendingImage: pendingImage,
          onPickImage: onPickImage,
          onRemoveImage: onRemoveImage,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedSection,
          decoration: const InputDecoration(labelText: 'Parent Section'),
          items: parentItems,
          onChanged: (value) {
            if (value != null) onSectionChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: orderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Display Order'),
        ),
        const SizedBox(height: 12),
        _LanguagePicker(
          selected: selectedLanguages,
          onChanged: onLanguagesChanged,
        ),
        _TranslationFields(
          selectedLanguages: selectedLanguages,
          nameControllers: nameTranslationControllers,
          descriptionControllers: descriptionTranslationControllers,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active Status'),
          value: isActive,
          onChanged: onActiveChanged,
        ),
        if (preview != null) ...[
          const Divider(height: 24),
          const Text('Live Preview',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _CategoryPreview(category: preview!),
        ],
      ],
    );
  }
}

class _SubsectionForm extends StatelessWidget {
  const _SubsectionForm({
    required this.nameController,
    required this.slugController,
    required this.descriptionController,
    required this.orderController,
    required this.selectedLanguages,
    required this.nameTranslationControllers,
    required this.descriptionTranslationControllers,
    required this.isActive,
    required this.imageUrl,
    required this.pendingImage,
    required this.onNameChanged,
    required this.onSlugChanged,
    required this.onLanguagesChanged,
    required this.onActiveChanged,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final TextEditingController nameController;
  final TextEditingController slugController;
  final TextEditingController descriptionController;
  final TextEditingController orderController;
  final Set<String> selectedLanguages;
  final Map<String, TextEditingController> nameTranslationControllers;
  final Map<String, TextEditingController> descriptionTranslationControllers;
  final bool isActive;
  final String imageUrl;
  final List<int>? pendingImage;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onSlugChanged;
  final ValueChanged<Set<String>> onLanguagesChanged;
  final ValueChanged<bool> onActiveChanged;
  final Future<void> Function() onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Subsection Name *'),
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: slugController,
          decoration:
              const InputDecoration(labelText: 'SEO Slug *', prefixText: '/'),
          onChanged: onSlugChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          maxLength: 200,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 4),
        _ImagePickerRow(
          imageUrl: imageUrl,
          pendingImage: pendingImage,
          onPickImage: onPickImage,
          onRemoveImage: onRemoveImage,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: orderController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Display Order'),
        ),
        const SizedBox(height: 12),
        _LanguagePicker(
            selected: selectedLanguages, onChanged: onLanguagesChanged),
        _TranslationFields(
          selectedLanguages: selectedLanguages,
          nameControllers: nameTranslationControllers,
          descriptionControllers: descriptionTranslationControllers,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active Status'),
          value: isActive,
          onChanged: onActiveChanged,
        ),
      ],
    );
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
      preview = Image.network(
        imageUrl,
        width: 96,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
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
            label: const Text('Remove'),
          ),
        ],
      ],
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Supported Languages',
            style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: _supportedLanguageLabels.entries.map((entry) {
            final isSelected = selected.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: entry.key == 'en'
                  ? null
                  : (value) {
                      final next = {...selected};
                      if (value) {
                        next.add(entry.key);
                      } else {
                        next.remove(entry.key);
                      }
                      onChanged(next);
                    },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TranslationFields extends StatelessWidget {
  const _TranslationFields({
    required this.selectedLanguages,
    required this.nameControllers,
    required this.descriptionControllers,
  });

  final Set<String> selectedLanguages;
  final Map<String, TextEditingController> nameControllers;
  final Map<String, TextEditingController> descriptionControllers;

  @override
  Widget build(BuildContext context) {
    final languages = selectedLanguages
        .where((language) => language != 'en')
        .toList()
      ..sort();
    if (languages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Translations',
            style: TextStyle(fontWeight: FontWeight.w600)),
        ...languages.expand((language) => [
              const SizedBox(height: 8),
              TextField(
                controller: nameControllers[language],
                decoration: InputDecoration(
                    labelText: '${_supportedLanguageLabels[language]} Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionControllers[language],
                maxLines: 2,
                decoration: InputDecoration(
                    labelText:
                        '${_supportedLanguageLabels[language]} Description'),
              ),
            ]),
      ],
    );
  }
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({required this.category});

  final VenueCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: category.imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(category.imageUrl,
                    width: 52, height: 52, fit: BoxFit.cover),
              )
            : Text(category.icon?.isNotEmpty == true ? category.icon! : '🏷️',
                style: const TextStyle(fontSize: 26)),
        title: Text(category.name),
        subtitle: Text(category.description.isEmpty
            ? 'No description'
            : category.description),
        trailing: category.isActive
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cancel, color: Colors.red),
      ),
    );
  }
}

Map<String, TextEditingController> _translationControllers(
    [Map<String, String>? values]) {
  return {
    for (final language
        in _supportedLanguageLabels.keys.where((language) => language != 'en'))
      language: TextEditingController(text: values?[language] ?? ''),
  };
}

Map<String, String> _nonEmptyTranslations(
  Map<String, TextEditingController> controllers, {
  Set<String>? allowedLanguages,
}) {
  return {
    for (final entry in controllers.entries)
      if ((allowedLanguages == null || allowedLanguages.contains(entry.key)) &&
          entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };
}

String? _validateForm(
    String name, String slug, int? order, Set<String> selectedLanguages) {
  if (name.isEmpty || name.length > 120)
    return 'Name must contain between 1 and 120 characters.';
  if (selectedLanguages.isEmpty) return 'Select at least one language.';
  if (!RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$').hasMatch(slug)) {
    return 'SEO slug may contain lowercase letters, numbers, hyphens, and underscores.';
  }
  if (order == null || order < 0)
    return 'Display order must be a non-negative number.';
  return null;
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

void _disposeControllers(Iterable<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}

class RoundedCornerShapeBorder extends ShapeBorder {
  const RoundedCornerShapeBorder(
      {required this.side, required this.borderRadius});

  final BorderSide side;
  final BorderRadius borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect.deflate(side.width)));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint();
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(side.width / 2), paint);
  }

  @override
  ShapeBorder scale(double t) => RoundedCornerShapeBorder(
        side: side.scale(t),
        borderRadius: borderRadius * t,
      );
}
