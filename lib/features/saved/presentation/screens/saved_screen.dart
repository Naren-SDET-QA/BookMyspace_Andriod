import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Saved (favourited) venues.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedVenues)),
      body: user == null
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Sign in to save venues',
              message: 'Your saved spaces will appear here after you sign in.',
              action: FilledButton(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text('Sign in'),
              ),
            )
          : favorites.when(
              data: (venues) {
                if (venues.isEmpty) {
                  return const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No saved venues yet',
                    message: 'Tap the heart on any venue to keep it here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(favoritesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => VenueCard(venue: venues[i]),
                  ),
                );
              },
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(favoritesProvider),
              ),
            ),
    );
  }
}
