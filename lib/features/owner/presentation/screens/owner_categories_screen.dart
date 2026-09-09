import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';

/// Screen allowing Venue Owners and Administrators to add, edit,
/// activate, and deactivate categories dynamically without code changes.
class OwnerCategoriesScreen extends ConsumerStatefulWidget {
  const OwnerCategoriesScreen({super.key});

  @override
  ConsumerState<OwnerCategoriesScreen> createState() => _OwnerCategoriesScreenState();
}

class _OwnerCategoriesScreenState extends ConsumerState<OwnerCategoriesScreen> {
  String _searchQuery = '';
  String _filterMode = 'ALL'; // 'ALL', 'ACTIVE', 'DISABLED'

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
        onPressed: () => _showAddCategoryDialog(context),
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
        data: (categories) {
          final query = _searchQuery.trim().toLowerCase();
          final filtered = categories.where((cat) {
            if (query.isNotEmpty) {
              final matchesName = cat.name.toLowerCase().contains(query);
              final matchesSlug = cat.slug.toLowerCase().contains(query);
              if (!matchesName && !matchesSlug) return false;
            }
            if (_filterMode == 'ACTIVE') return cat.isActive;
            if (_filterMode == 'DISABLED') return !cat.isActive;
            return true;
          }).toList();

          final activeCount = categories.where((c) => c.isActive).length;
          final disabledCount = categories.length - activeCount;

          return Column(
            children: [
              // Search & Filter Header
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
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Row(
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
                          avatar: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                          onSelected: (_) => setState(() => _filterMode = 'ACTIVE'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _filterMode == 'DISABLED',
                          label: Text('Disabled ($disabledCount)'),
                          avatar: const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
                          onSelected: (_) => setState(() => _filterMode = 'DISABLED'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Categories List
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No categories found',
                        message: 'Try adjusting your search query or add a new category.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedCornerShapeBorder(
                              side: BorderSide(
                                color: cat.isActive
                                    ? theme.colorScheme.outlineVariant.withValues(alpha: 0.6)
                                    : Colors.red.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cat.isActive
                                      ? AppTheme.brand.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.Center,
                                child: Text(
                                  cat.icon?.isNotEmpty == true ? cat.icon! : '🏷️',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: cat.isActive ? null : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cat.isActive
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.red.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cat.isActive ? 'ACTIVE' : 'DISABLED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: cat.isActive ? Colors.green[700] : Colors.red[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Slug: ${cat.slug} • Section: ${cat.parentSection ?? "general"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 20),
                                    tooltip: 'Edit Category',
                                    onPressed: () => _showEditCategoryDialog(context, cat),
                                  ),
                                  Switch(
                                    value: cat.isActive,
                                    activeColor: AppTheme.brand,
                                    onChanged: (val) async {
                                      await ref.read(venueRepositoryProvider).setCategoryActive(cat.id, val);
                                      ref.invalidate(allVenueCategoriesProvider);
                                      ref.invalidate(venueCategoriesProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${cat.name} is now ${val ? "Active" : "Disabled"}'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final iconController = TextEditingController(text: '📸');
    String selectedSection = 'general';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Space Category 🏷️'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g., Photography Studio',
                      ),
                      onChanged: (val) {
                        if (slugController.text.isEmpty ||
                            slugController.text == val.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '').substring(0, (val.length - 1).clamp(0, val.length))) {
                          slugController.text = val.trim().toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slugController,
                      decoration: const InputDecoration(
                        labelText: 'Unique Slug',
                        hintText: 'e.g., photography_studio',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: iconController,
                      decoration: const InputDecoration(
                        labelText: 'Icon / Emoji',
                        hintText: 'e.g., 📸, 🏛️, 🏨, 🎓',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSection,
                      decoration: const InputDecoration(labelText: 'Parent Section'),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General / Other Space')),
                        DropdownMenuItem(value: 'venues', child: Text('Function Halls / Venues')),
                        DropdownMenuItem(value: 'hotels', child: Text('Hotels & Rooms')),
                        DropdownMenuItem(value: 'pgs', child: Text('PG & Hostels')),
                        DropdownMenuItem(value: 'classes', child: Text('Institutes & Classes')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSection = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Immediately'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final slug = slugController.text.trim().ifBlank(name.toLowerCase().replaceAll(' ', '_'));
                    if (name.isEmpty) return;

                    await ref.read(venueRepositoryProvider).addCategory(
                      name: name,
                      slug: slug,
                      icon: iconController.text.trim().ifBlank('🏷️'),
                      parentSection: selectedSection,
                      isActive: isActive,
                    );

                    ref.invalidate(allVenueCategoriesProvider);
                    ref.invalidate(venueCategoriesProvider);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Category "$name" created successfully!')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, VenueCategory cat) {
    final nameController = TextEditingController(text: cat.name);
    final iconController = TextEditingController(text: cat.icon ?? '🏷️');
    String selectedSection = cat.parentSection ?? 'general';
    bool isActive = cat.isActive;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${cat.name} 🏷️'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Category Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: iconController,
                      decoration: const InputDecoration(labelText: 'Icon / Emoji'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSection,
                      decoration: const InputDecoration(labelText: 'Parent Section'),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General / Other Space')),
                        DropdownMenuItem(value: 'venues', child: Text('Function Halls / Venues')),
                        DropdownMenuItem(value: 'hotels', child: Text('Hotels & Rooms')),
                        DropdownMenuItem(value: 'pgs', child: Text('PG & Hostels')),
                        DropdownMenuItem(value: 'classes', child: Text('Institutes & Classes')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSection = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Status'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final updated = cat.copyWith(
                      name: name,
                      icon: iconController.text.trim().ifBlank('🏷️'),
                      parentSection: selectedSection,
                      isActive: isActive,
                    );

                    await ref.read(venueRepositoryProvider).updateCategory(updated);
                    ref.invalidate(allVenueCategoriesProvider);
                    ref.invalidate(venueCategoriesProvider);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Category "${updated.name}" updated successfully!')),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
