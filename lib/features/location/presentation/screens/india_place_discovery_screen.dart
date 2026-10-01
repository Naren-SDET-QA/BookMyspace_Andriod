import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/search_route.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../domain/location_node.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../widgets/cascading_location_selector.dart';

/// Customer India hierarchy explorer.
///
/// State, district, mandal, and town come from the location directory.
/// Discover opens the existing venue search with that place. Nothing on
/// this screen invents venues or coordinates.
class IndiaPlaceDiscoveryScreen extends ConsumerStatefulWidget {
  const IndiaPlaceDiscoveryScreen({super.key});

  @override
  ConsumerState<IndiaPlaceDiscoveryScreen> createState() =>
      _IndiaPlaceDiscoveryScreenState();
}

class _IndiaPlaceDiscoveryScreenState
    extends ConsumerState<IndiaPlaceDiscoveryScreen> {
  CascadingLocationValue _hierarchy = const CascadingLocationValue();
  int _radiusKm = 10;

  LocationNode? get _selected =>
      _hierarchy.area ??
      _hierarchy.village ??
      _hierarchy.city ??
      _hierarchy.mandal ??
      _hierarchy.district ??
      _hierarchy.state ??
      _hierarchy.country;

  String get _label {
    final parts = <String>[
      if (_hierarchy.state != null) _hierarchy.state!.name,
      if (_hierarchy.district != null) _hierarchy.district!.name,
      if (_hierarchy.mandal != null) _hierarchy.mandal!.name,
      if (_hierarchy.city != null) _hierarchy.city!.name,
      if (_hierarchy.area != null) _hierarchy.area!.name,
    ];
    if (parts.isEmpty) return _selected?.name ?? '';
    return parts.join(' → ');
  }

  void _discover() {
    final selected = _selected;
    final label = selected?.name.trim() ?? '';
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a state, district, or city first.'),
        ),
      );
      return;
    }
    final notifier = ref.read(discoveryLocationProvider.notifier);
    notifier.setRadiusKm(_radiusKm);
    if (selected!.latitude != null && selected.longitude != null) {
      notifier.applyGps(
        latitude: selected.latitude!,
        longitude: selected.longitude!,
        city: _hierarchy.city?.name ?? _hierarchy.district?.name ?? label,
        district: _hierarchy.district?.name,
        stateName: _hierarchy.state?.name,
        label: label,
      );
    } else {
      notifier.setCity(label);
    }
    final query = VenueSearchQuery(
      query: label,
      city: _hierarchy.city?.name ?? label,
      state: _hierarchy.state?.name,
      district: _hierarchy.district?.name,
      area: _hierarchy.area?.name,
      latitude: selected.latitude,
      longitude: selected.longitude,
      radiusKm: selected.latitude == null ? null : _radiusKm,
    );
    if (!mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      context.go(SearchRouteParams.locationFor(query));
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cities = ref.watch(listedVenueCitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'India Place Discovery',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ResponsiveLayoutBuilder(
        builder: (context, responsive) {
          final wide = responsive.availableWidth >= 840;
          final hierarchy = _HierarchyPanel(
            hierarchy: _hierarchy,
            radiusKm: _radiusKm,
            onHierarchy: (value) => setState(() => _hierarchy = value),
            onRadius: (km) => setState(() => _radiusKm = km),
            onDiscover: _discover,
          );
          final preview = _PreviewPanel(
            label: _label,
            radiusKm: _radiusKm,
            cities: cities,
            onCity: (city) {
              ref.read(discoveryLocationProvider.notifier).setCity(city);
              final query = VenueSearchQuery(query: city, city: city);
              if (GoRouter.maybeOf(context) != null) {
                context.go(SearchRouteParams.locationFor(query));
              }
            },
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.maxContentWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  12,
                  responsive.horizontalPadding,
                  24,
                ),
                children: [
                  Text(
                    'Hierarchical & PIN Code Explorer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!wide) ...[
                    hierarchy,
                    const SizedBox(height: 16),
                    preview,
                  ] else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 20.0;
                        final left = (constraints.maxWidth - gap) * 0.56;
                        final right = constraints.maxWidth - gap - left;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: left, child: hierarchy),
                            const SizedBox(width: 20),
                            SizedBox(width: right, child: preview),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HierarchyPanel extends StatelessWidget {
  const _HierarchyPanel({
    required this.hierarchy,
    required this.radiusKm,
    required this.onHierarchy,
    required this.onRadius,
    required this.onDiscover,
  });

  final CascadingLocationValue hierarchy;
  final int radiusKm;
  final ValueChanged<CascadingLocationValue> onHierarchy;
  final ValueChanged<int> onRadius;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. India Hierarchical Selection',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'India → State → District → Mandal → Town',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        CascadingLocationSelector(
          value: hierarchy,
          compact: MediaQuery.sizeOf(context).width < 600,
          onChanged: onHierarchy,
        ),
        const SizedBox(height: 16),
        Text(
          'Discovery Radius',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final km in const [5, 10, 25])
              ChoiceChip(
                label: Text('$km km'),
                selected: radiusKm == km,
                onSelected: (_) => onRadius(km),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('discover-places-button'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onDiscover,
          child: const Text(
            'Discover Places in this Location',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.label,
    required this.radiusKm,
    required this.cities,
    required this.onCity,
  });

  final String label;
  final int radiusKm;
  final AsyncValue<List<String>> cities;
  final ValueChanged<String> onCity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = label.isEmpty ? 'Choose a place' : label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Popular Locations in India',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        cities.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, _) => Text(
            'Listed cities are unavailable right now.',
            style: theme.textTheme.bodySmall,
          ),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'Cities appear here from real venue listings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final city in items.take(12))
                  ActionChip(
                    label: Text(city, overflow: TextOverflow.ellipsis),
                    onPressed: () => onCity(city),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          key: const Key('india-place-preview'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label.isEmpty
                    ? 'Pick a level in the hierarchy, then discover places.'
                    : 'Searching near $place · radius $radiusKm km',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
