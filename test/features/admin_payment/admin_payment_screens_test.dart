import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/admin_payment/domain/payment_health.dart';
import 'package:bookmyspace/features/admin_payment/domain/payment_transaction.dart';
import 'package:bookmyspace/features/admin_payment/presentation/providers/admin_payment_providers.dart';
import 'package:bookmyspace/features/admin_payment/presentation/screens/admin_payment_health_screen.dart';
import 'package:bookmyspace/features/admin_payment/presentation/screens/admin_transaction_ledger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_admin_payment_repository.dart';

Widget _wrap(Widget child, {required FakeAdminPaymentRepository repo}) {
  return ProviderScope(
    overrides: [adminPaymentRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

PaymentTransaction _tx({String reconciliationFlag = 'ok'}) {
  return PaymentTransaction.fromJson({
    'payment_id': 'pay-1',
    'booking_id': 'bk-1',
    'booking_reference': 'BMS-ABCDEF',
    'venue_id': 'venue-1',
    'venue_name': 'Test Venue',
    'amount': 1000.50,
    'currency': 'INR',
    'payment_status': 'captured',
    'booking_status': 'confirmed',
    'approval_status': 'approved',
    'provider_order_id': 'order_abc123',
    'provider_payment_id': 'pay_abc123',
    'webhook_received': true,
    'reconciliation_flag': reconciliationFlag,
    'payment_created_at': '2026-09-13T04:35:27.099Z',
    'payment_updated_at': '2026-09-13T05:10:00.061Z',
    'booking_created_at': '2026-09-13T04:35:26.083Z',
    'total_count': 1,
  });
}

void main() {
  group('AdminPaymentHealthScreen', () {
    testWidgets('shows a loading indicator before data arrives', (tester) async {
      final repo = FakeAdminPaymentRepository();
      await tester.pumpWidget(
        _wrap(const AdminPaymentHealthScreen(), repo: repo),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an empty state when there is no activity in range', (tester) async {
      final repo = FakeAdminPaymentRepository();
      await tester.pumpWidget(
        _wrap(const AdminPaymentHealthScreen(), repo: repo),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.query_stats_outlined), findsOneWidget);
    });

    testWidgets('shows real metric values, never a fabricated number', (tester) async {
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
      final repo = FakeAdminPaymentRepository(health: health);
      await tester.pumpWidget(
        _wrap(const AdminPaymentHealthScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('15'), findsWidgets);
      expect(find.text('0.0%'), findsOneWidget);
    });

    testWidgets('shows an error state with retry on backend failure', (tester) async {
      final repo = FakeAdminPaymentRepository(
        healthError: const AuthException('administrator_required'),
      );
      await tester.pumpWidget(
        _wrap(const AdminPaymentHealthScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsOneWidget);
      expect(repo.getPaymentHealthCallCount, 1);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repo.getPaymentHealthCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('contains no mutation controls anywhere on screen', (tester) async {
      final health = PaymentHealth.fromJson({
        'range_from': '2026-08-14T00:00:00Z',
        'range_to': '2026-09-13T00:00:00Z',
        'total_transactions': 5,
        'captured_count': 4,
        'pending_count': 1,
        'failed_count': 0,
        'refunded_count': 0,
        'captured_amount': 4000,
        'pending_amount': 1000,
        'success_rate': 100.0,
        'reconciliation_exceptions': 0,
        'webhook_missing_count': 0,
      });
      final repo = FakeAdminPaymentRepository(health: health);
      await tester.pumpWidget(
        _wrap(const AdminPaymentHealthScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      // No refund, confirm, capture, or approve buttons should ever exist
      // on a read-only operations screen.
      expect(find.widgetWithText(ElevatedButton, 'Refund'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Confirm'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Capture'), findsNothing);
    });
  });

  group('AdminTransactionLedgerScreen', () {
    testWidgets('shows an empty ledger state', (tester) async {
      final repo = FakeAdminPaymentRepository();
      await tester.pumpWidget(
        _wrap(const AdminTransactionLedgerScreen(), repo: repo),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.receipt_long_outlined), findsWidgets);
    });

    testWidgets('renders real ledger rows with no reconciliation exception styling by default', (tester) async {
      final repo = FakeAdminPaymentRepository(
        page: PaymentTransactionPage(
          items: [_tx()],
          totalCount: 1,
          page: 1,
          pageSize: 20,
        ),
      );
      await tester.pumpWidget(
        _wrap(const AdminTransactionLedgerScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('BMS-ABCDEF'), findsOneWidget);
    });

    testWidgets('shows an error state with retry on backend failure', (tester) async {
      final repo = FakeAdminPaymentRepository(
        pageError: const AuthException('administrator_required'),
      );
      await tester.pumpWidget(
        _wrap(const AdminTransactionLedgerScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('sending a search query calls the repository with that filter', (tester) async {
      final repo = FakeAdminPaymentRepository();
      await tester.pumpWidget(
        _wrap(const AdminTransactionLedgerScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('adminPaymentLedgerSearchField')),
        'BMS-ABCDEF',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.lastFilter?.search, 'BMS-ABCDEF');
    });
  });
}
