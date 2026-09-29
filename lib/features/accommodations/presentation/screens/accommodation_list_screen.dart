import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../domain/accommodation.dart';
import '../accommodation_providers.dart';

class AccommodationListScreen extends ConsumerStatefulWidget {
  const AccommodationListScreen({super.key, required this.module});

  final AccommodationModule module;

  @override
  ConsumerState<AccommodationListScreen> createState() =>
      _AccommodationListScreenState();
}

class _AccommodationListScreenState
    extends ConsumerState<AccommodationListScreen> {
  String _search = '';
  String? _type;
  String? _routeQuery;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    // Route query is the deep-link source. Re-read it when the URL changes
    // (browser back/refresh) without resetting text the user is typing.
    final query = GoRouterState.of(context).uri.queryParameters['q']?.trim() ?? '';
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

  List<(String, String)> get _types => widget.module == AccommodationModule.pg
      ? const [('Co-Living', 'co_living'), ('PG', 'pg')]
      : const [
          ('Hotels', 'hotel'),
          ('Hostels', 'hostel'),
          ('Resorts', 'resort'),
          ('Guest Houses', 'guest_house'),
          ('Service Apartments', 'service_apartment'),
        ];

  @override
  Widget build(BuildContext context) {
    final query = AccommodationQuery(
      module: widget.module,
      search: _search,
      type: _type,
    );
    final result = ref.watch(accommodationSearchProvider(query));
    final prefs = ref.watch(discoveryBookingPrefsProvider);
    final isPg = widget.module == AccommodationModule.pg;
    final title = isPg ? 'PG / Co-Living' : 'Rooms & Stays';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by property or city',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                for (final type in _types) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(type.$1),
                    selected: _type == type.$2,
                    onSelected: (_) => setState(() => _type = type.$2),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Text(
              isPg
                  ? 'Move-in ${_fmt(prefs.day)} · ${prefs.tenureMonths} '
                      '${prefs.tenureMonths == 1 ? 'month' : 'months'}'
                      '${prefs.gender == null ? '' : ' · ${prefs.gender}'}'
                      '${prefs.sharing == null ? '' : ' · ${prefs.sharing}'}'
                  : 'Check-in ${_fmt(prefs.day)} · Check-out ${_fmt(prefs.checkOutDay)} · '
                      '${prefs.guests} guests · ${prefs.rooms} '
                      '${prefs.rooms == 1 ? 'room' : 'rooms'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: result.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(accommodationSearchProvider(query)),
              ),
              data: (items) {
                final visible = _visible(items, prefs);
                if (visible.isEmpty) {
                  return const EmptyState(
                    icon: Icons.bedroom_parent_outlined,
                    title: 'No properties found',
                    message: 'Try another area or property type.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(accommodationSearchProvider(query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _PropertyCard(property: visible[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AccommodationProperty> _visible(
    List<AccommodationProperty> items,
    DiscoveryBookingPrefs prefs,
  ) {
    if (widget.module != AccommodationModule.pg) return items;
    return items
        .where((property) => genderPolicyAllows(property.genderPolicy, prefs.gender))
        .toList(growable: false);
  }

  static String _fmt(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});
  final AccommodationProperty property;

  @override
  Widget build(BuildContext context) {
    final isPg = property.module == AccommodationModule.pg;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/${isPg ? 'pg' : 'stays'}/${property.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 82,
                  height: 92,
                  child: property.coverImage.isEmpty
                      ? DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.brand, AppTheme.brandLight],
                            ),
                          ),
                          child: Icon(
                            isPg ? Icons.apartment_rounded : Icons.hotel_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        )
                      : AppNetworkImage(
                          url: property.coverImage,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.city} • ${property.propertyType.replaceAll('_', ' ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.startingPrice > 0
                          ? 'From ₹${property.startingPrice.toStringAsFixed(0)} ${isPg ? '/ month' : '/ night'}'
                          : 'Price unavailable',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPg
                          ? [
                              if (property.genderPolicy != null &&
                                  property.genderPolicy!.trim().isNotEmpty)
                                property.genderPolicy!,
                              '${property.units.length} listed units',
                            ].join(' · ')
                          : 'Date availability is checked on the property',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
