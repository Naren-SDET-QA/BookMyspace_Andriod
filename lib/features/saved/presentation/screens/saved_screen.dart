import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../domain/saved_item.dart';
import '../../domain/saved_venue_filter.dart';
import '../saved_items_providers.dart';
import '../widgets/saved_listings_tab.dart';

/// Saved (favourited) venues with search (name / city) and a category
/// filter derived from the saved venues.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _categoryKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('favorites'));
    final user = ref.watch(currentUserProvider);
    final favorites = ref.watch(favoritesProvider);

    final Widget venuesBody = !enabled
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Favorites are unavailable',
              message:
                  'This optional module is currently disabled by the administrator.',
            )
          : user == null
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
                return _buildList(venues);
              },
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(favoritesProvider),
              ),
            );

    final savedIds = ref.watch(savedItemIdsProvider).valueOrNull ?? const {};
    final showEducation = enabled &&
        user != null &&
        savedIds.values.any((ids) => ids.isNotEmpty);
    final favoriteCount = favorites.valueOrNull?.length;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final favoritesTitle = !english
        ? l10n.savedVenues
        : favoriteCount == null
        ? 'Favorites'
        : 'Favorites ($favoriteCount)';
    if (!showEducation) {
      return Scaffold(
        appBar: AppBar(title: Text(favoritesTitle)),
        body: venuesBody,
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(english ? 'Favorites' : l10n.savedVenues),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Venues'),
              Tab(text: 'Courses'),
              Tab(text: 'Institutes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            venuesBody,
            const SavedListingsTab(type: SavedItemType.course),
            const SavedListingsTab(type: SavedItemType.institute),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Venue> venues) {
    final categories = SavedVenueFilter.categoriesOf(venues);
    final selectedKey =
        categories.any((c) => SavedVenueFilter.keyOf(c) == _categoryKey)
        ? _categoryKey
        : null;
    final visible = SavedVenueFilter.apply(
      venues,
      query: _query,
      categoryKey: selectedKey,
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(favoritesProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            sliver: SliverToBoxAdapter(
              child: TextField(
                key: const Key('saved-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search your favorites...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          if (categories.length > 1)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      key: const Key('saved-category-all'),
                      label: const Text('All'),
                      selected: selectedKey == null,
                      onSelected: (_) => setState(() => _categoryKey = null),
                    ),
                    for (final category in categories) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: Key(
                          'saved-category-${SavedVenueFilter.keyOf(category)}',
                        ),
                        label: Text(category.name),
                        selected:
                            selectedKey == SavedVenueFilter.keyOf(category),
                        onSelected: (_) => setState(
                          () => _categoryKey = SavedVenueFilter.keyOf(category),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No saved venues match',
                message: 'Try a different name, city or category.',
                action: OutlinedButton(
                  key: const Key('saved-reset-filters'),
                  onPressed: _resetFilters,
                  child: const Text('Reset filters'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => VenueCard(venue: visible[i]),
              ),
            ),
        ],
      ),
    );
  }
}
