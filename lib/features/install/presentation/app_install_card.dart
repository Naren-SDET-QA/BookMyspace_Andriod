import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin/domain/app_install_config.dart';
import '../../admin/presentation/admin_settings_providers.dart';
import '../infrastructure/web_install_prompt.dart';

/// Customer install actions chosen by an admin. Renders nothing when every
/// option is off or none of them apply to this device.
class AppInstallCard extends ConsumerWidget {
  const AppInstallCard({super.key, this.surface});

  /// Test override. Production uses the device the app is running on.
  final AppInstallSurface? surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminSettingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    final config = AppInstallConfig.fromMap(settings.install);
    final where = surface ?? currentAppInstallSurface();
    final choices = config.choicesFor(
      where,
      webInstalled: WebInstallPrompt.isInstalled,
    );
    if (choices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const Key('app-install-card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.download_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.displayTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.displayMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final choice in choices) ...[
                _InstallButton(choice: choice, config: config, surface: where),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallButton extends StatelessWidget {
  const _InstallButton({
    required this.choice,
    required this.config,
    required this.surface,
  });

  final AppInstallChoice choice;
  final AppInstallConfig config;
  final AppInstallSurface surface;

  @override
  Widget build(BuildContext context) {
    final (key, label, icon, filled) = switch (choice) {
      AppInstallChoice.web => (
        const Key('app-install-web'),
        surface == AppInstallSurface.webIos
            ? 'Add to Home Screen'
            : 'Install web app',
        Icons.language_rounded,
        true,
      ),
      AppInstallChoice.play => (
        const Key('app-install-play'),
        'Get it on Google Play',
        Icons.shop_rounded,
        false,
      ),
      AppInstallChoice.apk => (
        const Key('app-install-apk'),
        'Download APK',
        Icons.android_rounded,
        false,
      ),
    };
    final onPressed = switch (choice) {
      AppInstallChoice.web => () => _offerWebInstall(context, surface),
      AppInstallChoice.play => () => _openHttps(context, config.playStoreUrl),
      AppInstallChoice.apk => () => _openHttps(context, config.apkUrl),
    };
    if (filled) {
      return FilledButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

Future<void> _offerWebInstall(
  BuildContext context,
  AppInstallSurface surface,
) async {
  if (surface == AppInstallSurface.webIos) {
    await _showInstallHelp(
      context,
      'In Safari, tap the Share button, then Add to Home Screen.',
    );
    return;
  }
  final outcome = await WebInstallPrompt.prompt();
  if (!context.mounted) return;
  if (outcome == 'accepted' || outcome == 'dismissed') return;
  await _showInstallHelp(
    context,
    'Open the browser menu and choose Install app or Add to Home Screen.',
  );
}

Future<void> _showInstallHelp(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Install the web app'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _openHttps(BuildContext context, String raw) async {
  if (!isHttpsUrl(raw)) {
    _snack(context, 'This install link is not available.');
    return;
  }
  try {
    final opened = await launchUrl(
      Uri.parse(raw.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _snack(context, 'Could not open the install link.');
    }
  } catch (_) {
    if (context.mounted) _snack(context, 'Could not open the install link.');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
