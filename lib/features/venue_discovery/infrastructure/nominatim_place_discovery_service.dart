import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/discovered_place.dart';

/// Read-only public-place search. Results remain non-bookable discovery
/// records until the C1 claim and moderation flow creates a venue draft.
class NominatimPlaceDiscoveryService {
  NominatimPlaceDiscoveryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<DiscoveredPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'q': trimmed,
      'limit': '20',
      'addressdetails': '1',
      'extratags': '1',
    });
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'en',
        'User-Agent': 'BookMySpace/1.0 (place-discovery)',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Place discovery failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (row) =>
              DiscoveredPlace.fromNominatim(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  void close() => _client.close();
}
