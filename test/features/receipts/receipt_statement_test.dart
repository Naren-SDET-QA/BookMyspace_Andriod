import 'package:bookmyspace/features/receipts/domain/receipt_statement.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receipt_fixtures.dart';

void main() {
  group('what the document is called', () {
    test('an issued receipt is called a receipt', () {
      final statement = ReceiptStatement(
        serverResult(receiptIssued: true, receiptNumber: 'BMS-R-ABC123'),
      );

      expect(statement.isReceipt, isTrue);
      expect(statement.title, 'Payment Receipt');
      expect(statement.numberLine, 'BMS-R-ABC123');
    });

    test('a booking with no captured payment is called a statement', () {
      final statement = ReceiptStatement(
        serverResult(
          receiptIssued: false,
          receiptNumber: null,
          document: serverDocument(
            omissions: const ['platform_fee', 'no_payment_recorded'],
          ),
        ),
      );

      expect(statement.isReceipt, isFalse);
      expect(
        statement.title,
        'Payment Statement',
        reason: 'a statement is not evidence of payment and must not be titled '
            'as though it were',
      );
      expect(statement.numberLine, 'No receipt number issued');
    });

    test('never leaves the number line blank', () {
      final pending = ReceiptStatement(
        serverResult(receiptIssued: true, receiptNumber: null),
      );
      final blank = ReceiptStatement(
        serverResult(receiptIssued: true, receiptNumber: '   '),
      );

      expect(pending.numberLine, 'Number pending');
      expect(blank.numberLine, 'Number pending');
    });
  });

  group('notes', () {
    test('explains why there is no receipt number', () {
      final statement = ReceiptStatement(
        serverResult(receiptIssued: false, receiptNumber: null),
      );

      expect(
        statement.notes.first,
        contains('no receipt number has been issued'),
        reason: 'the most important thing a reader needs comes first',
      );
      expect(statement.notes.first, contains('not evidence of payment'));
    });

    test('does not explain a missing number when one exists', () {
      final statement = ReceiptStatement(serverResult());

      expect(
        statement.notes.join(' '),
        isNot(contains('no receipt number has been issued')),
      );
    });

    test('discloses that platform fees could not be itemised', () {
      final statement = ReceiptStatement(
        serverResult(document: serverDocument(omissions: const ['platform_fee'])),
      );

      expect(
        statement.notes.any((note) => note.contains('Platform fees are not itemised')),
        isTrue,
      );
    });

    test('stays silent about platform fees when one was recorded', () {
      final statement = ReceiptStatement(
        serverResult(document: serverDocument(omissions: const [])),
      );

      expect(
        statement.notes.any((note) => note.contains('Platform fees')),
        isFalse,
      );
    });

    test('states the tax rate is a reference, not a source', () {
      final statement = ReceiptStatement(
        serverResult(document: serverDocument(taxRate: 18)),
      );

      final rate = statement.notes.firstWhere((n) => n.contains('tax rate'));
      expect(rate, contains('18%'));
      expect(rate, contains('not re-derived'));
    });

    test('says nothing about a rate when the venue has none', () {
      final statement = ReceiptStatement(
        serverResult(document: serverDocument(taxRate: null)),
      );

      expect(statement.notes.any((n) => n.contains('tax rate')), isFalse);
    });

    test('always states the document is a frozen snapshot', () {
      for (final issued in [true, false]) {
        final statement =
            ReceiptStatement(serverResult(receiptIssued: issued));
        expect(
          statement.notes.any((n) => n.contains('immutable snapshot')),
          isTrue,
          reason: 'a reader must know the document cannot have changed',
        );
      }
    });
  });

  group('reconciliation notice', () {
    test('is absent when the lines add up', () {
      final statement = ReceiptStatement(serverResult());

      expect(statement.needsReconciliationNotice, isFalse);
    });

    test('names both figures when they disagree', () {
      final statement = ReceiptStatement(
        serverResult(
          document: serverDocument(base: 1500, tax: 270, discount: 0, total: 1900),
        ),
      );

      expect(statement.needsReconciliationNotice, isTrue);
      expect(statement.reconciliationNotice, contains('₹1,770.00'));
      expect(statement.reconciliationNotice, contains('₹130.00'));
      expect(
        statement.reconciliationNotice,
        contains('authoritative'),
        reason: 'the charged amount wins, and the notice must say so',
      );
    });
  });

  group('rate formatting', () {
    test('drops trailing zeros', () {
      expect(ReceiptStatement.formatRate(18), '18');
      expect(ReceiptStatement.formatRate(18.0), '18');
      expect(ReceiptStatement.formatRate(12.5), '12.5');
      expect(ReceiptStatement.formatRate(5.25), '5.25');
    });
  });
}
