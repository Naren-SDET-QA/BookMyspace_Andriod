import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_providers.dart';

/// Settings screen: theme, language and account management entry points.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.settings,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Appearance section
          _SectionHeader(label: 'Appearance'),
          const SizedBox(height: 8),
          _GlassSettingsTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: AppTheme.violet,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.home3dEffects,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        l10n.home3dEffectsSubtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: ref.watch(home3dEffectsProvider),
                  onChanged: (enabled) => ref
                      .read(home3dEffectsProvider.notifier)
                      .setEnabled(enabled),
                  activeThumbColor: AppTheme.violet,
                ),
              ],
            ),
          ),
          _GlassSettingsTile(
            icon: Icons.language_rounded,
            iconColor: AppTheme.violet,
            onTap: () => _showLanguagePicker(context, ref),
            title: l10n.language,
            subtitle: locale.languageCode.toUpperCase(),
          ),
          _GlassSettingsTile(
            icon: Icons.extension_outlined,
            iconColor: AppTheme.violet,
            onTap: () => context.push(AppRoutes.featuresHub),
            title: l10n.featuresHub,
            subtitle: l10n.featuresHubSubtitle,
          ),
          const SizedBox(height: 20),

          // Support section
          _SectionHeader(label: 'Support'),
          const SizedBox(height: 8),
          _GlassSettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: AppTheme.violet,
            onTap: () => context.push(AppRoutes.notifications),
            title: l10n.notifications,
          ),
          _GlassSettingsTile(
            icon: Icons.support_agent_rounded,
            iconColor: AppTheme.violet,
            onTap: () => context.push(AppRoutes.support),
            title: l10n.support,
          ),
          const SizedBox(height: 20),

          // Legal section
          _SectionHeader(label: 'Legal'),
          const SizedBox(height: 8),
          _GlassSettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.violet,
            onTap: () => context.push(AppRoutes.privacyPolicy),
            title: l10n.privacyPolicy,
          ),
          _GlassSettingsTile(
            icon: Icons.description_outlined,
            iconColor: AppTheme.violet,
            onTap: () => context.push(AppRoutes.termsOfService),
            title: l10n.termsAndConditions,
          ),
          _GlassSettingsTile(
            icon: Icons.info_outline,
            iconColor: AppTheme.violet,
            onTap: () => _showAboutDialog(context, l10n),
            title: l10n.about,
          ),
          const SizedBox(height: 20),

          // Danger zone
          _SectionHeader(label: 'Account'),
          const SizedBox(height: 8),
          _GlassSettingsTile(
            icon: Icons.delete_forever_outlined,
            iconColor: theme.colorScheme.error,
            onTap: () => _confirmDeleteAccount(context, ref, l10n),
            title: l10n.deleteAccount,
            titleColor: theme.colorScheme.error,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('తెలుగు'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('te'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('हिन्दी'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('hi'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('ಕನ್ನಡ'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('kn'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('தமிழ்'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('ta'));
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showAboutDialog(
      context: context,
      applicationName: l10n.appName,
      applicationVersion: '1.0.0',
      children: [Text(l10n.tagline)],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmation = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final typedDelete =
                confirmation.text.trim().toUpperCase() == 'DELETE';
            return AlertDialog(
              title: Text(l10n.deleteAccount),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently deletes your BookMySpace account and signed-in data. Type DELETE to confirm.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmation,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: typedDelete
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(l10n.delete),
                ),
              ],
            );
          },
        );
      },
    );
    confirmation.dispose();
    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final retry = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteAccount),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        if (retry == true && context.mounted) {
          await _confirmDeleteAccount(context, ref, l10n);
        }
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _GlassSettingsTile extends StatelessWidget {
  const _GlassSettingsTile({
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.title,
    this.subtitle,
    this.titleColor,
    this.child,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final String? title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 12),
                if (child != null)
                  Expanded(child: child!)
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: titleColor,
                            ),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (onTap != null && child == null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
