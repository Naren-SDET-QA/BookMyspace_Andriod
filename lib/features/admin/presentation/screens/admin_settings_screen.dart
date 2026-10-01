import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/notifications/onesignal_push_service.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/admin_settings.dart';
import '../admin_settings_providers.dart';
import '../widgets/app_install_section.dart';
import '../widgets/platform_finance_section.dart';
import '../widgets/platform_status_section.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../promotions/presentation/widgets/existing_media_picker.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin settings'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminSettingsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Settings unavailable.')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PlatformStatusSection(),
            const PlatformFinanceSection(),
            _BrandingSection(settings: settings),
            _HomeSection(settings: settings),
            _ThemeSection(settings: settings),
            _ModuleSection(settings: settings),
            _PushSection(settings: settings),
            AppInstallSection(
              install: settings.install,
              onSave: (values) async {
                await ref
                    .read(adminSettingsRepositoryProvider)
                    .saveSection(AdminSettings.installSection, values);
                ref.invalidate(adminSettingsProvider);
              },
            ),
            const _ExistingSettingsLinks(),
          ],
        ),
      ),
    );
  }
}

class _BrandingSection extends ConsumerStatefulWidget {
  const _BrandingSection({required this.settings});
  final AdminSettings settings;
  @override
  ConsumerState<_BrandingSection> createState() => _BrandingSectionState();
}

class _BrandingSectionState extends ConsumerState<_BrandingSection> {
  late Map<String, dynamic> values;

  @override
  void initState() {
    super.initState();
    values = {
      'app_name': widget.settings.branding['app_name'] ?? 'BookMySpace',
      'tagline': widget.settings.branding['tagline'] ?? '',
      'logo_url': widget.settings.branding['logo_url'] ?? '',
      'logo_dark_url': widget.settings.branding['logo_dark_url'] ?? '',
      'splash_url': widget.settings.branding['splash_url'] ?? '',
      'wordmark_first_color':
          widget.settings.branding['wordmark_first_color'] ?? '#3F51B5',
      'wordmark_rest_color':
          widget.settings.branding['wordmark_rest_color'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    String str(String key) => values[key]?.toString() ?? '';
    return _SectionCard(
      title: 'Branding & logo (entire app)',
      children: [
        const Text(
          'Logo, splash and app name update everywhere the brand lockup is used. '
          'Leave an image blank to keep the bundled asset.',
        ),
        const SizedBox(height: 8),
        if (str('logo_url').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                str('logo_url').trim(),
                height: 72,
                errorBuilder: (_, _, _) =>
                    const Text('Logo URL could not be loaded.'),
              ),
            ),
          ),
        for (final item in const [
          ('app_name', 'App name (e.g. BookMySpace)'),
          ('tagline', 'Tagline'),
          ('logo_url', 'Logo image URL (light)'),
          ('logo_dark_url', 'Logo image URL (dark, optional)'),
          ('splash_url', 'Splash image URL (optional)'),
          ('wordmark_first_color', 'Wordmark color (#RRGGBB)'),
          ('wordmark_rest_color', 'Wordmark middle color (optional)'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              initialValue: str(item.$1),
              decoration: InputDecoration(
                labelText: item.$2,
                suffixIcon: item.$1 == 'logo_url' && str(item.$1).isNotEmpty
                    ? IconButton(
                        tooltip: 'Restore bundled logo',
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        onPressed: () =>
                            setState(() => values[item.$1] = ''),
                      )
                    : null,
              ),
              onChanged: (v) => values[item.$1] = v,
            ),
          ),
        _SaveButton(section: AdminSettings.brandingSection, values: values),
      ],
    );
  }
}

class _HomeSection extends ConsumerStatefulWidget {
  const _HomeSection({required this.settings});
  final AdminSettings settings;
  @override
  ConsumerState<_HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends ConsumerState<_HomeSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.home};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Home UI',
    children: [
      for (final item in const [
        ('search_placeholder', 'Search placeholder'),
        ('hero_title', 'Hero title'),
        ('hero_subtitle', 'Hero subtitle'),
        ('primary_booking_button_text', 'Primary booking button'),
        ('banner_text', 'Banner text'),
        ('banner_media_url', 'Banner media URL'),
      ])
        TextFormField(
          initialValue: values[item.$1]?.toString() ?? '',
          decoration: InputDecoration(labelText: item.$2),
          onFieldSubmitted: (v) => setState(
            () => values[item.$1] = AdminSettings.text(
              v,
              AdminSettings.defaults.home[item.$1]!.toString(),
            ),
          ),
        ),
      FutureBuilder<List<String>>(
        future: ref
            .read(supabaseProvider)
            .from('venues')
            .select('id')
            .then(
              (rows) =>
                  (rows as List).map((row) => row['id'].toString()).toList(),
            ),
        builder: (context, snapshot) => ExistingMediaPicker(
          venueIds: snapshot.data ?? const [],
          selectedId: values['banner_media_id']?.toString(),
          onSelected: (media) => setState(() {
            values['banner_media_id'] = media.id;
            values['banner_media_url'] = media.url;
          }),
          onRemoved: () => setState(() {
            values.remove('banner_media_id');
            values.remove('banner_media_url');
          }),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: switch (values['home_layout']?.toString()) {
          'modern' => 'modern',
          'premium' => 'premium',
          'moment' => 'moment',
          'life' => 'life',
          _ => 'glass',
        },
        decoration: const InputDecoration(
          labelText: 'Home layout',
          helperText: 'Every admin can choose the Home customers see.',
        ),
        items: const [
          DropdownMenuItem(
            value: 'glass',
            child: Text('Glass — current Home (default)'),
          ),
          DropdownMenuItem(
            value: 'moment',
            child: Text('Moment — Your Space for Every Moment'),
          ),
          DropdownMenuItem(
            value: 'life',
            child: Text('Life — Spaces for Your Life'),
          ),
          DropdownMenuItem(
            value: 'modern',
            child: Text('Modern — new category-tile Home'),
          ),
          DropdownMenuItem(
            value: 'premium',
            child: Text('Premium — hero search, offers & recently viewed'),
          ),
        ],
        onChanged: (v) => setState(() => values['home_layout'] = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: values['bottom_nav_style']?.toString() == 'modern'
            ? 'modern'
            : 'classic',
        decoration: const InputDecoration(labelText: 'Bottom navigation'),
        items: const [
          DropdownMenuItem(
            value: 'classic',
            child: Text('Classic — current 6 tabs (default)'),
          ),
          DropdownMenuItem(
            value: 'modern',
            child: Text('Modern — Home, Explore, Bookings, Chat, Profile'),
          ),
        ],
        onChanged: (v) => setState(() => values['bottom_nav_style'] = v),
      ),
      const SizedBox(height: 8),
      for (final item in const [
        ('home_banner_visible', 'Home banner'),
        ('search_banner_visible', 'Search banner'),
        ('tile_spaces_visible', 'Tile: Spaces'),
        ('tile_institutes_visible', 'Tile: Institutes'),
        ('tile_classes_visible', 'Tile: Classes'),
        ('tile_pg_visible', 'Tile: PG / Hostels'),
        ('tile_stays_visible', 'Tile: Stays'),
        ('tile_shopping_visible', 'Tile: Shopping'),
        ('space_radar_visible', 'Your Space Radar'),
        ('activity_visible', 'Your Activity'),
      ])
        SwitchListTile(
          title: Text(item.$2),
          value: AdminSettings.flag(values[item.$1], fallback: true),
          onChanged: (v) => setState(() => values[item.$1] = v),
        ),
      _SaveButton(section: 'home_ui', values: values),
    ],
  );
}

class _ThemeSection extends StatefulWidget {
  const _ThemeSection({required this.settings});
  final AdminSettings settings;
  @override
  State<_ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<_ThemeSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.theme};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Theme and colors',
    children: [
      for (final key in const [
        'primary_color',
        'accent_color',
        'banner_background',
        'banner_text_color',
      ])
        TextFormField(
          initialValue: values[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: key.replaceAll('_', ' ')),
          onFieldSubmitted: (v) {
            if (AdminSettings.validHex(v)) setState(() => values[key] = v);
          },
        ),
      const Text(
        'Invalid colors keep the previous value and never affect app startup.',
      ),
      _SaveButton(section: 'theme', values: values),
    ],
  );
}

class _ModuleSection extends StatefulWidget {
  const _ModuleSection({required this.settings});
  final AdminSettings settings;
  @override
  State<_ModuleSection> createState() => _ModuleSectionState();
}

class _ModuleSectionState extends State<_ModuleSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.modules};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Modules',
    children: [
      for (final key in const [
        'promotions',
        'media',
        'location',
        'availability',
        'payments',
        'check_in',
      ])
        SwitchListTile(
          title: Text(key),
          value: AdminSettings.flag(values[key]),
          onChanged: (v) => setState(() => values[key] = v),
        ),
      _SaveButton(section: 'modules', values: values),
    ],
  );
}

/// Admin settings -> Push Notifications / OneSignal.
///
/// Only the on/off switch is stored (module_feature_configs, module_key
/// `push_notifications`). The OneSignal App ID comes from the build
/// environment (ONESIGNAL_APP_ID); the REST API key is a Supabase Edge
/// Function secret and is never entered or shown here.
class _PushSection extends StatefulWidget {
  const _PushSection({required this.settings});
  final AdminSettings settings;
  @override
  State<_PushSection> createState() => _PushSectionState();
}

class _PushSectionState extends State<_PushSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.push};
  }

  @override
  Widget build(BuildContext context) {
    final appIdConfigured = OneSignalPushService.isValidAppId(
      AppConfig.oneSignalAppId,
    );
    return _SectionCard(
      title: 'Push Notifications / OneSignal',
      children: [
        SwitchListTile(
          key: const ValueKey('admin_push_onesignal_switch'),
          title: const Text('Enable OneSignal push notifications'),
          subtitle: Text(
            appIdConfigured
                ? 'OneSignal App ID is configured for this build.'
                : 'ONESIGNAL_APP_ID is not configured for this build, so '
                      'push stays off even when enabled.',
          ),
          value: AdminSettings.flag(values[AdminSettings.pushEnabledKey]),
          onChanged: (v) =>
              setState(() => values[AdminSettings.pushEnabledKey] = v),
        ),
        const Text(
          'When off, OneSignal is not initialised and devices are not '
          'registered. Turning it off stops delivery immediately; the SDK is '
          'fully unloaded on the next app launch.',
        ),
        _SaveButton(section: AdminSettings.pushSection, values: values),
      ],
    );
  }
}

class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.section, required this.values});
  final String section;
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () async {
            final defaults = switch (section) {
              'home_ui' => AdminSettings.defaults.home,
              'theme' => AdminSettings.defaults.theme,
              'branding' => const <String, dynamic>{
                'app_name': 'BookMySpace',
                'tagline': '',
                'logo_url': '',
                'logo_dark_url': '',
                'splash_url': '',
                'wordmark_first_color': '#3F51B5',
                'wordmark_rest_color': '',
              },
              _ => const <String, dynamic>{},
            };
            if (defaults.isEmpty) return;
            try {
              await ref
                  .read(adminSettingsRepositoryProvider)
                  .saveSection(section, defaults);
              ref.invalidate(adminSettingsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Defaults restored')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Defaults could not be restored'),
                  ),
                );
              }
            }
          },
          child: const Text('Reset/default'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(adminSettingsRepositoryProvider)
                  .saveSection(section, values);
              ref.invalidate(adminSettingsProvider);
              if (context.mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Settings saved')));
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings could not be saved')),
                );
            }
          },
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(title),
      childrenPadding: const EdgeInsets.all(16),
      children: children,
    ),
  );
}

class _ExistingSettingsLinks extends StatelessWidget {
  const _ExistingSettingsLinks();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _LinkCard(
        'App Studio — edit everything',
        'Logo, any text/image/field, banners, sections and theme in one hub',
        AppRoutes.adminAppStudio,
      ),
      _LinkCard(
        'Live element editor',
        'Any text, image, field, link, color or visibility on any screen',
        AppRoutes.adminUiElementOverrides,
      ),
      _LinkCard(
        'Authentication',
        'Auth providers and dependency rules',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Categories and modules',
        'Category-level capability controls',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Promotions',
        'Offers, banners, targeting and media',
        AppRoutes.adminPromotions,
      ),
      _LinkCard(
        'Booking, Location and Payments',
        'Existing authoritative configuration screens',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Media',
        'Owner media manager and storage controls',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Policies and Tax & Fees',
        'Use existing business configuration; pricing remains server-authoritative',
        AppRoutes.adminBusinessPricing,
      ),
      _LinkCard(
        'App Health',
        'Diagnostics and safe recovery status',
        AppRoutes.adminHealth,
      ),
    ],
  );
}

class _LinkCard extends StatelessWidget {
  const _LinkCard(this.title, this.subtitle, this.route);
  final String title;
  final String subtitle;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
