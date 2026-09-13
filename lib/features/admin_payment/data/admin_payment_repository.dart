import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/payment_health.dart';
import '../domain/payment_transaction.dart';

/// Read-only repository for the Admin Payment Operations area
/// (Payment Health + Transaction Ledger).
///
/// This repository NEVER mutates payment or booking state. It calls only
/// the two `SECURITY DEFINER` observability RPCs
/// (`admin_get_payment_health`, `admin_list_payment_transactions`), which
/// themselves enforce `is_platform_admin()` authorization server-side.
/// Authorization is never assumed or duplicated on the client.
abstract interface class AdminPaymentRepository {
  Future<PaymentHealth> getPaymentHealth({
    required DateTime from,
    required DateTime to,
  });

  Future<PaymentTransactionPage> listTransactions({
    required int page,
    required int pageSize,
    PaymentTransactionFilter filter = const PaymentTransactionFilter(),
  });
}

class SupabaseAdminPaymentRepository implements AdminPaymentRepository {
  SupabaseAdminPaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentHealth> getPaymentHealth({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_get_payment_health',
        params: {
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
        },
      );
      if (response is! Map<String, dynamic>) {
        throw const app_errors.SerializationException(
          'Payment health data could not be read.',
        );
      }
      return PaymentHealth.fromJson(response);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<PaymentTransactionPage> listTransactions({
    required int page,
    required int pageSize,
    PaymentTransactionFilter filter = const PaymentTransactionFilter(),
  }) async {
    try {
      final response = await _client.rpc(
        'admin_list_payment_transactions',
        params: {
          'p_page': page,
          'p_page_size': pageSize,
          if (filter.from != null)
            'p_from': filter.from!.toUtc().toIso8601String(),
          if (filter.to != null) 'p_to': filter.to!.toUtc().toIso8601String(),
          if (filter.paymentStatus != null)
            'p_payment_status': filter.paymentStatus,
          if (filter.bookingStatus != null)
            'p_booking_status': filter.bookingStatus,
          if (filter.venueId != null) 'p_venue_id': filter.venueId,
          if (filter.search != null && filter.search!.trim().isNotEmpty)
            'p_search': filter.search!.trim(),
        },
      );
      final rows = (response as List?) ?? const [];
      final items = rows
          .map((row) => PaymentTransaction.fromJson(row as Map<String, dynamic>))
          .toList();
      final totalCount = items.isEmpty
          ? 0
          : ((rows.first as Map<String, dynamic>)['total_count'] as num?)?.toInt() ?? 0;
      return PaymentTransactionPage(
        items: items,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
