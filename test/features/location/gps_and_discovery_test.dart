import 'dart:async';

import 'package:bookmyspace/features/home/presentation/discovery_location.dart';
import 'package:bookmyspace/features/location/domain/gps_location.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/location/presentation/gps_session.dart';
import 'package:bookmyspace/features/location/presentation/location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGpsLocationService implements GpsLocationService {
  FakeGpsLocationService(
    this.result, {
    this.hang = false,
    this.delay,
  });

  GpsResult result;
  bool hang;
  Duration? delay;
  int requestCount = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;
  final _hang = Completer<GpsResult>();

  @override
  Future<GpsPermissionState> checkPermission() async =>
      GpsPermissionState.notRequested;

  @override
  Future<bool> isServiceEnabled() async =>
      result.status != GpsRequestStatus.serviceDisabled;

  @override
  Future<GpsResult> requestCurrentLocation({
    GpsPhaseCallback? onPhase,
    Duration locationTimeout = const Duration(seconds: 10),
    Duration geocodeTimeout = const Duration(seconds: 10),
  }) async {
    requestCount++;
    onPhase?.call(GpsPhase.checkingService);
    onPhase?.call(GpsPhase.loadingLocation);
    if (hang) return _hang.future;
    if (delay != null) await Future<void>.delayed(delay!);
    onPhase?.call(result.phase);
    return result;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }
}

void main() {
  test('successful GPS result exposes coordinates and label', () {
    const fix = GpsFix(
      latitude: 17.4483,
      longitude: 78.3915,
      city: 'Hyderabad',
      state: 'Telangana',
      postalCode: '500081',
      area: 'Madhapur',
    );
    const result = GpsResult(
      status: GpsRequestStatus.success,
      fix: fix,
    );
    expect(result.isSuccess, isTrue);
    expect(fix.displayLabel, contains('Madhapur'));
    expect(fix.latitude, isNot(0));
  });

  test('permission denied and unavailable states are distinct', () {
    expect(
      const GpsResult(status: GpsRequestStatus.permissionDenied).isSuccess,
      isFalse,
    );
    expect(
      const GpsResult(status: GpsRequestStatus.unavailable).isSuccess,
      isFalse,
    );
    expect(
      const GpsResult(status: GpsRequestStatus.timeout).isSuccess,
      isFalse,
    );
    expect(
      const GpsResult(status: GpsRequestStatus.permissionDenied).phase,
      GpsPhase.permissionDenied,
    );
    expect(
      const GpsResult(status: GpsRequestStatus.serviceDisabled).phase,
      GpsPhase.serviceDisabled,
    );
  });

  test('geocode failure keeps valid coordinates', () {
    const fix = GpsFix(
      latitude: 15.8497,
      longitude: 74.4977,
      geocodeFailed: true,
    );
    const result = GpsResult(status: GpsRequestStatus.success, fix: fix);
    expect(result.isSuccess, isTrue);
    expect(fix.latitude, 15.8497);
    expect(fix.cityLabel, 'Current location');
  });

  test('fake GPS service can retry a later success', () async {
    final service = FakeGpsLocationService(
      const GpsResult(
        status: GpsRequestStatus.permissionDenied,
        message: 'denied',
      ),
    );
    expect((await service.requestCurrentLocation()).isSuccess, isFalse);
    service.result = const GpsResult(
      status: GpsRequestStatus.success,
      fix: GpsFix(latitude: 13.0827, longitude: 80.2707, city: 'Chennai'),
    );
    expect((await service.requestCurrentLocation()).isSuccess, isTrue);
  });

  test('discovery location merges into Search only when the route has none', () {
    const gps = DiscoveryLocation(
      city: 'Hyderabad',
      latitude: 17.385,
      longitude: 78.4867,
      radiusKm: 10,
      source: DiscoveryLocationSource.gps,
    );
    const empty = VenueSearchQuery();
    final merged = gps.mergeInto(empty);
    expect(merged.city, 'Hyderabad');
    expect(merged.latitude, 17.385);
    expect(merged.longitude, 78.4867);
    expect(merged.radiusKm, 10);

    const routed = VenueSearchQuery(city: 'Bengaluru');
    expect(gps.mergeInto(routed).city, 'Bengaluru');
    expect(gps.mergeInto(routed).latitude, isNull);
  });

  test('discovery location applies GPS, PIN, and city without build mutation',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(discoveryLocationProvider).hasCity, isFalse);

    container.read(discoveryLocationProvider.notifier).applyGps(
          latitude: 12.9716,
          longitude: 77.5946,
          city: 'Bengaluru',
          stateName: 'Karnataka',
          label: 'Bengaluru, Karnataka',
        );
    expect(container.read(discoveryLocationProvider).hasCoordinates, isTrue);
    expect(container.read(discoveryLocationProvider).city, 'Bengaluru');
    expect(
      container.read(discoveryLocationProvider).source,
      DiscoveryLocationSource.gps,
    );

    container.read(discoveryLocationProvider.notifier).applyPin(
          pincode: '600001',
          city: 'Chennai G.P.O.',
          district: 'Chennai',
          stateName: 'Tamil Nadu',
        );
    expect(container.read(discoveryLocationProvider).pincode, '600001');
    expect(
      container.read(discoveryLocationProvider).source,
      DiscoveryLocationSource.pin,
    );
    expect(container.read(discoveryLocationProvider).hasCoordinates, isFalse);

    container.read(discoveryLocationProvider.notifier).setCity('Pune');
    expect(container.read(discoveryLocationProvider).city, 'Pune');
    expect(container.read(discoveryLocationProvider).pincode, isNull);
  });

  test('GPS session ignores duplicate in-flight requests', () async {
    final service = FakeGpsLocationService(
      const GpsResult(
        status: GpsRequestStatus.success,
        fix: GpsFix(latitude: 1, longitude: 2, city: 'Pune'),
      ),
      hang: true,
    );
    final container = ProviderContainer(
      overrides: [
        gpsLocationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(gpsSessionProvider.notifier);
    unawaited(notifier.requestCurrentLocation());
    unawaited(notifier.requestCurrentLocation());
    await Future<void>.delayed(Duration.zero);
    expect(service.requestCount, 1);
    expect(container.read(gpsSessionProvider).isBusy, isTrue);
    notifier.cancelIfBusy();
    expect(container.read(gpsSessionProvider).isBusy, isFalse);
    expect(container.read(gpsSessionProvider).phase, GpsPhase.idle);
  });

  test('hanging GPS request always exits via overall timeout', () async {
    final service = FakeGpsLocationService(
      const GpsResult(status: GpsRequestStatus.unavailable),
      hang: true,
    );
    final container = ProviderContainer(
      overrides: [
        gpsLocationServiceProvider.overrideWithValue(service),
        gpsSessionProvider.overrideWith(
          (ref) => GpsSessionNotifier(
            ref.watch(gpsLocationServiceProvider),
            overallTimeout: const Duration(milliseconds: 40),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    unawaited(
      container.read(gpsSessionProvider.notifier).requestCurrentLocation(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final state = container.read(gpsSessionProvider);
    expect(state.isBusy, isFalse);
    expect(state.phase, GpsPhase.timeout);
    expect(state.message, 'Location request timed out');
  });

  test('permission denied maps to a terminal GPS phase', () async {
    final service = FakeGpsLocationService(
      const GpsResult(
        status: GpsRequestStatus.permissionDenied,
        message: 'Location permission is off',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        gpsLocationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    await container.read(gpsSessionProvider.notifier).requestCurrentLocation();
    expect(container.read(gpsSessionProvider).phase, GpsPhase.permissionDenied);
    expect(container.read(gpsSessionProvider).isBusy, isFalse);
  });

  test('GPS session is idle until an explicit user action', () {
    final container = ProviderContainer(
      overrides: [
        gpsLocationServiceProvider.overrideWithValue(
          FakeGpsLocationService(
            const GpsResult(
              status: GpsRequestStatus.success,
              fix: GpsFix(latitude: 1, longitude: 1),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(gpsSessionProvider).phase, GpsPhase.idle);
    expect(container.read(gpsSessionProvider).isBusy, isFalse);
  });
}
