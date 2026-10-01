import '../../venues/domain/venue.dart';

/// A place returned by the public Nominatim/OSM search.
///
/// External places are discovery-only until an owner claim is approved. They
/// never become bookable venues on the client.
class DiscoveredPlace {
  const DiscoveredPlace({
    required this.id,
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.category,
    this.address,
    this.website,
  });

  final String id;
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? category;
  final String? address;
  final String? website;

  factory DiscoveredPlace.fromNominatim(Map<String, dynamic> json) {
    final latitude = double.tryParse('${json['lat'] ?? ''}');
    final longitude = double.tryParse('${json['lon'] ?? ''}');
    if (latitude == null || longitude == null) {
      throw const FormatException('Place coordinates are invalid.');
    }
    final address = json['address'] is Map
        ? Map<String, dynamic>.from(json['address'] as Map)
        : const <String, dynamic>{};
    return DiscoveredPlace(
      id: '${json['osm_type'] ?? 'place'}:${json['osm_id'] ?? json['place_id']}',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : (json['display_name'] as String? ?? 'Unknown place')
                .split(',')
                .first
                .trim(),
      displayName: json['display_name'] as String? ?? 'Unknown place',
      latitude: latitude,
      longitude: longitude,
      category: json['type'] as String? ?? json['class'] as String?,
      address: _addressLine(address),
      website: (json['extratags'] is Map)
          ? (json['extratags']['website'] as String?)
          : null,
    );
  }

  /// Removes external results that are already represented by a registered
  /// venue, using both normalized names and a small coordinate radius.
  static List<DiscoveredPlace> deduplicate(
    List<DiscoveredPlace> places,
    List<Venue> registered,
  ) {
    final seen = <String>{};
    return places
        .where((place) {
          final key = _normalize(place.name);
          if (key.isNotEmpty &&
              registered.any((venue) => _normalize(venue.name) == key)) {
            return false;
          }
          if (registered.any(
            (venue) => _near(place, venue.latitude, venue.longitude),
          )) {
            return false;
          }
          if (key.isNotEmpty && !seen.add(key)) return false;
          return true;
        })
        .toList(growable: false);
  }

  static bool _near(DiscoveredPlace place, double latitude, double longitude) {
    if (latitude == 0 || longitude == 0) return false;
    final dLat = (place.latitude - latitude).abs();
    final dLon = (place.longitude - longitude).abs();
    return dLat < 0.001 && dLon < 0.001;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String? _addressLine(Map<String, dynamic> address) {
    final parts =
        [
              address['road'],
              address['suburb'],
              address['city'] ?? address['town'] ?? address['village'],
              address['state'],
            ]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty);
    final line = parts.join(', ');
    return line.isEmpty ? null : line;
  }
}
