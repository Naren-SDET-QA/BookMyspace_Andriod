import 'package:bookmyspace/features/admin_payment/data/admin_payment_repository.dart';
import 'package:bookmyspace/features/admin_payment/domain/payment_health.dart';
import 'package:bookmyspace/features/admin_payment/domain/payment_transaction.dart';

/// Deterministic in-memory double for widget tests. Never touches Supabase.
class FakeAdminPaymentRepository implements AdminPaymentRepository {
  FakeAdminPaymentRepository({
    this.health,
    this.page = const PaymentTransactionPage(
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 20,
    ),
    this.healthError,
    this.pageError,
  });

  final PaymentHealth? health;
  final PaymentTransactionPage page;
  final Object? healthError;
  final Object? pageError;

  int getPaymentHealthCallCount = 0;
  int listTransactionsCallCount = 0;
  PaymentTransactionFilter? lastFilter;

  @override
  Future<PaymentHealth> getPaymentHealth({
    required DateTime from,
    required DateTime to,
  }) async {
    getPaymentHealthCallCount++;
    if (healthError != null) throw healthError!;
    return health ??
        PaymentHealth.fromJson({
          'range_from': from.toIso8601String(),
          'range_to': to.toIso8601String(),
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
  }

  @override
  Future<PaymentTransactionPage> listTransactions({
    required int page,
    required int pageSize,
    PaymentTransactionFilter filter = const PaymentTransactionFilter(),
  }) async {
    listTransactionsCallCount++;
    lastFilter = filter;
    if (pageError != null) throw pageError!;
    return this.page;
  }
}
