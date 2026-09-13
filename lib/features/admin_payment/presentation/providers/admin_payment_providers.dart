import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../data/admin_payment_repository.dart';
import '../../domain/payment_health.dart';
import '../../domain/payment_transaction.dart';

final adminPaymentRepositoryProvider = Provider<AdminPaymentRepository>((ref) {
  return SupabaseAdminPaymentRepository(ref.watch(supabaseProvider));
});

/// Selected date range for the Payment Health screen. Defaults to the
/// trailing 30 days; the user can change it from the screen's filter UI.
class PaymentHealthRangeNotifier extends StateNotifier<DateTimeRange> {
  PaymentHealthRangeNotifier()
      : super(
          DateTimeRange(
            from: DateTime.now().toUtc().subtract(const Duration(days: 30)),
            to: DateTime.now().toUtc(),
          ),
        );

  void setRange(DateTime from, DateTime to) {
    state = DateTimeRange(from: from, to: to);
  }
}

class DateTimeRange {
  const DateTimeRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;
}

final paymentHealthRangeProvider =
    StateNotifierProvider<PaymentHealthRangeNotifier, DateTimeRange>((ref) {
  return PaymentHealthRangeNotifier();
});

final paymentHealthProvider = FutureProvider.autoDispose<PaymentHealth>((ref) {
  final range = ref.watch(paymentHealthRangeProvider);
  return ref.watch(adminPaymentRepositoryProvider).getPaymentHealth(
        from: range.from,
        to: range.to,
      );
});

/// Ledger query state: current page, page size, and active filters.
class TransactionLedgerQuery {
  const TransactionLedgerQuery({
    this.page = 1,
    this.pageSize = 20,
    this.filter = const PaymentTransactionFilter(),
  });

  final int page;
  final int pageSize;
  final PaymentTransactionFilter filter;

  TransactionLedgerQuery copyWith({
    int? page,
    int? pageSize,
    PaymentTransactionFilter? filter,
  }) {
    return TransactionLedgerQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      filter: filter ?? this.filter,
    );
  }
}

class TransactionLedgerQueryNotifier
    extends StateNotifier<TransactionLedgerQuery> {
  TransactionLedgerQueryNotifier() : super(const TransactionLedgerQuery());

  void setPage(int page) => state = state.copyWith(page: page);

  void setFilter(PaymentTransactionFilter filter) {
    // Any filter change resets pagination to the first page.
    state = state.copyWith(filter: filter, page: 1);
  }
}

final transactionLedgerQueryProvider = StateNotifierProvider<
    TransactionLedgerQueryNotifier, TransactionLedgerQuery>((ref) {
  return TransactionLedgerQueryNotifier();
});

final transactionLedgerProvider =
    FutureProvider.autoDispose<PaymentTransactionPage>((ref) {
  final query = ref.watch(transactionLedgerQueryProvider);
  return ref.watch(adminPaymentRepositoryProvider).listTransactions(
        page: query.page,
        pageSize: query.pageSize,
        filter: query.filter,
      );
});
