import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Raster tile URLs shared by listing-detail and live discovery maps.
///
/// Both native and Flutter web use official OSM tiles.  OSM's CDN sends
/// `Access-Control-Allow-Origin: *`, so CanvasKit can paint tiles without a
/// CORS proxy.
///
/// CARTO's basemap service now requires an API key and is no longer used as
/// the primary or fallback source.  The URL constants are kept for reference;
/// pass your key as a query parameter if you later want CARTO back.
abstract final class OsmMapTiles {
  static const userAgentPackageName = 'com.bookmyspace.app';

  // ── OSM (primary, both platforms) ─────────────────────────────────────────
  static const osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ── CARTO (reference only – API key required since Sep 2026) ──────────────
  static const cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const cartoLightUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  static const cartoSubdomains = ['a', 'b', 'c', 'd'];

  // ── Active configuration ───────────────────────────────────────────────────

  /// OSM on every platform; no API key required.
  static String get urlTemplate => osmUrl;

  /// No fallback – CARTO requires an API key and would show the same
  /// "API KEY REQUIRED" watermark.  Set this to a keyed CARTO URL if you
  /// obtain a key and want redundancy.
  static String? get fallbackUrl => null;

  /// OSM primary has no `{s}` token; list kept so [TileLayer] is happy.
  static List<String> get subdomains => cartoSubdomains;

  static String get attributionLabel => '© OpenStreetMap';
}

/// OSM [TileLayer] that works on native and Flutter web without an API key.
class OsmTileLayer extends StatelessWidget {
  const OsmTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: OsmMapTiles.urlTemplate,
      fallbackUrl: OsmMapTiles.fallbackUrl,
      subdomains: OsmMapTiles.subdomains,
      userAgentPackageName: OsmMapTiles.userAgentPackageName,
    );
  }
}

/// Required OSM attribution overlay.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text.rich(
            TextSpan(
              text: 'flutter_map | © ',
              children: [TextSpan(text: OsmMapTiles.attributionLabel)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
