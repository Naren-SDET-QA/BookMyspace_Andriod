import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Cluster representation for grouping closely situated venue markers.
class VenueCluster {
  const VenueCluster({
    required this.id,
    required this.position,
    required this.venues,
  });

  final String id;
  final LatLng position;
  final List<Venue> venues;

  bool get isSingle => venues.length == 1;
  Venue get singleVenue => venues.first;
}

/// An interactive live map discovery screen supporting both iOS and Web.
///
/// Features:
/// - Real-time Google Maps integration matching Android parity.
/// - Venue pins with dynamic clustering based on map zoom levels.
/// - Map/List split view (side-by-side on Web/Desktop, layered sheet on Mobile).
/// - Category and text search filtering with debounced reactivity.
/// - Synchronized two-way selection:
///     * Selecting a pin highlights the venue in the list and scrolls it into view.
///     * Clicking a venue in the list centers and zooms the map onto the venue.
/// - Full loading, empty, and error state handling.
/// - Venue detail navigation on card or callout tap.
class VenueMapScreen extends ConsumerStatefulWidget {
  const VenueMapScreen({
    super.key,
    this.initialVenueId,
    this.initialCategory,
    this.initialQuery = '',
  });

  final String? initialVenueId;
  final String? initialCategory;
  final String initialQuery;

  @override
  ConsumerState<VenueMapScreen> createState() => _VenueMapScreenState();
}

class _VenueMapScreenState extends ConsumerState<VenueMapScreen> {
  GoogleMapController? _mapController;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  late VenueSearchQuery _query;

  // Selected venue identifier for two-way synchronization
  String? _selectedVenueId;

  // Current map zoom level tracked for dynamic clustering
  double _currentZoom = 12.0;

  LatLng get _mapCenter {
    final location = ref.read(discoveryLocationProvider);
    if (location.hasCoordinates) {
      return LatLng(location.latitude!, location.longitude!);
    }
    return const LatLng(17.3850, 78.4867);
  }

  // Scroll controller for the list view to scroll selected item into view
  final ScrollController _listScrollController = ScrollController();

  // Keep track of venue list keys for automatic scrolling
  final Map<String, GlobalKey> _itemKeys = {};

  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _query = VenueSearchQuery(
      query: widget.initialQuery,
      categorySlug: widget.initialCategory,
    );
    _searchController = TextEditingController(text: _query.query);
    _selectedVenueId = widget.initialVenueId;
  }

  void _setQuery(VenueSearchQuery query) {
    if (_query == query) return;
    setState(() => _query = query);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _listScrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _setQuery(_query.copyWith(query: text.trim()));
    });
  }

  /// Centers the map on the selected venue and updates active selection.
  Future<void> _selectVenue(Venue venue, {bool animateMap = true}) async {
    setState(() {
      _selectedVenueId = venue.id;
    });

    if (animateMap && _mapController != null && venue.latitude != 0.0) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(venue.latitude, venue.longitude),
            zoom: math.max(_currentZoom, 14.5),
          ),
        ),
      );
    }

    _scrollToVenueInList(venue.id);
  }

  void _scrollToVenueInList(String venueId) {
    final key = _itemKeys[venueId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  /// Clusters venues using a simple grid-based distance metric according to zoom level.
  List<VenueCluster> _computeClusters(List<Venue> venues, double zoom) {
    final validVenues =
        venues.where((v) => v.latitude != 0.0 && v.longitude != 0.0).toList();
    if (validVenues.isEmpty) return const [];

    // Threshold radius in degrees decreases as zoom increases
    // At zoom 10: ~0.08 deg, at zoom 15: ~0.003 deg
    final clusterRadius = 40.0 / math.pow(2, zoom);

    final List<VenueCluster> clusters = [];
    final Set<String> visitedIds = {};

    for (final venue in validVenues) {
      if (visitedIds.contains(venue.id)) continue;

      final nearby = <Venue>[venue];
      visitedIds.add(venue.id);

      for (final other in validVenues) {
        if (visitedIds.contains(other.id)) continue;
        final dLat = (venue.latitude - other.latitude).abs();
        final dLng = (venue.longitude - other.longitude).abs();
        final dist = math.sqrt(dLat * dLat + dLng * dLng);

        if (dist < clusterRadius) {
          nearby.add(other);
          visitedIds.add(other.id);
        }
      }

      // Compute geometric center of cluster
      double avgLat = 0;
      double avgLng = 0;
      for (final v in nearby) {
        avgLat += v.latitude;
        avgLng += v.longitude;
      }
      avgLat /= nearby.length;
      avgLng /= nearby.length;

      clusters.add(
        VenueCluster(
          id: nearby.length == 1 ? nearby.first.id : 'cluster_${venue.id}',
          position: LatLng(avgLat, avgLng),
          venues: nearby,
        ),
      );
    }

    return clusters;
  }

  Set<Marker> _buildMarkers(List<VenueCluster> clusters) {
    final markers = <Marker>{};

    for (final cluster in clusters) {
      if (cluster.isSingle) {
        final venue = cluster.singleVenue;
        final isSelected = venue.id == _selectedVenueId;

        markers.add(
          Marker(
            markerId: MarkerId(venue.id),
            position: LatLng(venue.latitude, venue.longitude),
            icon: isSelected
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueCyan)
                : BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: venue.name,
              snippet: '${venue.city} · ${formatInr(venue.price)}',
              onTap: () => context.push(
                AppRoutes.venueDetails.replaceAll(':id', venue.id),
              ),
            ),
            onTap: () => _selectVenue(venue, animateMap: false),
            zIndexInt: isSelected ? 10 : 1,
          ),
        );
      } else {
        // Multi-venue cluster pin
        final count = cluster.venues.length;
        markers.add(
          Marker(
            markerId: MarkerId(cluster.id),
            position: cluster.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: '$count Venues in this area',
              snippet: 'Tap or zoom in to explore',
            ),
            onTap: () {
              // Zoom into the cluster
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: cluster.position,
                    zoom: _currentZoom + 2.0,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final query = _query;
    final categoriesAsync = ref.watch(venueCategoriesProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Map Discovery', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          if (query.hasFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: l10n.clearFilters,
              onPressed: () {
                _searchController.clear();
                _setQuery(const VenueSearchQuery());
              },
            ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Re-center Map',
            onPressed: () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _mapCenter, zoom: 12.0),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 840;

          return Column(
            children: [
              // Search text box & category chips filter bar
              _buildFilterHeader(theme, l10n, query, categoriesAsync),

              // Main content area: split-view for wide screens (Web/Desktop),
              // or responsive vertical split for mobile screens
              Expanded(
                child: searchResultsAsync.when(
                  data: (venues) {
                    final clusters = _computeClusters(venues, _currentZoom);
                    final markers = _buildMarkers(clusters);

                    // Ensure item keys for scrolling
                    for (final v in venues) {
                      _itemKeys.putIfAbsent(v.id, () => GlobalKey());
                    }

                    if (isWideScreen) {
                      // Desktop Web Layout: Side-by-side split view
                      return Row(
                        children: [
                          // Left side: Interactive Map (55% width)
                          Expanded(
                            flex: 55,
                            child: _buildGoogleMap(markers, venues),
                          ),
                          // Vertical divider
                          const VerticalDivider(width: 1, thickness: 1),
                          // Right side: Venue list with two-way selection (45% width)
                          Expanded(
                            flex: 45,
                            child: _buildVenueList(venues, theme, l10n),
                          ),
                        ],
                      );
                    } else {
                      // Mobile View: Split layout with map on top, venue cards list on bottom
                      return Column(
                        children: [
                          Expanded(
                            flex: 55,
                            child: _buildGoogleMap(markers, venues),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Expanded(
                            flex: 45,
                            child: _buildVenueList(venues, theme, l10n),
                          ),
                        ],
                      );
                    }
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading interactive map and venues...'),
                        ],
                      ),
                    ),
                  ),
                  error: (e, _) => ErrorView(
                    message: e.toString(),
                    onRetry: () =>
                        ref.invalidate(searchResultsProvider(query)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader(
    ThemeData theme,
    AppLocalizations l10n,
    VenueSearchQuery query,
    AsyncValue<List<VenueCategory>> categoriesAsync,
  ) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search input field
          TextField(
            controller: _searchController,
            onChanged: _onSearchQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Category horizontal scroll chips
          SizedBox(
            height: 38,
            child: categoriesAsync.when(
              data: (categories) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isAll = query.categorySlug == null;
                      return AnimatedCategoryChip(
                        selected: isAll,
                        label: l10n.allCategories,
                        emoji: '🌐',
                        onTap: () {
                          _setQuery(query.copyWith(categorySlug: () => null));
                        },
                      );
                    }
                    final cat = categories[index - 1];
                    final isSelected = query.categorySlug == cat.slug;
                    return AnimatedCategoryChip(
                      selected: isSelected,
                      label: cat.name,
                      emoji: cat.icon,
                      onTap: () {
                        _setQuery(
                          query.copyWith(
                            categorySlug: () => isSelected ? null : cat.slug,
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const SizedBox(
                height: 36,
                child: Row(
                  children: [
                    SkeletonBox(width: 80, height: 32, radius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 100, height: 32, radius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 90, height: 32, radius: 16),
                  ],
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap(Set<Marker> markers, List<Venue> venues) {
    LatLng initialTarget = _mapCenter;
    if (_selectedVenueId != null) {
      final selected =
          venues.where((v) => v.id == _selectedVenueId).firstOrNull;
      if (selected != null && selected.latitude != 0.0) {
        initialTarget = LatLng(selected.latitude, selected.longitude);
      }
    } else if (venues.isNotEmpty) {
      final firstWithCoords =
          venues.where((v) => v.latitude != 0.0).firstOrNull;
      if (firstWithCoords != null) {
        initialTarget =
            LatLng(firstWithCoords.latitude, firstWithCoords.longitude);
      }
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: _currentZoom,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            setState(() {
              _isMapReady = true;
            });
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          onCameraIdle: () {
            // Recompute clusters on zoom change
            if (mounted) setState(() {});
          },
        ),
        if (!_isMapReady)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildVenueList(
    List<Venue> venues,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (venues.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.location_off_rounded,
          title: l10n.noResults,
          message: l10n.noResultsMessage,
        ),
      );
    }

    return ListView.separated(
      controller: _listScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: venues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final venue = venues[index];
        final isSelected = venue.id == _selectedVenueId;

        return KeyedSubtree(
          key: _itemKeys[venue.id],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.brand
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.brand.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectVenue(venue, animateMap: true),
              child: VenueCard(venue: venue),
            ),
          ),
        );
      },
    );
  }
}
