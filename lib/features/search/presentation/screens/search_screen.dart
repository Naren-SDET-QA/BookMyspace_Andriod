import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../widgets/voice_search_bottom_sheet.dart';

/// Search screen: text query + category chips + sort/filter sheet.
///
/// The working query is derived from the current route (query parameters,
/// with `extra` as fallback). User actions write by replacing the route,
/// never by mutating a shared provider during widget construction.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialCategory,
    this.initialQuery = '',
    this.routeQuery,
  });

  /// Preselected category slug (set when navigating from home chips).
  final String? initialCategory;

  /// Preselected free-text query from the route.
  final String initialQuery;

  /// Full query parsed by the router. Preferred over the individual fields.
  final VenueSearchQuery? routeQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  VenueSearchQuery? _detachedQuery;
  String? _syncedRouteQueryText;

  @override
  void initState() {
    super.initState();
    final initial = _constructorQuery();
    _controller = TextEditingController(text: initial.query);
    _syncedRouteQueryText = initial.query;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final routeQuery =
        SearchRouteParams.fromGoRouterState(GoRouterState.of(context))
            .toQuery();
    if (_syncedRouteQueryText == routeQuery.query) return;
    _syncedRouteQueryText = routeQuery.query;
    if (_controller.text == routeQuery.query) return;
    _controller.value = TextEditingValue(
      text: routeQuery.query,
      selection: TextSelection.collapsed(offset: routeQuery.query.length),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  VenueSearchQuery _constructorQuery() {
    return widget.routeQuery ??
        VenueSearchQuery(
          query: widget.initialQuery,
          categorySlug: widget.initialCategory,
        );
  }

  VenueSearchQuery _effectiveQuery() {
    final routeQuery = GoRouter.maybeOf(context) != null
        ? SearchRouteParams.fromGoRouterState(GoRouterState.of(context))
            .toQuery()
        : _detachedQuery ?? _constructorQuery();
    return ref.watch(discoveryLocationProvider).mergeInto(routeQuery);
  }

  void _commitQuery(VenueSearchQuery query) {
    if (GoRouter.maybeOf(context) == null) {
      if (_detachedQuery == query) return;
      setState(() => _detachedQuery = query);
      return;
    }
    final current =
        SearchRouteParams.fromGoRouterState(GoRouterState.of(context))
            .toQuery();
    if (current == query) return;
    context.go(SearchRouteParams.locationFor(query));
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _commitQuery(_effectiveQuery().copyWith(query: value.trim()));
    });
  }

  void _clearFilters() {
    _controller.clear();
    _commitQuery(const VenueSearchQuery());
  }

  void _openVoiceSearch() {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (voiceResult) {
        final newQuery = voiceResult.toVenueSearchQuery();
        if (voiceResult.isClearCommand) {
          _controller.clear();
        } else if (voiceResult.cleanedSearchQuery.isNotEmpty) {
          _controller.text = voiceResult.cleanedSearchQuery;
        }
        _commitQuery(newQuery);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎙️ '),
                Expanded(
                  child: Text(
                    voiceResult.spokenFeedback.isNotEmpty
                        ? voiceResult.spokenFeedback
                        : 'Voice search filter applied!',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onFallbackToText: () {
        _searchFocusNode.requestFocus();
      },
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom;
        final maxHeight = media.size.height * 0.88;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: maxHeight,
            child: _FilterSheet(
              initial: _effectiveQuery(),
              categories: ref.read(venueCategoriesProvider).value ?? const [],
              onApply: _commitQuery,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _effectiveQuery();
    final results = ref.watch(searchResultsProvider(query));
    final categories = ref.watch(venueCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Live Map Discovery',
            onPressed: () => context.push(
              SearchRouteParams.mapLocationFor(query),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _searchFocusNode,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (query.hasFilters || _controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: _clearFilters,
                              tooltip: 'Clear search',
                            ),
                          IconButton(
                            icon: const Icon(Icons.mic_rounded,
                                color: AppTheme.brand),
                            onPressed: _openVoiceSearch,
                            tooltip: 'Voice Search',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: query.hasFilters,
                    child: const Icon(Icons.tune_rounded),
                  ),
                  tooltip: l10n.filters,
                ),
              ],
            ),
          ),
          if (query.city != null ||
              query.pincode != null ||
              query.hasCoordinates)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(
                    query.hasCoordinates
                        ? Icons.my_location_rounded
                        : Icons.location_on_outlined,
                    size: 18,
                    color: AppTheme.brand,
                  ),
                  label: Text(
                    [
                      if (query.city != null && query.city!.trim().isNotEmpty)
                        query.city!.trim(),
                      if (query.pincode != null &&
                          query.pincode!.trim().isNotEmpty)
                        'PIN ${query.pincode!.trim()}',
                      if (query.hasCoordinates)
                        '${query.radiusKm ?? 10} km',
                    ].join(' • '),
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedCategoryChip(
                    label: l10n.allCategories,
                    selected: query.categorySlug == null,
                    onTap: () {
                      _commitQuery(query.copyWith(categorySlug: () => null));
                    },
                  ),
                ),
                ...?categories.value?.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedCategoryChip(
                      label: c.name,
                      emoji: c.icon,
                      selected: query.categorySlug == c.slug,
                      onTap: () {
                        _commitQuery(
                          query.copyWith(categorySlug: () => c.slug),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              data: (venues) {
                if (venues.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No results found',
                    message:
                        'Try a different keyword, category or price range.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: venues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      VenueCard(venue: venues[i], entranceIndex: i),
                );
              },
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(searchResultsProvider(query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet filter panel for sorting, price range and category.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.categories,
    required this.onApply,
  });

  final VenueSearchQuery initial;
  final List<VenueCategory> categories;
  final void Function(VenueSearchQuery) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late VenueSortBy _sortBy;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _categorySlug;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initial.sortBy;
    _categorySlug = widget.initial.categorySlug;
    _minController = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
      return;
    }
    Navigator.of(context).pop();
  }

  void _apply() {
    final updated = widget.initial.copyWith(
      sortBy: _sortBy,
      categorySlug: () => _categorySlug,
      minPrice: () => double.tryParse(_minController.text),
      maxPrice: () => double.tryParse(_maxController.text),
    );
    widget.onApply(updated);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('filters_back'),
                  tooltip: 'Back',
                  onPressed: _close,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    l10n.filters,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('filters_clear'),
                  onPressed: () {
                    setState(() {
                      _sortBy = VenueSortBy.relevance;
                      _categorySlug = null;
                      _minController.clear();
                      _maxController.clear();
                    });
                  },
                  child: Text(l10n.clearFilters),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(l10n.sortBy, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SortChip(
                          label: l10n.relevance,
                          selected: _sortBy == VenueSortBy.relevance,
                          onTap: () =>
                              setState(() => _sortBy = VenueSortBy.relevance),
                        ),
                        _SortChip(
                          label: l10n.priceLowToHigh,
                          selected: _sortBy == VenueSortBy.priceAsc,
                          onTap: () =>
                              setState(() => _sortBy = VenueSortBy.priceAsc),
                        ),
                        _SortChip(
                          label: l10n.priceHighToLow,
                          selected: _sortBy == VenueSortBy.priceDesc,
                          onTap: () =>
                              setState(() => _sortBy = VenueSortBy.priceDesc),
                        ),
                        _SortChip(
                          label: l10n.topRated,
                          selected: _sortBy == VenueSortBy.rating,
                          onTap: () =>
                              setState(() => _sortBy = VenueSortBy.rating),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.allCategories, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AnimatedCategoryChip(
                          label: l10n.allCategories,
                          selected: _categorySlug == null,
                          onTap: () => setState(() => _categorySlug = null),
                        ),
                        ...widget.categories.map(
                          (c) => AnimatedCategoryChip(
                            label: c.name,
                            emoji: c.icon,
                            selected: _categorySlug == c.slug,
                            onTap: () =>
                                setState(() => _categorySlug = c.slug),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.pricing, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('filters_min_price'),
                            controller: _minController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.minPrice,
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('filters_max_price'),
                            controller: _maxController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.maxPrice,
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('filters_apply'),
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(l10n.apply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
