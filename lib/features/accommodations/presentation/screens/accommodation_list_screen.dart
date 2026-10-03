import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../domain/accommodation.dart';
import '../stay_results_filter.dart';
import '../widgets/stay_filter_panel.dart';
import '../widgets/stay_results_chrome.dart';

/// Customer accommodation discovery backed by the canonical venue contract.
///
/// The old implementation queried `accommodation_properties` and
/// `accommodation_units`, which are not part of the linked DEV schema. This
/// screen deliberately uses the same public venue search contract as the
/// rest of customer discovery, so Hotel/PG entry points render instead of
/// silently failing or inventing accommodation rows.
class AccommodationListScreen extends ConsumerStatefulWidget {
  const AccommodationListScreen({super.key, required this.module});

  final AccommodationModule module;

  @override
  ConsumerState<AccommodationListScreen> createState() =>
      _AccommodationListScreenState();
}

class _AccommodationListScreenState
    extends ConsumerState<AccommodationListScreen> {
  late final TextEditingController _searchController;
  String _search = '';
  StayResultsFilter _filter = const StayResultsFilter();
  StaySort _sort = StaySort.topPicks;
  String? _routeQuery;
  List<Venue>? _cachedResults;
  double? _priceCeiling;

  bool get _isPg => widget.module == AccommodationModule.pg;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final query =
        GoRouterState.of(context).uri.queryParameters['q']?.trim() ?? '';
    if (query == _routeQuery) return;
    _routeQuery = query;
    _search = query;
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  VenueSearchQuery _query(DiscoveryBookingPrefs prefs) {
    return VenueSearchQuery(
      query: _search.trim(),
      sectionId: _isPg
          ? CustomerSection.pgHostels.id
          : CustomerSection.lodgeRooms.id,
      sortBy: _sort.serverSort,
      minPrice: _filter.minPrice,
      maxPrice: _filter.maxPrice,
      minRating: _filter.minRating,
      minStarRating: _isPg ? null : _filter.serverMinStar,
      gender: _isPg ? prefs.gender : null,
      sharing: _isPg ? prefs.sharing : null,
      limit: 50,
    );
  }

  bool _inSection(Venue venue) {
    final section = CustomerSectionCatalog.sectionForVenue(venue);
    return _isPg
        ? section == CustomerSection.pgHostels
        : section == CustomerSection.lodgeRooms;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(discoveryBookingPrefsProvider);
    final query = _query(prefs);
    final results = ref.watch(searchResultsProvider(query));
    final snapshot = results.asData?.value;
    if (snapshot != null) _cachedResults = snapshot;
    final items = snapshot ?? _cachedResults;
    final title = _isPg ? 'PG & co-living' : 'Hotels & stays';

    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: Text(title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = MediaQuery.sizeOf(context);
          final finiteWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : viewport.width;
          final finiteHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : viewport.height;
          final responsive = ResponsiveInfo.fromConstraints(
            BoxConstraints.tightFor(width: finiteWidth, height: finiteHeight),
          );
          final contentWidth = finiteWidth > responsive.maxContentWidth
              ? responsive.maxContentWidth
              : finiteWidth;
          final wide = responsive.isExpanded || responsive.isExtraWide;
          return Center(
            child: SizedBox(
              width: contentWidth,
              height: finiteHeight,
              child: Column(
                children: [
                  StaySearchBar(
                    isPg: _isPg,
                    controller: _searchController,
                    hasSearch: _search.trim().isNotEmpty,
                    prefs: prefs,
                    onChanged: (value) => setState(() => _search = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    onPickDates: _pickDates,
                    onPickGuests: _pickGuests,
                    onSearch: () => FocusScope.of(context).unfocus(),
                  ),
                  if (results.isLoading && items != null)
                    const LinearProgressIndicator(minHeight: 2),
                  StayFilterChipBar(
                    filter: _filter,
                    isPg: _isPg,
                    priceCeiling: _priceCeiling ?? 20000,
                    onChanged: (next) => setState(() => _filter = next),
                    onOpenAll: () => _openFilters(
                      (items ?? const <Venue>[]).where(_inSection).toList(),
                      _priceCeiling ?? 20000,
                    ),
                  ),
                  Expanded(
                    child: items == null
                        ? _firstLoad(results, query)
                        : _resultsBody(
                            items: items,
                            prefs: prefs,
                            query: query,
                            wide: wide,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _firstLoad(AsyncValue<List<Venue>> results, VenueSearchQuery query) {
    if (results.hasError && !results.hasValue) {
      return ErrorView(
        message: results.error.toString(),
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _resultsBody({
    required List<Venue> items,
    required DiscoveryBookingPrefs prefs,
    required VenueSearchQuery query,
    required bool wide,
  }) {
    final sectioned = items.where(_inSection).toList(growable: false);
    final observedCeiling = StayResultsFilterEngine.priceCeiling(sectioned);
    if (_filter.minPrice == null &&
        _filter.maxPrice == null &&
        observedCeiling > 0) {
      _priceCeiling = observedCeiling;
    }
    final ceiling = _priceCeiling ?? observedCeiling;
    final visible = StayResultsFilterEngine.sort(
      StayResultsFilterEngine.apply(sectioned, _filter, isPg: _isPg),
      _sort,
    );
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          SizedBox(
            width: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: StayFilterPanel(
                venues: sectioned,
                filter: _filter,
                isPg: _isPg,
                priceCeiling: ceiling,
                onChanged: (next) => setState(() => _filter = next),
                onClear: _clearFilters,
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              _resultsHeader(visible.length),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(searchResultsProvider(query));
                    await ref.read(searchResultsProvider(query).future);
                  },
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 360,
                              child: EmptyState(
                                icon: Icons.bedroom_parent_outlined,
                                title: 'No properties found',
                                message:
                                    'Try another destination or clear a filter.',
                                action: _filter.activeCount == 0
                                    ? null
                                    : TextButton(
                                        onPressed: _clearFilters,
                                        child: const Text('Clear filters'),
                                      ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          key: const Key('stay_results_list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return LayoutBuilder(
                              builder: (context, cardConstraints) {
                                return StayResultCard(
                                  venue: visible[index],
                                  isPg: _isPg,
                                  prefs: prefs,
                                  horizontal: cardConstraints.maxWidth >= 680,
                                  onTap: () => _openDetails(visible[index]),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultsHeader(int count) {
    final noun = count == 1 ? 'property' : 'properties';
    final place = _search.trim();
    final title = place.isEmpty
        ? '$count $noun found'
        : '$place: $count $noun found';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: StaySortButton(
              sort: _sort,
              onSelected: (value) => setState(() => _sort = value),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFilters() => setState(() => _filter = const StayResultsFilter());

  Future<void> _openFilters(List<Venue> venues, double ceiling) async {
    final picked = await showModalBottomSheet<StayResultsFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = _filter;
        return StatefulBuilder(
          builder: (context, setModal) {
            final count = StayResultsFilterEngine.count(
              venues,
              draft,
              isPg: _isPg,
            );
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.92,
              child: StayFilterPanel(
                venues: venues,
                filter: draft,
                isPg: _isPg,
                priceCeiling: ceiling,
                showApplyBar: true,
                resultCount: count,
                onChanged: (next) => setModal(() => draft = next),
                onClear: () =>
                    setModal(() => draft = const StayResultsFilter()),
                onApply: () => Navigator.pop(context, draft),
              ),
            );
          },
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _filter = picked);
  }

  Future<void> _pickDates() async {
    final prefs = ref.read(discoveryBookingPrefsProvider);
    final notifier = ref.read(discoveryBookingPrefsProvider.notifier);
    if (_isPg) {
      final moveIn = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)),
        initialDate: prefs.day,
      );
      if (moveIn != null) notifier.setDate(moveIn);
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: prefs.day, end: prefs.checkOutDay),
    );
    if (range == null || !mounted) return;
    notifier.setDate(range.start);
    notifier.setCheckOut(range.end);
  }

  Future<void> _pickGuests() async {
    final prefs = ref.read(discoveryBookingPrefsProvider);
    final picked = await showDialog<_PartySize>(
      context: context,
      builder: (context) {
        var guests = prefs.guests;
        var rooms = prefs.rooms;
        var months = prefs.tenureMonths;
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: Text(_isPg ? 'Guests' : 'Guests and rooms'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperRow(
                    label: _isPg ? 'Guests' : 'Adults',
                    value: guests,
                    onChanged: (value) => setDialog(() => guests = value),
                  ),
                  if (_isPg)
                    _StepperRow(
                      label: 'Months',
                      value: months,
                      max: 12,
                      onChanged: (value) => setDialog(() => months = value),
                    )
                  else
                    _StepperRow(
                      label: 'Rooms',
                      value: rooms,
                      max: 8,
                      onChanged: (value) => setDialog(() => rooms = value),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _PartySize(guests: guests, rooms: rooms, months: months),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(discoveryBookingPrefsProvider.notifier);
    notifier.setGuests(picked.guests);
    if (_isPg) {
      notifier.setTenureMonths(picked.months);
    } else {
      notifier.setRooms(picked.rooms);
    }
  }

  void _openDetails(Venue venue) {
    context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id));
  }
}

class _PartySize {
  const _PartySize({
    required this.guests,
    required this.rooms,
    required this.months,
  });

  final int guests;
  final int rooms;
  final int months;
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 20,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
