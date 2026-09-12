import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../venues/domain/venue.dart';

enum DiscoveryLocationSource { none, city, gps, pin }

/// User-chosen discovery location. Never inferred and never mutated from
/// `build()` / `initState()`.
class DiscoveryLocation {
  const DiscoveryLocation({
    this.city,
    this.district,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
    this.source = DiscoveryLocationSource.none,
    this.labelOverride,
  });

  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final int radiusKm;
  final DiscoveryLocationSource source;
  final String? labelOverride;

  bool get hasCity => city != null && city!.trim().isNotEmpty;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get label {
    if (labelOverride != null && labelOverride!.trim().isNotEmpty) {
      return labelOverride!.trim();
    }
    if (hasCity) return city!.trim();
    if (pincode != null && pincode!.trim().isNotEmpty) return pincode!.trim();
    return 'Select location';
  }

  DiscoveryLocation copyWith({
    String? city,
    String? district,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    int? radiusKm,
    DiscoveryLocationSource? source,
    String? labelOverride,
    bool clearCity = false,
    bool clearCoordinates = false,
    bool clearPin = false,
  }) {
    return DiscoveryLocation(
      city: clearCity ? null : (city ?? this.city),
      district: clearCity ? null : (district ?? this.district),
      state: clearCity ? null : (state ?? this.state),
      pincode: clearPin || clearCity ? null : (pincode ?? this.pincode),
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      radiusKm: radiusKm ?? this.radiusKm,
      source: source ?? this.source,
      labelOverride: clearCity ? null : (labelOverride ?? this.labelOverride),
    );
  }
}

class DiscoveryLocationNotifier extends StateNotifier<DiscoveryLocation> {
  DiscoveryLocationNotifier() : super(const DiscoveryLocation());

  void setCity(String? city) {
    final trimmed = city?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(
        clearCity: true,
        clearCoordinates: true,
        clearPin: true,
        source: DiscoveryLocationSource.none,
      );
      return;
    }
    state = state.copyWith(
      city: trimmed,
      clearCoordinates: true,
      clearPin: true,
      source: DiscoveryLocationSource.city,
      labelOverride: trimmed,
    );
  }

  void applyGps({
    required double latitude,
    required double longitude,
    String? city,
    String? district,
    String? stateName,
    String? pincode,
    String? label,
  }) {
    state = DiscoveryLocation(
      city: city?.trim().isEmpty == true ? null : city?.trim(),
      district: district?.trim(),
      state: stateName?.trim(),
      pincode: pincode?.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusKm: state.radiusKm,
      source: DiscoveryLocationSource.gps,
      labelOverride: label,
    );
  }

  void applyPin({
    required String pincode,
    String? city,
    String? district,
    String? stateName,
    String? mandal,
    String? label,
  }) {
    state = DiscoveryLocation(
      city: city?.trim().isEmpty == true ? null : city?.trim(),
      district: district?.trim(),
      state: stateName?.trim(),
      pincode: pincode.trim(),
      radiusKm: state.radiusKm,
      source: DiscoveryLocationSource.pin,
      labelOverride: label ??
          [
            if (city != null && city.trim().isNotEmpty) city.trim(),
            if (mandal != null && mandal.trim().isNotEmpty) mandal.trim(),
            pincode.trim(),
          ].join(', '),
    );
  }

  void setRadiusKm(int km) {
    if (km <= 0 || km == state.radiusKm) return;
    state = state.copyWith(radiusKm: km);
  }
}

final discoveryLocationProvider =
    StateNotifierProvider<DiscoveryLocationNotifier, DiscoveryLocation>((ref) {
  return DiscoveryLocationNotifier();
});

extension DiscoverySearchQuery on DiscoveryLocation {
  /// Route location wins. Used when Search is opened from the tab bar without
  /// query parameters after the user applied GPS/PIN/city on Home.
  VenueSearchQuery mergeInto(VenueSearchQuery query) {
    final hasRouteLocation = query.hasCoordinates ||
        (query.city != null && query.city!.trim().isNotEmpty) ||
        (query.pincode != null && query.pincode!.trim().isNotEmpty);
    if (hasRouteLocation) return query;
    return query.copyWith(
      city: hasCity ? () => city : null,
      latitude: hasCoordinates ? () => latitude : null,
      longitude: hasCoordinates ? () => longitude : null,
      radiusKm: hasCoordinates ? () => radiusKm : null,
      pincode: (pincode != null && pincode!.trim().isNotEmpty)
          ? () => pincode
          : null,
    );
  }
}
