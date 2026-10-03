import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../map/presentation/widgets/osm_tile_layer.dart';
import '../../domain/venue.dart';

/// "Exact Venue Location & Navigation" section with interactive OSM map,
/// venue pin, zoom controls, and Directions launcher.
class VenueLocationNavigationSection extends StatefulWidget {
  const VenueLocationNavigationSection({
    super.key,
    required this.venue,
    required this.accent,
  });

  final Venue venue;
  final Color accent;

  @override
  State<VenueLocationNavigationSection> createState() =>
      _VenueLocationNavigationSectionState();
}

class _VenueLocationNavigationSectionState
    extends State<VenueLocationNavigationSection> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openDirections() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.venue.latitude},${widget.venue.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = LatLng(widget.venue.latitude, widget.venue.longitude);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.map_rounded,
                size: 20,
                color: widget.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exact Venue Location & Navigation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'OpenStreetMap',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Map Area
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      const OsmTileLayer(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 44,
                            height: 44,
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_pin,
                              color: widget.accent,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                      const OsmAttribution(),
                    ],
                  ),

                  // Map zoom controls
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ZoomButton(
                          icon: Icons.add,
                          onPressed: () {
                            final zoom = _mapController.camera.zoom + 1;
                            _mapController.move(_mapController.camera.center, zoom);
                          },
                        ),
                        const SizedBox(height: 4),
                        _ZoomButton(
                          icon: Icons.remove,
                          onPressed: () {
                            final zoom = _mapController.camera.zoom - 1;
                            _mapController.move(_mapController.camera.center, zoom);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Address detail row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.venue.address.isNotEmpty
                      ? widget.venue.address
                      : '${widget.venue.name}, ${widget.venue.city}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons: Directions & View Details
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: _openDirections,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(widget.venue.name),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 Address: ${widget.venue.address}'),
                            if (widget.venue.city.isNotEmpty)
                              Text('🏙️ City: ${widget.venue.city}'),
                            if (widget.venue.pincode.isNotEmpty)
                              Text('📮 PIN: ${widget.venue.pincode}'),
                            const SizedBox(height: 8),
                            Text('Coordinates: ${widget.venue.latitude.toStringAsFixed(4)}, ${widget.venue.longitude.toStringAsFixed(4)}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}
