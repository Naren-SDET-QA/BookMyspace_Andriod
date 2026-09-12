import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/gps_location.dart';

class GeolocatorGpsLocationService implements GpsLocationService {
  const GeolocatorGpsLocationService();

  static const kLocationTimeout = Duration(seconds: 10);
  static const kGeocodeTimeout = Duration(seconds: 10);
  static const _probeTimeout = Duration(seconds: 4);

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<GpsPermissionState> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<GpsResult> requestCurrentLocation({
    GpsPhaseCallback? onPhase,
    Duration locationTimeout = kLocationTimeout,
    Duration geocodeTimeout = kGeocodeTimeout,
  }) async {
    void emit(GpsPhase phase) => onPhase?.call(phase);

    try {
      emit(GpsPhase.checkingService);
      final bool enabled;
      try {
        enabled = await Geolocator.isLocationServiceEnabled()
            .timeout(_probeTimeout);
      } on TimeoutException {
        return const GpsResult(
          status: GpsRequestStatus.timeout,
          message: 'Location request timed out',
        );
      }
      if (!enabled) {
        return const GpsResult(
          status: GpsRequestStatus.serviceDisabled,
          message: 'Location Services are off',
        );
      }

      emit(GpsPhase.requestingPermission);
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission().timeout(_probeTimeout);
      } on TimeoutException {
        return const GpsResult(
          status: GpsRequestStatus.timeout,
          message: 'Location request timed out',
        );
      }
      if (permission == LocationPermission.denied) {
        // OS dialog — do not time this out while the user is deciding.
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const GpsResult(
          status: GpsRequestStatus.permissionDenied,
          message: 'Location permission is off',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const GpsResult(
          status: GpsRequestStatus.permissionPermanentlyDenied,
          message: 'Location permission is off',
        );
      }

      emit(GpsPhase.loadingLocation);
      final Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: locationTimeout,
          ),
        ).timeout(locationTimeout);
      } on TimeoutException {
        return const GpsResult(
          status: GpsRequestStatus.timeout,
          message: 'Location request timed out',
        );
      }

      emit(GpsPhase.reverseGeocoding);
      String? city;
      String? district;
      String? state;
      String? postalCode;
      String? area;
      String? label;
      var geocodeFailed = false;
      try {
        final marks = await Geocoding()
            .placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            )
            .timeout(geocodeTimeout);
        if (marks.isNotEmpty) {
          final place = marks.first;
          area = _firstNonEmpty([
            place.subLocality,
            place.thoroughfare,
          ]);
          city = _firstNonEmpty([
            place.locality,
            place.subAdministrativeArea,
            place.name,
          ]);
          district = _firstNonEmpty([
            place.subAdministrativeArea,
            place.locality,
          ]);
          state = _firstNonEmpty([place.administrativeArea]);
          postalCode = _firstNonEmpty([place.postalCode]);
          label = [
            if (area != null) area,
            if (city != null) city,
            if (state != null) state,
            if (postalCode != null) postalCode,
          ].join(', ');
        }
      } on TimeoutException {
        geocodeFailed = true;
      } catch (_) {
        geocodeFailed = true;
      }

      if (city == null && area == null && (label == null || label.isEmpty)) {
        label =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }

      return GpsResult(
        status: GpsRequestStatus.success,
        fix: GpsFix(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          city: city,
          district: district,
          state: state,
          postalCode: postalCode,
          area: area,
          label: label,
          geocodeFailed: geocodeFailed,
        ),
      );
    } on PermissionDeniedException {
      return const GpsResult(
        status: GpsRequestStatus.permissionDenied,
        message: 'Location permission is off',
      );
    } on LocationServiceDisabledException {
      return const GpsResult(
        status: GpsRequestStatus.serviceDisabled,
        message: 'Location Services are off',
      );
    } on TimeoutException {
      return const GpsResult(
        status: GpsRequestStatus.timeout,
        message: 'Location request timed out',
      );
    } on app_errors.TimeoutException {
      return const GpsResult(
        status: GpsRequestStatus.timeout,
        message: 'Location request timed out',
      );
    } catch (error) {
      final mapped = app_errors.mapError(error);
      final text = mapped.message.toLowerCase();
      if (text.contains('timeout') || text.contains('time out')) {
        return const GpsResult(
          status: GpsRequestStatus.timeout,
          message: 'Location request timed out',
        );
      }
      return GpsResult(
        status: GpsRequestStatus.unavailable,
        message: mapped.message,
      );
    }
  }

  static GpsPermissionState _mapPermission(LocationPermission permission) {
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return GpsPermissionState.granted;
    }
    if (permission == LocationPermission.deniedForever) {
      return GpsPermissionState.permanentlyDenied;
    }
    if (permission == LocationPermission.denied) {
      return GpsPermissionState.denied;
    }
    return GpsPermissionState.notRequested;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
