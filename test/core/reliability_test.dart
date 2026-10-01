import 'dart:async' as dart_async;

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/network/circuit_breaker.dart';
import 'package:bookmyspace/core/network/idempotency.dart';
import 'package:bookmyspace/core/network/retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('withReadRetry retries network reads and then succeeds', () async {
    var attempts = 0;
    final result = await withReadRetry(() async {
      attempts += 1;
      if (attempts < 3) {
        throw const NetworkException('down', code: 'network');
      }
      return 'ok';
    });
    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('withReadRetry does not retry payment errors', () async {
    var attempts = 0;
    await expectLater(
      withReadRetry(() async {
        attempts += 1;
        throw Exception('payment_provider_invalid');
      }),
      throwsA(isA<Exception>()),
    );
    expect(attempts, 1);
  });

  test('circuit breaker opens after consecutive failures', () async {
    final clock = <DateTime>[DateTime.utc(2026, 1, 1)];
    final breaker = CircuitBreaker(
      failureThreshold: 2,
      resetTimeout: const Duration(seconds: 30),
      clock: () => clock.first,
    );
    Future<void> fail() => breaker.execute(() async {
          throw const NetworkException('down', code: 'network');
        });

    await expectLater(fail(), throwsA(isA<NetworkException>()));
    await expectLater(fail(), throwsA(isA<NetworkException>()));
    await expectLater(fail(), throwsA(isA<CircuitOpenException>()));
    expect(breaker.state, CircuitState.open);
  });

  test('idempotency keys are unique per call', () {
    expect(IdempotencyKey.create('pay'), isNot(IdempotencyKey.create('pay')));
  });

  test('retry wrapper bounds a hung read', () async {
    Object? error;
    try {
      await withReadRetry(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 1;
        },
        config: const RetryConfig(
          maxRetries: 1,
          timeout: Duration(milliseconds: 5),
        ),
      );
    } catch (e) {
      error = e;
    }
    expect(error, isA<dart_async.TimeoutException>());
  });
}
