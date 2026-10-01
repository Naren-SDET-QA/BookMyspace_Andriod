import 'package:bookmyspace/features/admin_payment/domain/payment_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String paymentStatus = 'captured',
  String bookingStatus = 'confirmed',
  String reconciliationFlag = 'ok',
  bool webhookReceived = true,
  String? providerPaymentId = 'pay_abc123',
}) {
  return {
    'payment_id': 'pay-1',
    'booking_id': 'bk-1',
    'booking_reference': 'BMS-ABCDEF',
    'venue_id': 'venue-1',
    'venue_name': 'Test Venue',
    'amount': 1000.50,
    'currency': 'INR',
    'payment_status': paymentStatus,
    'booking_status': bookingStatus,
    'approval_status': 'approved',
    'provider_order_id': 'order_abc123',
    'provider_payment_id': providerPaymentId,
    'webhook_received': webhookReceived,
    'reconciliation_flag': reconciliationFlag,
    'payment_created_at': '2026-09-13T04:35:27.099Z',
    'payment_updated_at': '2026-09-13T05:10:00.061Z',
    'booking_created_at': '2026-09-13T04:35:26.083Z',
    'total_count': 15,
  };
}

void main() {
  test('parses a real admin_list_payment_transactions row', () {
    final tx = PaymentTransaction.fromJson(_row());

    expect(tx.bookingReference, 'BMS-ABCDEF');
    expect(tx.amount, 1000.50);
    expect(tx.currency, 'INR');
    expect(tx.paymentStatus, 'captured');
    expect(tx.bookingStatus, 'confirmed');
    expect(tx.webhookReceived, isTrue);
    expect(tx.hasReconciliationException, isFalse);
  });

  test('flags a reconciliation exception row distinctly from an ok row', () {
    final ok = PaymentTransaction.fromJson(_row());
    final exception = PaymentTransaction.fromJson(
      _row(reconciliationFlag: 'captured_not_confirmed'),
    );

    expect(ok.hasReconciliationException, isFalse);
    expect(exception.hasReconciliationException, isTrue);
  });

  test('parsing tolerates unexpected extra keys without failing', () {
    final raw = _row();
    // The backend RPC never returns secret/signature material, but this
    // guards against the parser breaking if an unrelated extra key is
    // ever present in a row.
    raw['unexpected_extra_field'] = 'ignored';

    expect(() => PaymentTransaction.fromJson(raw), returnsNormally);
  });

  group('PaymentTransactionPage', () {
    test('computes pagination from server total_count', () {
      final page = PaymentTransactionPage(
        items: List.filled(5, PaymentTransaction.fromJson(_row())),
        totalCount: 15,
        page: 1,
        pageSize: 5,
      );

      expect(page.totalPages, 3);
      expect(page.hasNextPage, isTrue);
      expect(page.hasPreviousPage, isFalse);
    });

    test('reports no next page on the last page', () {
      final page = PaymentTransactionPage(
        items: List.filled(5, PaymentTransaction.fromJson(_row())),
        totalCount: 15,
        page: 3,
        pageSize: 5,
      );

      expect(page.hasNextPage, isFalse);
      expect(page.hasPreviousPage, isTrue);
    });

    test('empty ledger reports a single page and no next/previous', () {
      final page = PaymentTransactionPage(
        items: const [],
        totalCount: 0,
        page: 1,
        pageSize: 20,
      );

      expect(page.totalPages, 1);
      expect(page.hasNextPage, isFalse);
      expect(page.hasPreviousPage, isFalse);
    });
  });

  group('PaymentTransactionFilter', () {
    test('resets pagination-relevant fields via copyWith clears', () {
      const filter = PaymentTransactionFilter(
        paymentStatus: 'captured',
        bookingStatus: 'confirmed',
        search: 'BMS-1',
      );

      final cleared = filter.copyWith(
        clearPaymentStatus: true,
        clearBookingStatus: true,
        clearSearch: true,
      );

      expect(cleared.paymentStatus, isNull);
      expect(cleared.bookingStatus, isNull);
      expect(cleared.search, isNull);
    });

    test(
        'kPaymentStatusValues and kBookingStatusValues match the deployed enums',
        () {
      expect(
          kPaymentStatusValues,
          containsAll(<String>[
            'pending',
            'authorized',
            'captured',
            'failed',
            'refunded',
            'partially_refunded',
          ]));
      expect(
          kBookingStatusValues,
          containsAll(<String>[
            'held',
            'pending',
            'confirmed',
            'completed',
            'cancelled',
            'refunded',
            'no_show',
            'awaiting_owner_approval',
            'owner_rejected',
            'approval_expired',
          ]));
    });
  });
}
