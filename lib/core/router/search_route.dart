import 'package:go_router/go_router.dart';

import '../../features/venues/domain/venue.dart';

/// Canonical search/map discovery query encoded in the route URI.
///
/// Query parameters are the source of truth for how the user arrived on
/// Search or Map. `state.extra` is accepted only as a compatibility fallback
/// so older call sites keep working.
class SearchRouteParams {
  const SearchRouteParams({
    this.query = '',
    this.categorySlug,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.sortBy = VenueSortBy.relevance,
    this.venueId,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.pincode,
  });

  static const categoryParam = 'category';
  static const queryParam = 'q';
  static const cityParam = 'city';
  static const minPriceParam = 'minPrice';
  static const maxPriceParam = 'maxPrice';
  static const sortParam = 'sort';
  static const venueIdParam = 'venueId';
  static const latParam = 'lat';
  static const lngParam = 'lng';
  static const radiusParam = 'radius';
  static const pinParam = 'pin';

  final String query;
  final String? categorySlug;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final VenueSortBy sortBy;
  final String? venueId;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final String? pincode;

  factory SearchRouteParams.fromQuery(VenueSearchQuery query) {
    return SearchRouteParams(
      query: query.query,
      categorySlug: query.categorySlug,
      city: query.city,
      minPrice: query.minPrice,
      maxPrice: query.maxPrice,
      sortBy: query.sortBy,
      latitude: query.latitude,
      longitude: query.longitude,
      radiusKm: query.radiusKm,
      pincode: query.pincode,
    );
  }

  factory SearchRouteParams.fromUri(Uri uri, {Object? extra}) {
    final extraMap = extra is Map ? Map<Object?, Object?>.from(extra) : null;

    String? extraString(String key) {
      final value = extraMap?[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }

    final params = uri.queryParameters;
    String? routeOrExtra(String key, {String? legacyKey}) {
      // A present-but-empty query parameter intentionally clears that field;
      // it must not fall back to stale compatibility data in `extra`.
      if (params.containsKey(key)) return _nonEmpty(params[key]);
      return extraString(key) ??
          (legacyKey == null ? null : extraString(legacyKey));
    }

    return SearchRouteParams(
      query: routeOrExtra(queryParam, legacyKey: 'query') ?? '',
      categorySlug: routeOrExtra(categoryParam),
      city: routeOrExtra(cityParam),
      minPrice: _parseDouble(routeOrExtra(minPriceParam)),
      maxPrice: _parseDouble(routeOrExtra(maxPriceParam)),
      sortBy: _parseSort(routeOrExtra(sortParam)),
      venueId: routeOrExtra(venueIdParam),
      latitude: _parseDouble(routeOrExtra(latParam)),
      longitude: _parseDouble(routeOrExtra(lngParam)),
      radiusKm: _parseInt(routeOrExtra(radiusParam)),
      pincode: routeOrExtra(pinParam),
    );
  }

  factory SearchRouteParams.fromGoRouterState(GoRouterState state) {
    return SearchRouteParams.fromUri(state.uri, extra: state.extra);
  }

  VenueSearchQuery toQuery() {
    return VenueSearchQuery(
      query: query,
      categorySlug: categorySlug,
      city: city,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortBy: sortBy,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      pincode: pincode,
    );
  }

  String get searchLocation => _location('/search');

  String get mapLocation => _location('/map');

  static String locationFor(VenueSearchQuery query) {
    return SearchRouteParams.fromQuery(query).searchLocation;
  }

  static String mapLocationFor(
    VenueSearchQuery query, {
    String? venueId,
  }) {
    return SearchRouteParams(
      query: query.query,
      categorySlug: query.categorySlug,
      city: query.city,
      minPrice: query.minPrice,
      maxPrice: query.maxPrice,
      sortBy: query.sortBy,
      venueId: venueId,
      latitude: query.latitude,
      longitude: query.longitude,
      radiusKm: query.radiusKm,
      pincode: query.pincode,
    ).mapLocation;
  }

  String _location(String path) {
    final params = <String, String>{};
    if (query.trim().isNotEmpty) params[queryParam] = query.trim();
    if (categorySlug != null && categorySlug!.trim().isNotEmpty) {
      params[categoryParam] = categorySlug!.trim();
    }
    if (city != null && city!.trim().isNotEmpty) {
      params[cityParam] = city!.trim();
    }
    if (minPrice != null) params[minPriceParam] = _formatNumber(minPrice!);
    if (maxPrice != null) params[maxPriceParam] = _formatNumber(maxPrice!);
    if (sortBy != VenueSortBy.relevance) params[sortParam] = sortBy.name;
    if (venueId != null && venueId!.trim().isNotEmpty) {
      params[venueIdParam] = venueId!.trim();
    }
    if (latitude != null) params[latParam] = latitude!.toString();
    if (longitude != null) params[lngParam] = longitude!.toString();
    if (radiusKm != null && radiusKm! > 0) {
      params[radiusParam] = radiusKm!.toString();
    }
    if (pincode != null && pincode!.trim().isNotEmpty) {
      params[pinParam] = pincode!.trim();
    }
    return Uri(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  static int? _parseInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }

  static VenueSortBy _parseSort(String? value) {
    if (value == null || value.isEmpty) return VenueSortBy.relevance;
    for (final item in VenueSortBy.values) {
      if (item.name == value) return item;
    }
    return VenueSortBy.relevance;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }
}
