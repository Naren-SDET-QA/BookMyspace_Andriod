/// Read-only, aggregate payment operations health for the Admin Payment
/// Operations area. All figures are derived from real `payments` /
/// `bookings` / `webhook_events` data via the `admin_get_payment_health`
/// backend RPC. Nothing here is invented, mocked, or hardcoded.
class PaymentHealth {
  const PaymentHealth({
    required this.rangeFrom,
    required this.rangeTo,
    required this.totalTransactions,
    required this.capturedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.refundedCount,
    required this.capturedAmount,
    required this.pendingAmount,
    required this.successRate,
    required this.reconciliationExceptions,
    required this.webhookMissingCount,
  });

  factory PaymentHealth.fromJson(Map<String, dynamic> json) {
    return PaymentHealth(
      rangeFrom: DateTime.parse(json['range_from'] as String),
      rangeTo: DateTime.parse(json['range_to'] as String),
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      capturedCount: (json['captured_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      refundedCount: (json['refunded_count'] as num?)?.toInt() ?? 0,
      capturedAmount: (json['captured_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0,
      // success_rate is intentionally nullable: when there is no captured or
      // failed activity in the selected range, the backend returns null
      // rather than a misleading 0% or 100%.
      successRate: (json['success_rate'] as num?)?.toDouble(),
      reconciliationExceptions:
          (json['reconciliation_exceptions'] as num?)?.toInt() ?? 0,
      webhookMissingCount:
          (json['webhook_missing_count'] as num?)?.toInt() ?? 0,
    );
  }

  final DateTime rangeFrom;
  final DateTime rangeTo;
  final int totalTransactions;
  final int capturedCount;
  final int pendingCount;
  final int failedCount;
  final int refundedCount;
  final double capturedAmount;
  final double pendingAmount;
  final double? successRate;
  final int reconciliationExceptions;
  final int webhookMissingCount;

  bool get hasExceptions =>
      reconciliationExceptions > 0 || webhookMissingCount > 0;

  /// Overall operational status label. Derived strictly from the real
  /// counts above — never a decorative or fabricated indicator.
  PaymentHealthStatus get status {
    if (totalTransactions == 0) return PaymentHealthStatus.unavailable;
    if (reconciliationExceptions > 0) return PaymentHealthStatus.critical;
    if (webhookMissingCount > 0) return PaymentHealthStatus.attention;
    if (successRate != null && successRate! < 90) {
      return PaymentHealthStatus.warning;
    }
    return PaymentHealthStatus.healthy;
  }
}

enum PaymentHealthStatus { healthy, warning, attention, critical, unavailable }
