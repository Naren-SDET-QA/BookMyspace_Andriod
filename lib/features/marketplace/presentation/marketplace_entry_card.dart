import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/marketplace_strings.dart';
import '../../../core/router/app_router.dart';

/// A section entry, preserving the existing Home and navigation destinations.
class MarketplaceEntryCard extends StatelessWidget {
  const MarketplaceEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      color: colors.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('marketplace-entry'),
        onTap: () => context.navigateSafely(AppRoutes.marketplace),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.local_activity_outlined,
                size: 32,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.marketplaceText('marketplace'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.marketplaceText('marketplaceEntry'),
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
