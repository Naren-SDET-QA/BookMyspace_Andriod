import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/presentation/module_manifests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backend module state and keeps platform restrictions', () {
    final flag = FeatureFlag.fromJson({
      'key': 'events',
      'enabled': true,
      'platforms': ['ios', 'android'],
      'config': {'max_items': 12},
      'updated_at': '2026-09-12T10:00:00Z',
    });

    expect(flag.enabledFor('ios'), isTrue);
    expect(flag.enabledFor('web'), isFalse);
    expect(flag.config['max_items'], 12);
  });

  test('referrals default to disabled without backend configuration', () {
    final referrals = moduleManifestFor('referrals')!.fallback();

    expect(referrals.enabled, isFalse);
    expect(referrals.config['expiry_days'], 30);
  });
}
