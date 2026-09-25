import 'package:bookmyspace/features/admin_payment/domain/payment_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a real admin_get_payment_health RPC response', () {
    final health = PaymentHealth.fromJson({
      'range_from': '2026-08-14T00:00:00Z',
      'range_to': '2026-09-13T00:00:00Z',
      'total_transactions': 15,
      'captured_count': 0,
      'pending_count': 0,
      'failed_count': 15,
      'refunded_count': 0,
      'captured_amount': 0,
      'pending_amount': 0,
      'success_rate': 0.0,
      'reconciliation_exceptions': 0,
      'webhook_missing_count': 0,
    });

    expect(health.totalTransactions, 15);
    expect(health.failedCount, 15);
    expect(health.successRate, 0.0);
    expect(health.hasExceptions, isFalse);
  });

  test('never fabricates a success rate when there is no captured/failed activity', () {
    final health = PaymentHealth.fromJson({
      'range_from': '2026-08-14T00:00:00Z',
      'range_to': '2026-09-13T00:00:00Z',
      'total_transactions': 0,
      'captured_count': 0,
      'pending_count': 0,
      'failed_count': 0,
      'refunded_count': 0,
      'captured_amount': 0,
      'pending_amount': 0,
      'success_rate': null,
      'reconciliation_exceptions': 0,
      'webhook_missing_count': 0,
    });

    expect(health.successRate, isNull);
    expect(health.status, PaymentHealthStatus.unavailable);
  });

  test('status is critical only when real reconciliation exceptions exist', () {
    final health = PaymentHealth.fromJson({
      'range_from': '2026-08-14T00:00:00Z',
      'range_to': '2026-09-13T00:00:00Z',
      'total_transactions': 4,
      'captured_count': 3,
      'pending_count': 0,
      'failed_count': 1,
      'refunded_count': 0,
      'captured_amount': 1000,
      'pending_amount': 0,
      'success_rate': 75.0,
      'reconciliation_exceptions': 1,
      'webhook_missing_count': 0,
    });

    expect(health.status, PaymentHealthStatus.critical);
  });

  test('status is attention when only webhooks are missing', () {
    final health = PaymentHealth.fromJson({
      'range_from': '2026-08-14T00:00:00Z',
      'range_to': '2026-09-13T00:00:00Z',
      'total_transactions': 4,
      'captured_count': 4,
      'pending_count': 0,
      'failed_count': 0,
      'refunded_count': 0,
      'captured_amount': 1000,
      'pending_amount': 0,
      'success_rate': 100.0,
      'reconciliation_exceptions': 0,
      'webhook_missing_count': 2,
    });

    expect(health.status, PaymentHealthStatus.attention);
  });

  test('status is healthy with no exceptions and a strong success rate', () {
    final health = PaymentHealth.fromJson({
      'range_from': '2026-08-14T00:00:00Z',
      'range_to': '2026-09-13T00:00:00Z',
      'total_transactions': 10,
      'captured_count': 10,
      'pending_count': 0,
      'failed_count': 0,
      'refunded_count': 0,
      'captured_amount': 50000,
      'pending_amount': 0,
      'success_rate': 100.0,
      'reconciliation_exceptions': 0,
      'webhook_missing_count': 0,
    });

    expect(health.status, PaymentHealthStatus.healthy);
  });
}
