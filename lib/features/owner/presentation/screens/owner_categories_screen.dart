import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
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
  String? _selectedDesktopCategoryId;
  bool _desktopReorderMode = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allVenueCategoriesProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    if (MediaQuery.sizeOf(context).width >= 1050) {
      final allSubsectionsAsync = ref.watch(allVenueSubsectionsCatalogProvider);
      return categoriesAsync.when(
        loading: () => const _AdminDesktopLoading(),
        error: (error, _) => Scaffold(
          body: ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(allVenueCategoriesProvider),
          ),
        ),
        data: (categories) => _buildDesktopConsole(
          context,
          theme,
          categories,
          allSubsectionsAsync.valueOrNull ?? const <VenueSubsection>[],
          currentLocale: locale,
          onLocaleChanged: (nextLocale) =>
              ref.read(localeProvider.notifier).setLocale(nextLocale),
        ),
      );
    }

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
        backgroundColor: AppTheme.violet,
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

  Widget _buildDesktopConsole(
    BuildContext context,
    ThemeData theme,
    List<VenueCategory> categories,
    List<VenueSubsection> allSubsections, {
    required Locale currentLocale,
    required ValueChanged<Locale> onLocaleChanged,
  }) {
    final selected = categories.isEmpty
        ? null
        : _selectedDesktopCategoryId == null
            ? categories.first
            : categories.firstWhere(
                (category) => category.id == _selectedDesktopCategoryId,
                orElse: () => categories.first,
              );
    final counts = <String, int>{};
    for (final subsection in allSubsections) {
      counts[subsection.categoryId] = (counts[subsection.categoryId] ?? 0) + 1;
    }
    final activeCategories = categories
        .where((category) => category.isActive)
        .toList(growable: false);
    final activeSubsections = allSubsections
        .where((subsection) => subsection.isActive)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: SafeArea(
        child: Row(
          children: [
            _AdminDesktopSidebar(
              collapsed: false,
              onNavigate: (route) => context.go(route),
              onViewApp: () => context.go('/home'),
            ),
            Expanded(
              child: Column(
                children: [
                  _AdminDesktopTopBar(
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onMenu: () => _showMessage(
                      'Use the sidebar to navigate the Admin Console.',
                    ),
                    onViewApp: () => context.go('/home'),
                    currentLocale: currentLocale,
                    onLocaleChanged: onLocaleChanged,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DesktopBreadcrumbHeader(
                            onAddCategory: _isBusy
                                ? null
                                : () => _showAddCategoryDialog(context),
                            onManageIcons: selected == null
                                ? null
                                : () => _showIconManager(selected),
                            reorderMode: _desktopReorderMode,
                            onReorder: () => setState(() {
                              _desktopReorderMode = !_desktopReorderMode;
                            }),
                          ),
                          const SizedBox(height: 18),
                          _DesktopStatsRow(
                            categoryCount: categories.length,
                            subsectionCount: allSubsections.length,
                            activeCount: activeCategories.length,
                            languageCount: _supportedLanguageLabels.length,
                          ),
                          const SizedBox(height: 18),
                          if (categories.isEmpty)
                            const EmptyState(
                              icon: Icons.category_outlined,
                              title: 'No categories found',
                              message:
                                  'Create a category to start the live catalogue.',
                            )
                          else
                            _DesktopManagementGrid(
                              categories: categories,
                              counts: counts,
                              selected: selected!,
                              activeSubsections: activeSubsections,
                              reorderMode: _desktopReorderMode,
                              isBusy: _isBusy,
                              onSelect: (category) => setState(() {
                                _selectedDesktopCategoryId = category.id;
                              }),
                              onSearchChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              searchQuery: _searchQuery,
                              onEdit: (category) =>
                                  _showEditCategoryDialog(context, category),
                              onToggle: _setCategoryActive,
                              onDelete: _confirmDeleteCategory,
                              onReorder: _reorderCategories,
                              onRefresh: () {
                                ref.invalidate(allVenueCategoriesProvider);
                                ref.invalidate(venueCategoriesProvider);
                                ref.invalidate(
                                  allVenueSubsectionsCatalogProvider,
                                );
                              },
                              onChangeIcon: _showIconManager,
                              onChangeImage: _changeCategoryImage,
                              onRemoveImage: _removeCategoryImage,
                              onSaveDetails: (category) =>
                                  _showEditCategoryDialog(context, category),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    if (MediaQuery.sizeOf(context).width < 600) {
      return _compactCategoryTile(
        context,
        theme,
        category,
        index,
        showDragHandle: showDragHandle,
        key: key,
      );
    }

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
                  activeThumbColor: AppTheme.violet,
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

  Widget _compactCategoryTile(
    BuildContext context,
    ThemeData theme,
    VenueCategory category,
    int index, {
    required bool showDragHandle,
    Key? key,
  }) {
    final isExpanded = _expandedCategoryIds.contains(category.id);
    final icon = _categoryIcon(category);

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
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            leading: showDragHandle
                ? ReorderableDragStartListener(index: index, child: icon)
                : icon,
            title: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: category.isActive ? null : Colors.grey,
              ),
            ),
            subtitle: Text(
              'Slug: ${category.slug} • Section: ${category.parentSection ?? "general"} • Order: ${category.displayOrder}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
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
                  activeThumbColor: AppTheme.violet,
                  onChanged: _isBusy
                      ? null
                      : (value) => _setCategoryActive(category, value),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red,
                  ),
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
            ? AppTheme.violet.withValues(alpha: 0.1)
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

  Future<void> _showIconManager(VenueCategory category) async {
    const icons = <String>[
      '🏛️',
      '🏢',
      '🏟️',
      '🌳',
      '🎓',
      '🛕',
      '📸',
      '💼',
      '🎉',
      '🏷️',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Manage icon · ${category.name}'),
        content: SizedBox(
          width: 360,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: icons
                .map(
                  (icon) => InkWell(
                    onTap: () => Navigator.pop(dialogContext, icon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: icon == category.icon
                            ? AppTheme.violet.withValues(alpha: 0.14)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: icon == category.icon
                              ? AppTheme.violet
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (selected == null || selected == category.icon) return;
    await _runMutation(() async {
      await ref.read(venueRepositoryProvider).updateCategory(
            category.copyWith(icon: selected),
          );
    }, successMessage: 'Icon updated for ${category.name}');
  }

  Future<void> _changeCategoryImage(VenueCategory category) async {
    final picked = await _pickImage();
    if (picked == null) return;
    await _runMutation(() async {
      await ref.read(venueRepositoryProvider).uploadCategoryImage(
            category: category,
            bytes: picked.bytes,
            extension: picked.extension,
          );
    }, successMessage: 'Image updated for ${category.name}');
  }

  Future<void> _removeCategoryImage(VenueCategory category) async {
    if (category.imageUrl.isEmpty && category.imagePath.isEmpty) return;
    await _runMutation(() async {
      await ref.read(venueRepositoryProvider).removeCategoryImage(category);
    }, successMessage: 'Image removed from ${category.name}');
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

const _adminNavy = Color(0xFF071A33);
const _adminBlue = Color(0xFF0B63CE);
const _adminTeal = Color(0xFF07C7B7);
const _adminBorder = Color(0xFFDCE6F2);

class _AdminDesktopLoading extends StatelessWidget {
  const _AdminDesktopLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F8FC),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AdminDesktopSidebar extends StatelessWidget {
  const _AdminDesktopSidebar({
    required this.collapsed,
    required this.onNavigate,
    required this.onViewApp,
  });

  final bool collapsed;
  final ValueChanged<String> onNavigate;
  final VoidCallback onViewApp;

  static const _items = <({IconData icon, String label, String? route})>[
    (icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/admin'),
    (
      icon: Icons.category_outlined,
      label: 'Categories',
      route: '/admin/categories'
    ),
    (icon: Icons.campaign_outlined, label: 'Banners', route: '/admin/cms'),
    (
      icon: Icons.view_quilt_outlined,
      label: 'Home Sections',
      route: '/admin/cms'
    ),
    (
      icon: Icons.text_fields_outlined,
      label: 'Text & Labels',
      route: '/admin/cms'
    ),
    (
      icon: Icons.perm_media_outlined,
      label: 'Media Library',
      route: '/admin/cms'
    ),
    (icon: Icons.palette_outlined, label: 'App Theme', route: '/features'),
    (
      icon: Icons.account_balance_outlined,
      label: 'Venues',
      route: '/admin/venues'
    ),
    (
      icon: Icons.people_outline,
      label: 'Users & Owners',
      route: '/admin/users'
    ),
    (
      icon: Icons.calendar_month_outlined,
      label: 'Bookings',
      route: '/admin/bookings'
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      label: 'Payments',
      route: '/admin/payments'
    ),
    (icon: Icons.event_outlined, label: 'Events', route: '/admin/events'),
    (icon: Icons.school_outlined, label: 'Courses', route: '/admin/courses'),
    (
      icon: Icons.bar_chart_outlined,
      label: 'Reports & Analytics',
      route: '/analytics'
    ),
    (icon: Icons.tune_outlined, label: 'Feature Hub', route: '/admin/modules'),
    (
      icon: Icons.integration_instructions_outlined,
      label: 'Integrations',
      route: '/admin/integrations'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? 76 : 252,
      color: _adminNavy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: _adminTeal.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.hub_outlined, color: _adminTeal),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BookMySpace',
                          style: TextStyle(
                            color: _adminTeal,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Spaces for Every Moment',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final item in _items) ...[
                  if (item.label == 'Categories')
                    _AdminSidebarItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Content Management',
                      selected: true,
                      collapsed: collapsed,
                      onTap: () => onNavigate('/admin/categories'),
                    ),
                  _AdminSidebarItem(
                    icon: item.icon,
                    label: item.label,
                    selected: item.route == '/admin/categories',
                    collapsed: collapsed,
                    onTap: item.route == null
                        ? null
                        : () => onNavigate(item.route!),
                  ),
                ],
              ],
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5234F4), Color(0xFF126DE5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.rocket_launch_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your changes are live\nUpdates reflect immediately in the app',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    Icon(Icons.check_circle, color: _adminTeal, size: 18),
                  ],
                ),
              ),
            ),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'BookMySpace v1.0.0\nBuild for a Better Tomorrow',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminSidebarItem extends StatelessWidget {
  const _AdminSidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Colors.white : Colors.white.withValues(alpha: 0.82);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: collapsed ? label : '',
        child: Material(
          color: selected ? _adminBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
                vertical: 11,
              ),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ),
                    if (label == 'Content Management')
                      const Icon(Icons.expand_less, color: Colors.white70),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDesktopTopBar extends StatefulWidget {
  const _AdminDesktopTopBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onMenu,
    required this.onViewApp,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMenu;
  final VoidCallback onViewApp;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_AdminDesktopTopBar> createState() => _AdminDesktopTopBarState();
}

class _AdminDesktopTopBarState extends State<_AdminDesktopTopBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _AdminDesktopTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _adminBorder)),
      ),
      child: Row(
        children: [
          IconButton(
              onPressed: widget.onMenu, icon: const Icon(Icons.menu_rounded)),
          const SizedBox(width: 12),
          SizedBox(
            width: 440,
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search anything...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: widget.onViewApp,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View App'),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Language',
            onSelected: (languageCode) =>
                widget.onLocaleChanged(Locale(languageCode)),
            itemBuilder: (_) => _supportedLanguageLabels.entries
                .map((entry) => PopupMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(growable: false),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _supportedLanguageLabels[
                            widget.currentLocale.languageCode] ??
                        'English',
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFE1EBF7),
            child: Icon(Icons.person_outline, color: _adminNavy),
          ),
          const SizedBox(width: 8),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Administrator',
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }
}

class _DesktopBreadcrumbHeader extends StatelessWidget {
  const _DesktopBreadcrumbHeader({
    required this.onAddCategory,
    required this.onManageIcons,
    required this.reorderMode,
    required this.onReorder,
  });

  final VoidCallback? onAddCategory;
  final VoidCallback? onManageIcons;
  final bool reorderMode;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.home_outlined, size: 15, color: Colors.black45),
                  SizedBox(width: 8),
                  Text('Content Management',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                  Icon(Icons.chevron_right, color: Colors.black38, size: 18),
                  Text('Categories',
                      style: TextStyle(fontSize: 13, color: _adminNavy)),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Manage Categories',
                style: TextStyle(
                  color: _adminNavy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Add, edit, and organize categories and subsections. Changes appear instantly in the app.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onManageIcons,
          icon: const Icon(Icons.apps_outlined),
          label: const Text('Manage Icons'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onReorder,
          icon: const Icon(Icons.swap_vert_rounded),
          label: Text(reorderMode ? 'Done Reordering' : 'Reorder'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onAddCategory,
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
          style: FilledButton.styleFrom(
            backgroundColor: _adminTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _DesktopStatsRow extends StatelessWidget {
  const _DesktopStatsRow({
    required this.categoryCount,
    required this.subsectionCount,
    required this.activeCount,
    required this.languageCount,
  });

  final int categoryCount;
  final int subsectionCount;
  final int activeCount;
  final int languageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DesktopStatCard(
            icon: Icons.category_outlined,
            value: '$categoryCount',
            label: 'Main Categories',
            color: const Color(0xFF6C3CF0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DesktopStatCard(
            icon: Icons.account_tree_outlined,
            value: '$subsectionCount',
            label: 'Subsections',
            color: const Color(0xFFFFB51B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DesktopStatCard(
            icon: Icons.verified_outlined,
            value: '$activeCount active',
            label: 'Live Updates',
            color: _adminTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _DesktopStatCard(
            icon: Icons.language_outlined,
            value: '$languageCount',
            label: 'Supported Languages',
            color: _adminBlue,
          ),
        ),
      ],
    );
  }
}

class _DesktopStatCard extends StatelessWidget {
  const _DesktopStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _adminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopManagementGrid extends StatelessWidget {
  const _DesktopManagementGrid({
    required this.categories,
    required this.counts,
    required this.selected,
    required this.activeSubsections,
    required this.reorderMode,
    required this.isBusy,
    required this.onSelect,
    required this.onSearchChanged,
    required this.searchQuery,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onReorder,
    required this.onRefresh,
    required this.onChangeIcon,
    required this.onChangeImage,
    required this.onRemoveImage,
    required this.onSaveDetails,
  });

  final List<VenueCategory> categories;
  final Map<String, int> counts;
  final VenueCategory selected;
  final List<VenueSubsection> activeSubsections;
  final bool reorderMode;
  final bool isBusy;
  final ValueChanged<VenueCategory> onSelect;
  final ValueChanged<String> onSearchChanged;
  final String searchQuery;
  final ValueChanged<VenueCategory> onEdit;
  final Future<void> Function(VenueCategory, bool) onToggle;
  final Future<void> Function(VenueCategory) onDelete;
  final Future<void> Function(List<VenueCategory>, int, int) onReorder;
  final VoidCallback onRefresh;
  final Future<void> Function(VenueCategory) onChangeIcon;
  final Future<void> Function(VenueCategory) onChangeImage;
  final Future<void> Function(VenueCategory) onRemoveImage;
  final ValueChanged<VenueCategory> onSaveDetails;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = categories
        .where((category) =>
            query.isEmpty ||
            category.name.toLowerCase().contains(query) ||
            category.slug.toLowerCase().contains(query))
        .toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _DesktopCategoryListCard(
            categories: filtered,
            counts: counts,
            selected: selected,
            reorderMode: reorderMode && query.isEmpty,
            isBusy: isBusy,
            searchQuery: searchQuery,
            onSearchChanged: onSearchChanged,
            onSelect: onSelect,
            onEdit: onEdit,
            onToggle: onToggle,
            onDelete: onDelete,
            onReorder: onReorder,
            onRefresh: onRefresh,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: _DesktopCategoryDetailsCard(
            category: selected,
            isBusy: isBusy,
            onDelete: onDelete,
            onEdit: onEdit,
            onToggle: onToggle,
            onChangeIcon: onChangeIcon,
            onChangeImage: onChangeImage,
            onRemoveImage: onRemoveImage,
            onSaveDetails: onSaveDetails,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _adminBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SubsectionsEditor(category: selected),
                ),
              ),
              const SizedBox(height: 14),
              _DesktopLivePreviewCard(
                categories: categories.where((c) => c.isActive).toList(),
                activeSubsections: activeSubsections,
                onRefresh: onRefresh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopCategoryListCard extends StatelessWidget {
  const _DesktopCategoryListCard({
    required this.categories,
    required this.counts,
    required this.selected,
    required this.reorderMode,
    required this.isBusy,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelect,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onReorder,
    required this.onRefresh,
  });

  final List<VenueCategory> categories;
  final Map<String, int> counts;
  final VenueCategory selected;
  final bool reorderMode;
  final bool isBusy;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<VenueCategory> onSelect;
  final ValueChanged<VenueCategory> onEdit;
  final Future<void> Function(VenueCategory, bool) onToggle;
  final Future<void> Function(VenueCategory) onDelete;
  final Future<void> Function(List<VenueCategory>, int, int) onReorder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final child = reorderMode
        ? ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) =>
                onReorder(categories, oldIndex, newIndex),
            itemBuilder: (context, index) => _DesktopCategoryRow(
              key: ValueKey(categories[index].id),
              category: categories[index],
              count: counts[categories[index].id] ?? 0,
              index: index,
              selected: categories[index].id == selected.id,
              showDragHandle: true,
              isBusy: isBusy,
              onSelect: onSelect,
              onEdit: onEdit,
              onToggle: onToggle,
              onDelete: onDelete,
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) => _DesktopCategoryRow(
              category: categories[index],
              count: counts[categories[index].id] ?? 0,
              index: index,
              selected: categories[index].id == selected.id,
              showDragHandle: false,
              isBusy: isBusy,
              onSelect: onSelect,
              onEdit: onEdit,
              onToggle: onToggle,
              onDelete: onDelete,
            ),
          );

    return _DesktopPanel(
      title: 'Categories',
      trailing: IconButton(
        onPressed: onRefresh,
        tooltip: 'Refresh categories',
        icon: const Icon(Icons.refresh_rounded, size: 19),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search categories...',
              prefixIcon: Icon(Icons.search_rounded, size: 19),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No matching categories'),
            )
          else
            child,
        ],
      ),
    );
  }
}

class _DesktopCategoryRow extends StatelessWidget {
  const _DesktopCategoryRow({
    super.key,
    required this.category,
    required this.count,
    required this.index,
    required this.selected,
    required this.showDragHandle,
    required this.isBusy,
    required this.onSelect,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final VenueCategory category;
  final int count;
  final int index;
  final bool selected;
  final bool showDragHandle;
  final bool isBusy;
  final ValueChanged<VenueCategory> onSelect;
  final ValueChanged<VenueCategory> onEdit;
  final Future<void> Function(VenueCategory, bool) onToggle;
  final Future<void> Function(VenueCategory) onDelete;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _adminBlue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _adminBlue : _adminBorder),
      ),
      child: Row(
        children: [
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator,
                  color: selected ? Colors.white70 : Colors.black38, size: 18),
            ),
          _CategoryThumbnail(category: category, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : _adminNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$count subsections',
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: category.isActive,
            onChanged: isBusy ? null : (value) => onToggle(category, value),
            activeTrackColor: _adminTeal.withValues(alpha: 0.35),
            activeThumbColor: _adminTeal,
          ),
          PopupMenuButton<String>(
            tooltip: 'Category actions',
            onSelected: (value) {
              if (value == 'edit') onEdit(category);
              if (value == 'delete') onDelete(category);
            },
            icon: Icon(Icons.more_vert,
                color: selected ? Colors.white : Colors.black54, size: 18),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit category')),
              PopupMenuItem(value: 'delete', child: Text('Delete category')),
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => onSelect(category),
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

class _DesktopCategoryDetailsCard extends StatelessWidget {
  const _DesktopCategoryDetailsCard({
    required this.category,
    required this.isBusy,
    required this.onDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onChangeIcon,
    required this.onChangeImage,
    required this.onRemoveImage,
    required this.onSaveDetails,
  });

  final VenueCategory category;
  final bool isBusy;
  final Future<void> Function(VenueCategory) onDelete;
  final ValueChanged<VenueCategory> onEdit;
  final Future<void> Function(VenueCategory, bool) onToggle;
  final Future<void> Function(VenueCategory) onChangeIcon;
  final Future<void> Function(VenueCategory) onChangeImage;
  final Future<void> Function(VenueCategory) onRemoveImage;
  final ValueChanged<VenueCategory> onSaveDetails;

  @override
  Widget build(BuildContext context) {
    return _DesktopPanel(
      title: 'Edit Category',
      trailing: TextButton.icon(
        onPressed: isBusy ? null : () => onDelete(category),
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
        label:
            const Text('Delete Category', style: TextStyle(color: Colors.red)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DesktopReadOnlyField(
            label: 'Category Name',
            value: category.name,
            onTap: () => onEdit(category),
          ),
          const SizedBox(height: 12),
          _DesktopReadOnlyField(
            label: 'Description',
            value: category.description.isEmpty
                ? 'Add a customer-facing description'
                : category.description,
            maxLines: 2,
            onTap: () => onEdit(category),
          ),
          const SizedBox(height: 14),
          const Text('Icon',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 7),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFECE5FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(category.icon ?? '🏷️',
                    style: const TextStyle(fontSize: 25)),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => onChangeIcon(category),
                icon: const Icon(Icons.image_outlined, size: 17),
                label: const Text('Change Icon'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Category Image',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 7),
          Row(
            children: [
              _CategoryImagePreview(category: category),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => onChangeImage(category),
                icon: const Icon(Icons.image_outlined, size: 17),
                label: const Text('Change Image'),
              ),
              if (category.imageUrl.isNotEmpty || category.imagePath.isNotEmpty)
                IconButton(
                  tooltip: 'Remove image',
                  onPressed: isBusy ? null : () => onRemoveImage(category),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 14),
              Switch.adaptive(
                value: category.isActive,
                onChanged: isBusy ? null : (value) => onToggle(category, value),
                activeTrackColor: _adminTeal.withValues(alpha: 0.35),
                activeThumbColor: _adminTeal,
              ),
              Text(category.isActive ? 'Active' : 'Disabled'),
            ],
          ),
          const SizedBox(height: 8),
          _DesktopReadOnlyField(
            label: 'Display Order',
            value: '${category.displayOrder}',
            onTap: () => onEdit(category),
          ),
          const SizedBox(height: 10),
          _DesktopReadOnlyField(
            label: 'SEO Slug',
            value: '/${category.slug}',
            onTap: () => onEdit(category),
          ),
          const SizedBox(height: 12),
          const Text('Supported Languages',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: category.supportedLanguages
                .map((language) => Chip(
                      label:
                          Text(_supportedLanguageLabels[language] ?? language),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => onEdit(category),
                child: const Text('Edit Details'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isBusy ? null : () => onSaveDetails(category),
                style: FilledButton.styleFrom(backgroundColor: _adminTeal),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopLivePreviewCard extends StatelessWidget {
  const _DesktopLivePreviewCard({
    required this.categories,
    required this.activeSubsections,
    required this.onRefresh,
  });

  final List<VenueCategory> categories;
  final List<VenueSubsection> activeSubsections;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _DesktopPanel(
      title: 'Live Preview (App View)',
      trailing: TextButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Refresh Preview'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              gradient: LinearGradient(
                colors: [Color(0xFF153C8E), Color(0xFF04C8B9)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore Verified Spaces',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Find the perfect space for your special moments',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.take(6).map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 104,
                    child: Column(
                      children: [
                        _CategoryImagePreview(category: category, size: 76),
                        const SizedBox(height: 5),
                        Text(category.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${categories.length} live categories · ${activeSubsections.length} active subsections',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _adminNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DesktopReadOnlyField extends StatelessWidget {
  const _DesktopReadOnlyField({
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.onTap,
  });

  final String label;
  final String value;
  final int maxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
    return onTap == null
        ? field
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: field,
          );
  }
}

class _CategoryThumbnail extends StatelessWidget {
  const _CategoryThumbnail({required this.category, this.size = 42});

  final VenueCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _adminBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: category.imageUrl.isEmpty
          ? Text(category.icon ?? '🏷️',
              style: TextStyle(fontSize: size * 0.45))
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                category.imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  category.icon ?? '🏷️',
                  style: TextStyle(fontSize: size * 0.45),
                ),
              ),
            ),
    );
  }
}

class _CategoryImagePreview extends StatelessWidget {
  const _CategoryImagePreview({required this.category, this.size = 96});

  final VenueCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size * 0.62,
        color: const Color(0xFFE9F0F8),
        alignment: Alignment.center,
        child: category.imageUrl.isEmpty
            ? Text(category.icon ?? '🏷️', style: const TextStyle(fontSize: 26))
            : Image.network(
                category.imageUrl,
                width: size,
                height: size * 0.62,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  category.icon ?? '🏷️',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
      ),
    );
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
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                    const SizedBox(width: 6),
                    _SubsectionThumbnail(subsection: subsection),
                  ],
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

class _SubsectionThumbnail extends StatelessWidget {
  const _SubsectionThumbnail({required this.subsection});

  final VenueSubsection subsection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _adminTeal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: subsection.imageUrl.isEmpty
          ? Text(subsection.icon ?? '◈', style: const TextStyle(fontSize: 17))
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                subsection.imageUrl,
                width: 38,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text(
                  subsection.icon ?? '◈',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
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
