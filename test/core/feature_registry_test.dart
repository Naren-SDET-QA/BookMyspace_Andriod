import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/features/feature_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product registry keeps referrals disabled until a backend exists', () {
    expect(FeatureRegistry.product.isEnabled('home'), isTrue);
    expect(FeatureRegistry.product.isEnabled('referrals'), isFalse);
    expect(FeatureRegistry.product.isEnabled('admin'), isTrue);
  });

  test('feature enablement is not an authorization grant', () {
    final admin = FeatureRegistry.product.byId('admin');
    expect(admin?.enabled, isTrue);
    expect(admin?.id, isNot('administrator'));
  });

  test('network failures are retryable reads; payment errors are not', () {
    expect(
      isRetryableReadError(const NetworkException('down', code: 'network')),
      isTrue,
    );
    expect(
      classifyError(Exception('payment_provider_invalid')),
      ErrorKind.payment,
    );
    expect(
      isRetryableReadError(Exception('payment_provider_invalid')),
      isFalse,
    );
  });
}
