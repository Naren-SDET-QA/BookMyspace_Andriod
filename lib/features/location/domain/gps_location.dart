enum GpsPermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
}

enum GpsRequestStatus {
  notRequested,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  unavailable,
  timeout,
  success,
}

/// Full GPS UI / session state machine.
///
/// Every non-terminal loading phase must have a guaranteed exit via timeout,
/// user cancellation, or a mapped result. Never leave a spinner running.
enum GpsPhase {
  idle,
  requestingPermission,
  checkingService,
  loadingLocation,
  reverseGeocoding,
  success,
  permissionDenied,
  serviceDisabled,
  timeout,
  error,
}

extension GpsPhaseX on GpsPhase {
  bool get isBusy =>
      this == GpsPhase.requestingPermission ||
      this == GpsPhase.checkingService ||
      this == GpsPhase.loadingLocation ||
      this == GpsPhase.reverseGeocoding;

  bool get isFailure =>
      this == GpsPhase.permissionDenied ||
      this == GpsPhase.serviceDisabled ||
      this == GpsPhase.timeout ||
      this == GpsPhase.error;
}

class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.city,
    this.district,
    this.state,
    this.postalCode,
    this.area,
    this.label,
    this.geocodeFailed = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? city;
  final String? district;
  final String? state;
  final String? postalCode;
  final String? area;
  final String? label;

  /// True when coordinates are valid but reverse geocoding timed out or failed.
  final bool geocodeFailed;

  bool get hasCity => city != null && city!.trim().isNotEmpty;

  String get displayLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    final parts = <String>[
      if (area != null && area!.trim().isNotEmpty) area!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (district != null &&
          district!.trim().isNotEmpty &&
          district!.trim() != city?.trim())
        district!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty)
        postalCode!.trim(),
    ];
    return parts.isEmpty ? 'Current location' : parts.join(', ');
  }

  String get cityLabel {
    if (hasCity) return city!.trim();
    if (area != null && area!.trim().isNotEmpty) return area!.trim();
    return displayLabel;
  }
}

class GpsResult {
  const GpsResult({
    required this.status,
    this.fix,
    this.message,
  });

  final GpsRequestStatus status;
  final GpsFix? fix;
  final String? message;

  bool get isSuccess => status == GpsRequestStatus.success && fix != null;

  GpsPhase get phase => switch (status) {
        GpsRequestStatus.success => GpsPhase.success,
        GpsRequestStatus.permissionDenied ||
        GpsRequestStatus.permissionPermanentlyDenied =>
          GpsPhase.permissionDenied,
        GpsRequestStatus.serviceDisabled => GpsPhase.serviceDisabled,
        GpsRequestStatus.timeout => GpsPhase.timeout,
        GpsRequestStatus.unavailable => GpsPhase.error,
        GpsRequestStatus.notRequested => GpsPhase.idle,
      };
}

typedef GpsPhaseCallback = void Function(GpsPhase phase);

abstract interface class GpsLocationService {
  Future<bool> isServiceEnabled();

  Future<GpsPermissionState> checkPermission();

  /// Requests OS permission and a current fix. Call only from an explicit
  /// user action, never from `build()` or `initState()`.
  ///
  /// [locationTimeout] bounds the coordinate request.
  /// [geocodeTimeout] bounds reverse geocoding. A geocode failure still
  /// returns coordinates.
  Future<GpsResult> requestCurrentLocation({
    GpsPhaseCallback? onPhase,
    Duration locationTimeout = const Duration(seconds: 10),
    Duration geocodeTimeout = const Duration(seconds: 10),
  });

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
