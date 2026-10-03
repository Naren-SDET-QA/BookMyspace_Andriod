import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../cms/domain/app_element_registry.dart';
import '../../../cms/domain/cms_media_asset.dart';
import '../../../cms/domain/ui_element_override.dart';
import '../../../cms/presentation/cms_media_providers.dart';
import '../../../cms/presentation/ui_element_override_providers.dart';
import '../admin_settings_providers.dart';
import '../app_branding_providers.dart';
import '../branding_revisions.dart';
import '../widgets/brand_loading_indicator.dart';

/// Central Global UI Content & Branding Studio (`/admin/studio`).
///
/// Authorized admins can:
/// - Pick any screen in the application
/// - Inspect all registered editable UI elements (text, image, field, color)
/// - See fallback/default values and active override status
/// - Edit and publish live overrides across the app
/// - Preview the real running customer screen
/// - Restore fallback defaults with one click
/// - Edit global branding (app name, logos, splash, wordmark colors)
class AdminAppStudioScreen extends ConsumerStatefulWidget {
  const AdminAppStudioScreen({super.key});

  @override
  ConsumerState<AdminAppStudioScreen> createState() => _AdminAppStudioScreenState();
}

class _AdminAppStudioScreenState extends ConsumerState<AdminAppStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedScreenKey = 'home';
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _screenToRoute(String screenKey) {
    switch (screenKey) {
      case 'home':
        return AppRoutes.home;
      case 'location':
        return AppRoutes.search;
      case 'hotels':
        return AppRoutes.staysList;
      case 'pg':
        return AppRoutes.pgList;
      case 'function_halls':
        return '${AppRoutes.search}?category=function_halls';
      case 'venue_details':
        return AppRoutes.search;
      case 'bookings':
        return AppRoutes.bookings;
      case 'referral':
        return AppRoutes.referrals;
      case 'favorites':
        return AppRoutes.saved;
      case 'institutes':
        return AppRoutes.education;
      case 'courses':
        return AppRoutes.coursesList;
      case 'kyc':
        return AppRoutes.ownerRegistration;
      case 'profile':
        return AppRoutes.profile;
      case 'settings':
        return AppRoutes.settings;
      case 'search':
        return AppRoutes.search;
      case 'notifications':
        return AppRoutes.notifications;
      case 'owner_dashboard':
        return AppRoutes.ownerDashboard;
      case 'admin':
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: const Text('App Studio — Global UI & Branding'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'UI Elements'),
            Tab(icon: Icon(Icons.branding_watermark_rounded), text: 'Global Branding'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildElementsTab(theme),
          _buildBrandingTab(theme),
        ],
      ),
    );
  }

  Widget _buildElementsTab(ThemeData theme) {
    final screens = AppElementRegistry.screens;
    final screenElements = screens[_selectedScreenKey] ?? const [];
    final overridesAsync = ref.watch(adminUiElementOverridesProvider(_selectedScreenKey));

    final filteredElements = screenElements.where((e) {
      if (_searchFilter.isEmpty) return true;
      final query = _searchFilter.toLowerCase();
      return e.label.toLowerCase().contains(query) ||
          e.elementKey.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          e.fallback.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Top Toolbar: Screen Picker & Preview Link
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedScreenKey,
                      decoration: const InputDecoration(
                        labelText: 'Target Screen / Domain',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final key in screens.keys)
                          DropdownMenuItem(
                            value: key,
                            child: Text(
                              '${key.toUpperCase()} (${screens[key]?.length ?? 0} elements)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedScreenKey = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final route = _screenToRoute(_selectedScreenKey);
                      context.push(route);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Preview Screen'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  hintText: 'Filter elements by key, label or copy...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchFilter = val.trim()),
              ),
            ],
          ),
        ),

        // Elements List
        Expanded(
          child: overridesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading overrides: $err')),
            data: (overrides) {
              final overrideMap = {for (final o in overrides) o.elementKey: o};

              if (filteredElements.isEmpty) {
                return Center(
                  child: Text(
                    'No elements match "$_searchFilter"',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredElements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final def = filteredElements[index];
                  final override = overrideMap[def.elementKey];
                  final isOverridden = override != null &&
                      (override.text != null ||
                          override.imageUrl != null ||
                          override.colorValue != null ||
                          override.hidden);

                  if (def.isGlobalBranding) {
                    // Single source of truth: branding fields live in the
                    // global `branding` row, edited (draft / publish /
                    // history) only in the Global Branding tab.
                    return _ElementEditorCard(
                      definition: def,
                      activeOverride: null,
                      isOverridden: false,
                      onEdit: _openGlobalBranding,
                      onRestore: null,
                    );
                  }
                  return _ElementEditorCard(
                    definition: def,
                    activeOverride: override,
                    isOverridden: isOverridden,
                    onEdit: () => _openEditorDialog(def, override),
                    onRestore: isOverridden && override.id.isNotEmpty
                        ? () => _restoreFallback(override)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openGlobalBranding() {
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Global brand elements (logo, loading animation, wordmark) are '
          'edited in Global Branding with draft, preview, publish and history.',
        ),
      ),
    );
  }

  Future<void> _restoreFallback(UiElementOverride override) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Default Value?'),
        content: Text(
          'This will delete the override for "${override.elementKey}" on "$_selectedScreenKey" and revert back to the bundled copy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore Default')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(uiElementOverrideRepositoryProvider).delete(override.id);
      ref.invalidate(adminUiElementOverridesProvider(_selectedScreenKey));
      ref.invalidate(resolvedUiElementOverridesProvider(_selectedScreenKey));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored default for ${override.elementKey}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore default: $e')),
        );
      }
    }
  }

  Future<void> _openEditorDialog(AppElementDefinition def, UiElementOverride? existing) async {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final colorCtrl = TextEditingController(text: existing?.colorValue ?? '');
    var isHidden = existing?.hidden ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              _typeBadge(def.elementType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  def.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  def.description,
                  style: themeOf(context).textTheme.bodySmall?.copyWith(
                    color: themeOf(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeOf(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BUNDLED DEFAULT / FALLBACK:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        def.fallback.isEmpty ? '(none)' : def.fallback,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (def.elementType == UiElementType.text || def.elementType == UiElementType.field)
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: def.elementType == UiElementType.field
                          ? 'Field Placeholder / Hint Override'
                          : 'Live Text Override',
                      border: const OutlineInputBorder(),
                      hintText: def.fallback,
                    ),
                  ),

                if (def.elementType == UiElementType.image) ...[
                  TextField(
                    controller: imageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Image URL Override (HTTPS)',
                      border: const OutlineInputBorder(),
                      hintText: def.fallback,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setModalState(() => imageCtrl.clear()),
                      ),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  if (imageCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: AppNetworkImage(url: imageCtrl.text.trim(), fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ],

                if (def.elementType == UiElementType.color) ...[
                  TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hex Color Override (#RRGGBB)',
                      border: const OutlineInputBorder(),
                      hintText: def.fallback,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                ],

                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide this element in the UI', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Collapses the element without breaking layout', style: TextStyle(fontSize: 11)),
                  value: isHidden,
                  onChanged: (val) => setModalState(() => isHidden = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save & Publish Live'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await ref.read(uiElementOverrideRepositoryProvider).save(
            screenKey: _selectedScreenKey,
            elementKey: def.elementKey,
            locale: 'en',
            text: textCtrl.text.trim().isEmpty ? null : textCtrl.text.trim(),
            imageUrl: imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
            colorValue: colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
            hidden: isHidden,
            enabled: true,
          );

      ref.invalidate(adminUiElementOverridesProvider(_selectedScreenKey));
      ref.invalidate(resolvedUiElementOverridesProvider(_selectedScreenKey));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Published "${def.label}" — immediately live in the app!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save override: $e')),
        );
      }
    }
  }

  Widget _buildBrandingTab(ThemeData theme) {
    final brandingAsync = ref.watch(appBrandingProvider);

    return brandingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading branding: $e')),
      data: (branding) => _GlobalBrandingEditor(branding: branding),
    );
  }

  Widget _typeBadge(UiElementType type) {
    Color color;
    switch (type) {
      case UiElementType.text:
        color = Colors.blue;
        break;
      case UiElementType.image:
        color = Colors.purple;
        break;
      case UiElementType.field:
        color = Colors.teal;
        break;
      case UiElementType.color:
        color = Colors.amber;
        break;
      case UiElementType.animation:
        color = Colors.pink;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  ThemeData themeOf(BuildContext context) => Theme.of(context);
}

class _ElementEditorCard extends StatelessWidget {
  const _ElementEditorCard({
    required this.definition,
    required this.activeOverride,
    required this.isOverridden,
    required this.onEdit,
    required this.onRestore,
  });

  final AppElementDefinition definition;
  final UiElementOverride? activeOverride;
  final bool isOverridden;
  final VoidCallback onEdit;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverridden
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.dividerColor,
          width: isOverridden ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  definition.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (isOverridden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'ACTIVE OVERRIDE',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Key: ${definition.qualifiedKey} • ${definition.description}',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),

          // Display Current Value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverridden ? 'Current Live Value:' : 'Bundled Default:',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                if (activeOverride?.hidden == true)
                  const Text('(Hidden)', style: TextStyle(color: Colors.red, fontSize: 12))
                else if (definition.elementType == UiElementType.image &&
                    (activeOverride?.imageUrl?.isNotEmpty == true || definition.fallback.isNotEmpty)) ...[
                  Text(
                    activeOverride?.imageUrl ?? definition.fallback,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 70,
                      width: 140,
                      child: AppNetworkImage(
                        url: activeOverride?.imageUrl ?? definition.fallback,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ] else
                  Text(
                    activeOverride?.text ?? definition.fallback,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isOverridden ? FontWeight.bold : FontWeight.normal,
                      color: isOverridden ? theme.colorScheme.primary : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onRestore != null)
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Restore Default', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  definition.isGlobalBranding
                      ? 'Edit in Global Branding'
                      : (isOverridden ? 'Edit Override' : 'Override Element'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalBrandingEditor extends ConsumerStatefulWidget {
  const _GlobalBrandingEditor({required this.branding});

  final AppBranding branding;

  @override
  ConsumerState<_GlobalBrandingEditor> createState() => _GlobalBrandingEditorState();
}

class _GlobalBrandingEditorState extends ConsumerState<_GlobalBrandingEditor> {
  late TextEditingController _appNameCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _logoLightCtrl;
  late TextEditingController _logoDarkCtrl;
  late TextEditingController _splashCtrl;
  late TextEditingController _firstColorCtrl;
  late TextEditingController _restColorCtrl;
  late TextEditingController _animationColorCtrl;
  late TextEditingController _animationThicknessCtrl;
  late TextEditingController _animationAssetCtrl;
  bool _animationEnabled = AppBranding.defaultAnimationEnabled;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _appNameCtrl = TextEditingController();
    _taglineCtrl = TextEditingController();
    _logoLightCtrl = TextEditingController();
    _logoDarkCtrl = TextEditingController();
    _splashCtrl = TextEditingController();
    _firstColorCtrl = TextEditingController();
    _restColorCtrl = TextEditingController();
    _animationColorCtrl = TextEditingController();
    _animationThicknessCtrl = TextEditingController();
    _animationAssetCtrl = TextEditingController();
    _applyToForm(widget.branding);
  }

  /// Loads [b] into the form (initial values, a saved draft, or a history
  /// snapshot). Nothing is published until the admin presses Publish.
  void _applyToForm(AppBranding b) {
    _appNameCtrl.text = b.appName;
    _taglineCtrl.text = b.tagline;
    _logoLightCtrl.text = b.logoUrl ?? '';
    _logoDarkCtrl.text = b.logoDarkUrl ?? '';
    _splashCtrl.text = b.splashUrl ?? '';
    _firstColorCtrl.text = b.wordmarkFirstColor ?? '#3F51B5';
    _restColorCtrl.text = b.wordmarkRestColor ?? '';
    _animationColorCtrl.text = b.animationColor ?? '';
    _animationThicknessCtrl.text = b.animationThickness.toString();
    _animationAssetCtrl.text = b.animationAssetUrl ?? '';
    _animationEnabled = b.animationEnabled;
  }

  @override
  void dispose() {
    _appNameCtrl.dispose();
    _taglineCtrl.dispose();
    _logoLightCtrl.dispose();
    _logoDarkCtrl.dispose();
    _splashCtrl.dispose();
    _firstColorCtrl.dispose();
    _restColorCtrl.dispose();
    _animationColorCtrl.dispose();
    _animationThicknessCtrl.dispose();
    _animationAssetCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// Validation message for the spinner colour field, or null when valid.
  String? get _animationColorError {
    final v = _animationColorCtrl.text.trim();
    if (v.isEmpty) return null;
    return parseBrandHexColor(v) == null ? 'Use a hex colour like #FF5733' : null;
  }

  /// Validation message for the spinner thickness field, or null when valid.
  String? get _animationThicknessError {
    final v = _animationThicknessCtrl.text.trim();
    if (v.isEmpty) return null;
    final parsed = double.tryParse(v);
    if (parsed == null || !parsed.isFinite) return 'Enter a number';
    if (parsed < AppBranding.minAnimationThickness ||
        parsed > AppBranding.maxAnimationThickness) {
      return 'Must be between ${AppBranding.minAnimationThickness} '
          'and ${AppBranding.maxAnimationThickness}';
    }
    return null;
  }

  bool get _hasErrors =>
      _animationEnabled && (_animationColorError != null || _animationThicknessError != null);

  /// The values the form would publish, in the stored metadata shape.
  Map<String, dynamic> _formValues() {
    final thickness = double.tryParse(_animationThicknessCtrl.text.trim());
    return {
      'app_name': _nullIfEmpty(_appNameCtrl) ?? 'BookMySpace',
      'tagline': _taglineCtrl.text.trim(),
      'logo_url': _nullIfEmpty(_logoLightCtrl),
      'logo_dark_url': _nullIfEmpty(_logoDarkCtrl),
      'splash_url': _nullIfEmpty(_splashCtrl),
      'wordmark_first_color': _nullIfEmpty(_firstColorCtrl) ?? '#3F51B5',
      'wordmark_rest_color': _nullIfEmpty(_restColorCtrl),
      'animation_enabled': _animationEnabled,
      'animation_color': _nullIfEmpty(_animationColorCtrl),
      'animation_thickness': AppBranding.clampThickness(thickness),
      'animation_asset_url': _nullIfEmpty(_animationAssetCtrl),
    };
  }

  /// Draft branding used for the live preview and for publishing, so the
  /// preview always matches exactly what customers will get.
  AppBranding get _draft => AppBranding.fromMap(_formValues());

  /// Lets the admin pick an existing image / GIF / WebP from the CMS Media
  /// library (the same `category-media` bucket used everywhere else).
  Future<void> _chooseFromMedia(
    TextEditingController target, {
    bool animatedOnly = false,
  }) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _MediaPickerDialog(animatedOnly: animatedOnly),
    );
    if (picked == null || !mounted) return;
    setState(() => target.text = picked);
    _toast('Selected from Media. Review the preview, then Publish.');
  }

  Future<void> _uploadMedia(
    TextEditingController target, {
    required String what,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: CmsMediaRules.allowedExtensions.toList(),
      withData: true,
    );
    if (result == null || result.files.single.bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final asset = await ref.read(cmsMediaRepositoryProvider).upload(
            name: result.files.single.name,
            bytes: result.files.single.bytes!,
          );
      if (!mounted) return;
      setState(() => target.text = asset.ref.url);
      _toast('$what uploaded. Review the preview, then Publish.');
    } catch (_) {
      _toast('$what upload failed. Check the file (PNG/JPG/WebP/GIF) and retry.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _refreshBranding() {
    ref.invalidate(appBrandingProvider);
    ref.invalidate(adminSettingsProvider);
    ref.invalidate(brandingHistoryProvider);
    ref.invalidate(brandingDraftProvider);
  }

  Future<void> _publish({
    String success = 'Global branding published across the app.',
    String label = 'Published',
  }) async {
    if (_hasErrors) {
      _toast('Fix the highlighted loading animation fields first.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Normalised through AppBranding so only valid values are stored; the
      // service also records history and clears the saved draft.
      await ref
          .read(brandingRevisionServiceProvider)
          .publish(_draft.toMap(), label: label);
      _refreshBranding();
      _toast(success, color: AppTheme.success);
    } catch (e) {
      _toast('Failed to update branding: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_hasErrors) {
      _toast('Fix the highlighted loading animation fields first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(brandingRevisionServiceProvider).saveDraft(_draft.toMap());
      ref.invalidate(brandingDraftProvider);
      _toast('Draft saved. Customers still see the published branding.');
    } catch (e) {
      _toast('Failed to save draft: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _loadDraft(BrandingDraft draft) {
    setState(() => _applyToForm(draft.branding));
    _toast('Draft loaded into the editor. Preview it, then Publish.');
  }

  Future<void> _discardDraft() async {
    try {
      await ref.read(brandingRevisionServiceProvider).discardDraft();
      ref.invalidate(brandingDraftProvider);
      _toast('Draft discarded.');
    } catch (e) {
      _toast('Failed to discard draft: $e');
    }
  }

  void _loadRevision(BrandingRevision revision) {
    setState(() => _applyToForm(revision.branding));
    _toast('Version loaded into the editor. Preview it, then Publish to restore.');
  }

  Future<void> _undoLastPublish() async {
    setState(() => _saving = true);
    try {
      final restored =
          await ref.read(brandingRevisionServiceProvider).undoLastPublish();
      if (restored == null) {
        _toast('Nothing to undo yet.');
        return;
      }
      if (mounted) setState(() => _applyToForm(AppBranding.fromMap(restored)));
      _refreshBranding();
      _toast('Last publish undone — previous branding is live.',
          color: AppTheme.success);
    } catch (e) {
      _toast('Undo failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetLogo() async {
    setState(() {
      _logoLightCtrl.clear();
      _logoDarkCtrl.clear();
    });
    await _publish(
      success: 'Logo reset to the bundled BookMySpace logo.',
      label: 'Reset logo',
    );
  }

  Future<void> _resetAnimation() async {
    setState(() {
      _animationEnabled = AppBranding.defaultAnimationEnabled;
      _animationColorCtrl.clear();
      _animationThicknessCtrl.text = AppBranding.defaultAnimationThickness.toString();
      _animationAssetCtrl.clear();
    });
    await _publish(
      success: 'Loading animation reset to defaults.',
      label: 'Reset animation',
    );
  }

  Widget _logoField({
    required ValueKey<String> key,
    required TextEditingController controller,
    required String label,
    bool animatedOnly = false,
    String uploadWhat = 'Logo',
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: key,
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'https://...',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.filledTonal(
            key: ValueKey('${key.value}-media'),
            tooltip: 'Choose from Media library',
            onPressed: _uploading || _saving
                ? null
                : () => _chooseFromMedia(controller, animatedOnly: animatedOnly),
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton.filledTonal(
            tooltip: 'Upload $uploadWhat',
            onPressed: _uploading || _saving
                ? null
                : () => _uploadMedia(controller, what: uploadWhat),
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
          ),
        ),
      ],
    );
  }

  Widget _previewTile({required String label, required bool dark, required AppBranding draft}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BookMySpaceMark(
            key: ValueKey('branding-preview-logo-${dark ? 'dark' : 'light'}'),
            size: 56,
            logoUrlOverride: draft.logoForBrightness(dark),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: dark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;
    final busy = _saving || _uploading;

    final savedDraft = ref.watch(brandingDraftProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (savedDraft != null)
          Card(
            key: const ValueKey('branding-draft-banner'),
            color: theme.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Unpublished draft saved'),
              subtitle: Text(
                savedDraft.savedAt == null
                    ? 'Not visible to customers until published.'
                    : 'Saved ${_formatWhen(savedDraft.savedAt!)} · not visible to customers until published.',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    key: const ValueKey('branding-draft-load'),
                    onPressed: busy ? null : () => _loadDraft(savedDraft),
                    child: const Text('Load'),
                  ),
                  TextButton(
                    key: const ValueKey('branding-draft-discard'),
                    onPressed: busy ? null : _discardDraft,
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Global App Brand & Logos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Changes propagate to splash, login, home headers and every other place the global logo appears.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _appNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'App Name (Default: BookMySpace)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taglineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tagline',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _logoField(
                  key: const ValueKey('branding-logo-light'),
                  controller: _logoLightCtrl,
                  label: 'Logo Image URL (Light theme)',
                ),
                const SizedBox(height: 12),
                _logoField(
                  key: const ValueKey('branding-logo-dark'),
                  controller: _logoDarkCtrl,
                  label: 'Logo Image URL (Dark theme, optional)',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _splashCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Splash Artwork URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstColorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Wordmark Primary Color (#3F51B5)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _restColorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Wordmark Secondary Color',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Loading animation settings
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loading Animation',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      // Own Material so the tile's ink is not hidden by the
                      // tinted container (ListTile debug assertion).
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          key: const ValueKey('branding-animation-enabled'),
                          title: const Text('Enable Loading Animation'),
                          subtitle: const Text('Show the loading animation on the splash/loading screen'),
                          value: _animationEnabled,
                          onChanged: (val) => setState(() => _animationEnabled = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (_animationEnabled) ...[
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('branding-animation-color'),
                          controller: _animationColorCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Spinner Color (Hex, e.g. #FF5733)',
                            helperText: 'Leave empty to use the brand colour',
                            errorText: _animationColorError,
                            border: const OutlineInputBorder(),
                            hintText: '#FF5733',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('branding-animation-thickness'),
                          controller: _animationThicknessCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText:
                                'Spinner Thickness (${AppBranding.minAnimationThickness} - ${AppBranding.maxAnimationThickness})',
                            errorText: _animationThicknessError,
                            border: const OutlineInputBorder(),
                            hintText: '${AppBranding.defaultAnimationThickness}',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        _logoField(
                          key: const ValueKey('branding-animation-asset'),
                          controller: _animationAssetCtrl,
                          label: 'Animation asset (GIF / animated WebP, optional)',
                          animatedOnly: true,
                          uploadWhat: 'Animation',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'When set, this Media asset replaces the spinner '
                          '(colour/thickness then apply only as fallback).',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Live preview of the unpublished draft
                const Text(
                  'Preview (not yet published)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _previewTile(label: 'Light logo', dark: false, draft: draft),
                    _previewTile(label: 'Dark logo', dark: true, draft: draft),
                    Container(
                      key: const ValueKey('branding-preview-spinner'),
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 84,
                            child: Center(
                              child: _hasErrors
                                  ? const Icon(Icons.error_outline, color: Colors.red)
                                  : BrandLoadingIndicator(branding: draft, size: 40),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            !draft.animationEnabled
                                ? 'Animation disabled'
                                : (draft.animationAssetUrl != null
                                      ? 'Animation asset'
                                      : 'Spinner'),
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('branding-reset-logo'),
                      onPressed: busy ? null : _resetLogo,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset Logo'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('branding-reset-animation'),
                      onPressed: busy ? null : _resetAnimation,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset Animation'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('branding-save-draft'),
                      onPressed: busy || _hasErrors ? null : _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Draft'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('branding-publish'),
                      onPressed: busy || _hasErrors ? null : _publish,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.publish_rounded),
                      label: const Text('Publish Global Branding'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _BrandingHistoryCard(
          busy: busy,
          onLoad: _loadRevision,
          onUndo: _undoLastPublish,
        ),
      ],
    );
  }
}

String _formatWhen(DateTime at) {
  final l = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// Published-version history for global branding (logo + loading animation).
/// "Load" puts a version into the editor for preview; "Undo last publish"
/// immediately re-publishes the version before the current one.
class _BrandingHistoryCard extends ConsumerWidget {
  const _BrandingHistoryCard({
    required this.busy,
    required this.onLoad,
    required this.onUndo,
  });

  final bool busy;
  final ValueChanged<BrandingRevision> onLoad;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(brandingHistoryProvider);
    return Card(
      key: const ValueKey('branding-history'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Branding History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('branding-undo'),
                  onPressed: busy || (history.valueOrNull?.length ?? 0) < 2
                      ? null
                      : onUndo,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Undo last publish'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load history: $e'),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Text(
                    'No published versions yet. Every publish / reset is recorded here.',
                    style: TextStyle(fontSize: 12),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      ListTile(
                        key: ValueKey('branding-history-$i'),
                        contentPadding: EdgeInsets.zero,
                        leading: BookMySpaceMark(
                          size: 36,
                          logoUrlOverride: entries[i].branding.logoUrl,
                        ),
                        title: Text(
                          i == 0 ? '${entries[i].label} (live)' : entries[i].label,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (entries[i].publishedAt != null)
                              _formatWhen(entries[i].publishedAt!),
                            entries[i].branding.logoUrl == null
                                ? 'bundled logo'
                                : 'custom logo',
                            !entries[i].branding.animationEnabled
                                ? 'animation off'
                                : (entries[i].branding.animationAssetUrl != null
                                      ? 'animation asset'
                                      : 'spinner'),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: TextButton(
                          onPressed: busy ? null : () => onLoad(entries[i]),
                          child: const Text('Load'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks an existing asset from the CMS Media library.
class _MediaPickerDialog extends ConsumerWidget {
  const _MediaPickerDialog({this.animatedOnly = false});

  /// Only show formats Flutter can animate (GIF / WebP).
  final bool animatedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(cmsMediaAssetsProvider(''));
    return AlertDialog(
      title: Text(animatedOnly ? 'Choose animation from Media' : 'Choose image from Media'),
      content: SizedBox(
        width: 480,
        height: 360,
        child: assets.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load Media: $e')),
          data: (all) {
            final items = all.where((a) {
              if (!a.isImage) return false;
              if (!animatedOnly) return true;
              final ext = a.name.split('.').last.toLowerCase();
              return ext == 'gif' || ext == 'webp';
            }).toList();
            if (items.isEmpty) {
              return const Center(
                child: Text('No matching media yet. Use Upload instead.'),
              );
            }
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 110,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => InkWell(
                key: ValueKey('media-pick-$i'),
                onTap: () => Navigator.pop(context, items[i].ref.url),
                child: Tooltip(
                  message: items[i].name,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: AppNetworkImage(url: items[i].ref.url, fit: BoxFit.contain),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
