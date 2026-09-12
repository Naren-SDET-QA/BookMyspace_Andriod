import 'package:flutter/material.dart';

import '../../../../core/features/feature_registry.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';

/// Catalog of independently described product modules.
///
/// Enablement is configuration. It does not grant owner/admin privileges.
class FeaturesHubScreen extends StatelessWidget {
  const FeaturesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modules = FeatureRegistry.product.modules;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featuresHub)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.featuresHubSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...modules.map((module) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  module.enabled
                      ? Icons.extension_rounded
                      : Icons.extension_off_outlined,
                  color: module.enabled
                      ? AppColors.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(module.name),
                subtitle: Text(
                  module.enabled
                      ? l10n.featureEnabled
                      : l10n.featureDisabledUntilBackend,
                ),
                trailing: Text(
                  module.enabled ? l10n.onLabel : l10n.offLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: module.enabled
                        ? AppColors.primaryDark
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
