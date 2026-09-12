import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/gps_location.dart';
import '../domain/pin_code_location.dart';
import '../infrastructure/geolocator_gps_location_service.dart';
import '../infrastructure/india_post_pin_code_repository.dart';

final gpsLocationServiceProvider = Provider<GpsLocationService>((ref) {
  return const GeolocatorGpsLocationService();
});

final pinCodeRepositoryProvider = Provider<PinCodeRepository>((ref) {
  return IndiaPostPinCodeRepository(client: ref.watch(supabaseProvider));
});
