import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/filter_checkbox_tile.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../../venues/domain/listing_template.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/town_fallback_provider.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../widgets/voice_search_bottom_sheet.dart';
import '../../../../core/widgets/category_icon_text.dart';

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
    final routeQuery = SearchRouteParams.fromGoRouterState(
      GoRouterState.of(context),
    ).toQuery();
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
        ? SearchRouteParams.fromGoRouterState(
            GoRouterState.of(context),
          ).toQuery()
        : _detachedQuery ?? _constructorQuery();
    return ref.watch(discoveryLocationProvider).mergeInto(routeQuery);
  }

  void _commitQuery(VenueSearchQuery query) {
    if (GoRouter.maybeOf(context) == null) {
      if (_detachedQuery == query) return;
      setState(() => _detachedQuery = query);
      return;
    }
    final current = SearchRouteParams.fromGoRouterState(
      GoRouterState.of(context),
    ).toQuery();
    if (current == query) return;
    context.go(SearchRouteParams.locationFor(query));
  }

  void _showGuestPicker(int current) {
    int guests = current;
    showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Number of Guests'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: guests > 1
                    ? () => setModalState(() => guests--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$guests',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: guests < 500
                    ? () => setModalState(() => guests++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, guests),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    ).then((picked) {
      if (picked != null && mounted) {
        ref.read(discoveryBookingPrefsProvider.notifier).setGuests(picked);
      }
    });
  }

  String _searchDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _commitQuery(_effectiveQuery().copyWith(query: value.trim()));
    });
  }

  /// Removable chips for filters that only voice search (or deep links)
  /// set: rating, guests, PG gender/sharing and amenities.
  List<Widget> _attributeChips(VenueSearchQuery query) {
    Widget chip(String label, VenueSearchQuery Function() without) {
      return InputChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        onDeleted: () => _commitQuery(without()),
      );
    }

    return [
      if (query.minRating != null)
        chip(
          '${query.minRating!.toStringAsFixed(1)}+ ★',
          () => query.copyWith(minRating: () => null),
        ),
      if (query.minStarRating != null)
        chip(
          '${query.minStarRating}★ hotel & up',
          () => query.copyWith(minStarRating: () => null),
        ),
      if (query.minCapacity != null)
        chip(
          '${query.minCapacity}+ guests',
          () => query.copyWith(minCapacity: () => null),
        ),
      if (query.maxCapacity != null)
        chip(
          'Up to ${query.maxCapacity} guests',
          () => query.copyWith(maxCapacity: () => null),
        ),
      if (query.gender != null)
        chip(switch (query.gender!.toLowerCase()) {
          'gents' => 'Gents',
          'ladies' => 'Ladies',
          'coliving' => 'Co-living',
          final other => other,
        }, () => query.copyWith(gender: () => null)),
      if (query.sharing != null)
        chip(switch (query.sharing!) {
          'single' => 'Single room',
          'double' => '2 sharing',
          'triple' => '3 sharing',
          final other => other,
        }, () => query.copyWith(sharing: () => null)),
      for (final amenity in (query.amenities.toList()..sort()))
        chip(
          _amenityLabels[amenity] ?? amenity,
          () =>
              query.copyWith(amenities: {...query.amenities}..remove(amenity)),
        ),
    ];
  }

  static const _amenityLabels = <String, String>{
    'ac': 'AC',
    'parking': 'Parking',
    'wifi': 'Wi-Fi',
    'catering': 'Catering',
    'food': 'Food',
    'pool': 'Pool',
    'lawn': 'Lawn / Garden',
    'power_backup': 'Power backup',
    'stage_sound': 'Stage & sound',
    'rooms': 'Guest rooms',
    'alcohol': 'Bar / drinks',
  };

  void _clearFilters() {
    _controller.clear();
    _commitQuery(const VenueSearchQuery());
  }

  void _openVoiceSearch() {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (voiceResult) {
        if (voiceResult.categorySlug == 'institutes_classes') {
          final query = voiceResult.cleanedSearchQuery.trim();
          context.go(
            query.isEmpty
                ? AppRoutes.education
                : '${AppRoutes.education}?q=${Uri.encodeQueryComponent(query)}',
          );
          return;
        }
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
      useRootNavigator: true,
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
              categories:
                  ref.read(venueCategoriesProvider).valueOrNull ?? const [],
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
    final bookingPrefs = ref.watch(discoveryBookingPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Live Map Discovery',
            onPressed: () =>
                context.push(SearchRouteParams.mapLocationFor(query)),
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
                            icon: const Icon(
                              Icons.mic_rounded,
                              color: AppTheme.violet,
                            ),
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
          _SearchFilterChips(
            query: query,
            onOpenFilters: _openFilters,
            onCommit: _commitQuery,
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
                    color: AppTheme.violet,
                  ),
                  label: Text(
                    [
                      if (query.city != null && query.city!.trim().isNotEmpty)
                        query.city!.trim(),
                      if (query.pincode != null &&
                          query.pincode!.trim().isNotEmpty)
                        'PIN ${query.pincode!.trim()}',
                      if (query.hasCoordinates) '${query.radiusKm ?? 10} km',
                    ].join(' • '),
                  ),
                ),
              ),
            ),
          if (_attributeChips(query).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  key: const Key('search_attribute_filters'),
                  spacing: 8,
                  runSpacing: 8,
                  children: _attributeChips(query),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event_rounded, size: 18),
                  label: Text(_searchDateLabel(bookingPrefs.day)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: bookingPrefs.day,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && mounted) {
                      ref
                          .read(discoveryBookingPrefsProvider.notifier)
                          .setDate(picked);
                    }
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_rounded, size: 18),
                  label: Text(
                    bookingPrefs.guests == 1
                        ? '1 Guest'
                        : '${bookingPrefs.guests} Guests',
                  ),
                  onPressed: () => _showGuestPicker(bookingPrefs.guests),
                ),
              ],
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
                ...?categories.valueOrNull?.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedCategoryChip(
                      label: c.name,
                      emoji: categoryIconOrNull(c.icon),
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
                  return _TownFallbackResults(
                    text: query.query,
                    categorySlug: query.categorySlug,
                  );
                }
                final section = CustomerSectionCatalog.fromAny(
                  query.categorySlug,
                );
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final responsive = ResponsiveInfo.fromConstraints(
                      constraints,
                    );
                    if (_usesCategoryRow(section)) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchTripContext(section: section!),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: venues.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  _categoryResultCard(section, venues[i]),
                            ),
                          ),
                        ],
                      );
                    }
                    if (responsive.resultsColumns <= 1) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: venues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            VenueCard(venue: venues[i], entranceIndex: i),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: responsive.resultsColumns,
                        mainAxisSpacing: responsive.gridSpacing,
                        crossAxisSpacing: responsive.gridSpacing,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: venues.length,
                      itemBuilder: (context, i) =>
                          VenueCard(venue: venues[i], entranceIndex: i),
                    );
                  },
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

  bool _usesCategoryRow(CustomerSection? section) {
    return section == CustomerSection.lodgeRooms ||
        section == CustomerSection.functionHalls ||
        section == CustomerSection.pgHostels;
  }

  Widget _categoryResultCard(CustomerSection section, Venue venue) {
    return switch (section) {
      CustomerSection.lodgeRooms => HotelListCard(venue: venue),
      CustomerSection.functionHalls => FunctionHallListCard(venue: venue),
      CustomerSection.pgHostels => PgListCard(venue: venue),
      CustomerSection.institutesClasses => VenueCard(venue: venue),
    };
  }
}

/// Dates and party size collected on Home. These are booking context, not
/// a claim that the list was filtered by availability.
class _SearchTripContext extends ConsumerWidget {
  const _SearchTripContext({required this.section});

  final CustomerSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(discoveryBookingPrefsProvider);
    final theme = Theme.of(context);
    final checkIn = _shortDate(prefs.day);
    final text = switch (section) {
      CustomerSection.lodgeRooms =>
        'These are venue listings. A multi-night hotel stay is reserved from Stay properties, not a one-date slot.',
      CustomerSection.functionHalls =>
        'Event date $checkIn · ${prefs.guests} guests. Open a hall to see its dates and slots.',
      CustomerSection.pgHostels =>
        'These are venue listings. A PG reservation uses PG properties, move-in $checkIn'
            '${prefs.gender == null ? '' : ' · ${prefs.gender}'}'
            '${prefs.sharing == null ? '' : ' · ${prefs.sharing}'}.',
      CustomerSection.institutesClasses => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    final stayRoute = section == CustomerSection.pgHostels
        ? AppRoutes.pgList
        : section == CustomerSection.lodgeRooms
        ? AppRoutes.staysList
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (stayRoute != null)
            TextButton(
              onPressed: () => context.push(stayRoute),
              child: Text(
                section == CustomerSection.pgHostels
                    ? 'Open PG reservations'
                    : 'Open hotel stays',
              ),
            ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
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
  String? _facility;
  int? _minStars;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initial.sortBy;
    _minStars = widget.initial.minStarRating;
    _categorySlug = widget.initial.categorySlug;
    _facility = widget.initial.facility;
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
      facility: () => _facility,
      minStarRating: () => _minStars,
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
                  tooltip: l10n.back,
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
                      _facility = null;
                      _minStars = null;
                      _minController.clear();
                      _maxController.clear();
                    });
                  },
                  child: Text(l10n.clearFilters),
                ),
                IconButton(
                  key: const Key('filters_close'),
                  tooltip: l10n.close,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
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
                        _SortChip(
                          label: 'Largest capacity',
                          selected: _sortBy == VenueSortBy.capacity,
                          onTap: () =>
                              setState(() => _sortBy = VenueSortBy.capacity),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.allCategories, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    FilterCheckboxTile(
                      label: l10n.allCategories,
                      value: _categorySlug == null,
                      onChanged: (selected) {
                        if (selected) {
                          setState(() {
                            _categorySlug = null;
                            _facility = null;
                          });
                        }
                      },
                    ),
                    for (final category in widget.categories)
                      FilterCheckboxTile(
                        label: category.name,
                        value: _categorySlug == category.slug,
                        onChanged: (selected) {
                          if (selected) {
                            setState(() {
                              _categorySlug = category.slug;
                              _facility = null;
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 20),
                    if (_categoryFilterGroups(
                      widget.categories,
                      _categorySlug,
                    ).isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ..._categoryFilterGroups(
                        widget.categories,
                        _categorySlug,
                      ).map((group) {
                        if (group.type == ListingFilterType.range) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.label,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              FilterCheckboxTile(
                                label: 'Any ${group.label.toLowerCase()}',
                                value: _facility == null,
                                onChanged: (selected) {
                                  if (selected) {
                                    setState(() => _facility = null);
                                  }
                                },
                              ),
                              for (final option in group.options)
                                FilterCheckboxTile(
                                  label: option,
                                  value: _facility == option,
                                  onChanged: (selected) {
                                    if (selected) {
                                      setState(() => _facility = option);
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    Text('Hotel class', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    FilterCheckboxTile(
                      label: 'Any hotel class',
                      value: _minStars == null,
                      onChanged: (selected) {
                        if (selected) setState(() => _minStars = null);
                      },
                    ),
                    for (final stars in const [3, 4, 5])
                      FilterCheckboxTile(
                        key: Key('filters_stars_$stars'),
                        label: stars == 5 ? '5★' : '$stars★ & up',
                        value: _minStars == stars,
                        onChanged: (selected) {
                          if (selected) setState(() => _minStars = stars);
                        },
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
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(l10n.apply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<ListingFilterGroup> _categoryFilterGroups(
  List<VenueCategory> categories,
  String? slug,
) {
  if (slug == null) return const [];
  for (final category in categories) {
    if (category.slug == slug) return category.listingTemplate.filterGroups;
  }
  return const [];
}

/// Filter chips that stay on screen, instead of waiting for a category list.
class _SearchFilterChips extends StatelessWidget {
  const _SearchFilterChips({
    required this.query,
    required this.onOpenFilters,
    required this.onCommit,
  });

  final VenueSearchQuery query;
  final VoidCallback onOpenFilters;
  final ValueChanged<VenueSearchQuery> onCommit;

  static const _priceBands = <(double?, double?, String)>[
    (null, null, 'Any price'),
    (null, 1000, 'Under ₹1,000'),
    (1000, 3000, '₹1,000 – ₹3,000'),
    (3000, 10000, '₹3,000 – ₹10,000'),
    (10000, 50000, '₹10,000 – ₹50,000'),
    (50000, null, 'Above ₹50,000'),
  ];

  static const _ratings = <(double?, String)>[
    (null, 'Any rating'),
    (4.5, 'Wonderful: 4.5+'),
    (4.0, 'Very good: 4+'),
    (3.5, 'Good: 3.5+'),
    (3.0, 'Pleasant: 3+'),
  ];

  static const _classes = <(int?, String)>[
    (null, 'Any hotel class'),
    (5, '5★'),
    (4, '4★ & up'),
    (3, '3★ & up'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceLabel = _priceLabel();
    final ratingLabel = _labelFor(_ratings, query.minRating, 'Rating');
    final classLabel = _labelFor(_classes, query.minStarRating, 'Hotel class');
    final filtersOn =
        query.minPrice != null ||
        query.maxPrice != null ||
        query.minRating != null ||
        query.minStarRating != null ||
        query.minCapacity != null ||
        (query.gender != null && query.gender!.isNotEmpty) ||
        (query.sharing != null && query.sharing!.isNotEmpty) ||
        query.amenities.isNotEmpty ||
        (query.facility != null && query.facility!.isNotEmpty);
    return Material(
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SizedBox(
          key: const Key('search_filter_chips'),
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _SearchDropChip(
                key: const Key('search_chip_filters'),
                label: 'Filters',
                icon: Icons.tune_rounded,
                selected: filtersOn,
                dropdown: false,
                onTap: onOpenFilters,
              ),
              _SearchDropChip(
                key: const Key('search_chip_price'),
                label: priceLabel,
                selected: query.minPrice != null || query.maxPrice != null,
                onTap: () => _pickPrice(context),
              ),
              _SearchDropChip(
                key: const Key('search_chip_rating'),
                label: ratingLabel,
                selected: query.minRating != null,
                onTap: () => _pickOne<double>(
                  context,
                  title: 'Rating',
                  options: [
                    for (final option in _ratings)
                      if (option.$1 != null) (option.$1!, option.$2),
                  ],
                  selected: query.minRating,
                  onApply: (value) =>
                      onCommit(query.copyWith(minRating: () => value)),
                ),
              ),
              _SearchDropChip(
                key: const Key('search_chip_class'),
                label: classLabel,
                selected: query.minStarRating != null,
                onTap: () => _pickOne<int>(
                  context,
                  title: 'Hotel class',
                  options: [
                    for (final option in _classes)
                      if (option.$1 != null) (option.$1!, option.$2),
                  ],
                  selected: query.minStarRating,
                  onApply: (value) =>
                      onCommit(query.copyWith(minStarRating: () => value)),
                ),
              ),
              ..._sectionChips(context),
            ],
          ),
        ),
      ),
    );
  }

  String _priceLabel() {
    for (final band in _priceBands) {
      if (band.$1 == null && band.$2 == null) continue;
      if (query.minPrice == band.$1 && query.maxPrice == band.$2) {
        return band.$3;
      }
    }
    if (query.minPrice == null && query.maxPrice == null) return 'Price';
    final start = (query.minPrice ?? 0).round();
    final end = query.maxPrice?.round();
    return end == null ? 'Above ₹$start' : '₹$start – ₹$end';
  }

  Future<void> _pickPrice(BuildContext context) {
    final selected = _priceBands.indexWhere(
      (band) => query.minPrice == band.$1 && query.maxPrice == band.$2,
    );
    return _pickOne<int>(
      context,
      title: 'Price',
      options: [
        for (var index = 1; index < _priceBands.length; index++)
          (index, _priceBands[index].$3),
      ],
      selected: selected > 0 ? selected : null,
      onApply: (index) {
        if (index == null) {
          onCommit(query.copyWith(minPrice: () => null, maxPrice: () => null));
          return;
        }
        final band = _priceBands[index];
        onCommit(
          query.copyWith(minPrice: () => band.$1, maxPrice: () => band.$2),
        );
      },
    );
  }

  String _labelFor<T>(
    List<(T?, String)> options,
    T? selected,
    String fallback,
  ) {
    for (final option in options) {
      if (option.$1 != null && option.$1 == selected) return option.$2;
    }
    return fallback;
  }

  List<Widget> _sectionChips(BuildContext context) {
    final section = CustomerSectionCatalog.fromAny(query.categorySlug);
    if (section == null) return const [];
    final chips = <Widget>[];
    for (final spec in CustomerSectionCatalog.filterSpecs(section)) {
      switch (spec.field) {
        case SectionFilterField.guests:
          chips.add(
            _SearchDropChip(
              key: const Key('search_chip_guests'),
              label: query.minCapacity == null
                  ? spec.label
                  : '${query.minCapacity}+ guests',
              selected: query.minCapacity != null,
              onTap: () => _pickOne<int>(
                context,
                title: spec.label,
                options: [
                  for (final option in spec.options)
                    if (int.tryParse(option) != null)
                      (int.parse(option), option),
                ],
                selected: query.minCapacity,
                onApply: (value) =>
                    onCommit(query.copyWith(minCapacity: () => value)),
              ),
            ),
          );
        case SectionFilterField.amenities:
          final picked = query.amenities;
          chips.add(
            _SearchDropChip(
              key: const Key('search_chip_amenities'),
              label: picked.isEmpty
                  ? spec.label
                  : picked.map(_title).join(', '),
              selected: picked.isNotEmpty,
              onTap: () => _pickMany(
                context,
                title: spec.label,
                options: [
                  for (final option in spec.options) (option, _title(option)),
                ],
                selected: picked,
                onApply: (value) => onCommit(query.copyWith(amenities: value)),
              ),
            ),
          );
        case SectionFilterField.gender:
          chips.add(
            _SearchDropChip(
              key: const Key('search_chip_gender'),
              label: query.gender == null || query.gender!.isEmpty
                  ? spec.label
                  : _title(query.gender!),
              selected: query.gender != null && query.gender!.isNotEmpty,
              onTap: () => _pickOne<String>(
                context,
                title: spec.label,
                options: [
                  for (final option in spec.options) (option, _title(option)),
                ],
                selected: query.gender,
                onApply: (value) =>
                    onCommit(query.copyWith(gender: () => value)),
              ),
            ),
          );
        case SectionFilterField.sharing:
          chips.add(
            _SearchDropChip(
              key: const Key('search_chip_sharing'),
              label: query.sharing == null || query.sharing!.isEmpty
                  ? spec.label
                  : _title(query.sharing!),
              selected: query.sharing != null && query.sharing!.isNotEmpty,
              onTap: () => _pickOne<String>(
                context,
                title: spec.label,
                options: [
                  for (final option in spec.options) (option, _title(option)),
                ],
                selected: query.sharing,
                onApply: (value) =>
                    onCommit(query.copyWith(sharing: () => value)),
              ),
            ),
          );
        case SectionFilterField.date:
        case SectionFilterField.priceRange:
        case SectionFilterField.checkInOut:
        case SectionFilterField.roomType:
        case SectionFilterField.minRating:
        case SectionFilterField.food:
        case SectionFilterField.deposit:
        case SectionFilterField.classType:
        case SectionFilterField.mode:
          break;
      }
    }
    return chips;
  }

  String _title(String value) {
    return value
        .split(RegExp(r'[_-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Future<void> _pickOne<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T? selected,
    required ValueChanged<T?> onApply,
  }) {
    bool matches(T? a, T? b) => a == b;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = selected;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return _SheetFrame(
              title: title,
              onClear: () {
                onApply(null);
                Navigator.pop(context);
              },
              onApply: () {
                onApply(draft);
                Navigator.pop(context);
              },
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    CheckboxListTile(
                      value: matches(draft, option.$1),
                      title: Text(option.$2),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setLocal(
                        () => draft = (checked ?? false) ? option.$1 : null,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickMany(
    BuildContext context, {
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final draft = {...selected};
        return StatefulBuilder(
          builder: (context, setLocal) {
            return _SheetFrame(
              title: title,
              onClear: () {
                onApply(const {});
                Navigator.pop(context);
              },
              onApply: () {
                onApply(draft);
                Navigator.pop(context);
              },
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    CheckboxListTile(
                      value: draft.contains(option.$1),
                      title: Text(option.$2),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setLocal(() {
                        if (checked ?? false) {
                          draft.add(option.$1);
                        } else {
                          draft.remove(option.$1);
                        }
                      }),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    required this.onClear,
    required this.onApply,
  });

  final String title;
  final Widget child;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Flexible(child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(onPressed: onClear, child: const Text('Clear')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.action,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: onApply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchDropChip extends StatelessWidget {
  const _SearchDropChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dropdown = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = selected
        ? AppTheme.action
        : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.action.withValues(alpha: 0.12)
            : theme.colorScheme.surface,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppTheme.action),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (dropdown)
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
              ],
            ),
          ),
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

/// Shown when a search returns nothing. If the search text is a town in the
/// location hierarchy, venues from the town's district (or state) are shown
/// with a note; otherwise the usual "No results" message.
class _TownFallbackResults extends ConsumerWidget {
  const _TownFallbackResults({required this.text, this.categorySlug});

  final String text;
  final String? categorySlug;

  static const _noResults = EmptyState(
    icon: Icons.search_off_rounded,
    title: 'No results found',
    message: 'Try a different keyword, category or price range.',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.trim().length < 3) return _noResults;
    final fallback = ref.watch(
      townFallbackProvider((text: text.trim(), categorySlug: categorySlug)),
    );
    return fallback.when(
      loading: () => const ListSkeleton(),
      error: (_, _) => _noResults,
      data: (result) {
        if (result == null || result.venues.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            message: result == null
                ? 'Try a different keyword, category or price range.'
                : 'No venues in ${result.townName} or nearby yet.',
          );
        }
        final area = result.scopeLabel.isEmpty
            ? result.scopeName
            : '${result.scopeName} ${result.scopeLabel}';
        final note = result.inTown
            ? 'Venues in ${result.townName}'
            : 'No venues in ${result.townName} yet. Showing venues in $area.';
        final venues = result.venues;
        return LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveInfo.fromConstraints(constraints);
            final banner = Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      key: const Key('search-town-fallback-note'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
            final Widget list = responsive.resultsColumns <= 1
                ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        VenueCard(venue: venues[i], entranceIndex: i),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: responsive.resultsColumns,
                      mainAxisSpacing: responsive.gridSpacing,
                      crossAxisSpacing: responsive.gridSpacing,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: venues.length,
                    itemBuilder: (context, i) =>
                        VenueCard(venue: venues[i], entranceIndex: i),
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [banner, Expanded(child: list)],
            );
          },
        );
      },
    );
  }
}
