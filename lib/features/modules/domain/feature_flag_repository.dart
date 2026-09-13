import 'feature_flag.dart';

abstract interface class FeatureFlagRepository {
  Future<List<FeatureFlag>> listFlags();

  /// Backend RLS and server-side config validation remain authoritative.
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  });
}
