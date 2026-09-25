import 'package:bookmyspace/features/receipts/domain/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'receipt_fixtures.dart';

void main() {
  group('parsing the server document', () {
    test('maps every field the migration returns', () {
      final document = ReceiptDocument.fromJson(serverDocument());

      expect(document.bookingId, '8f14e45f-ceea-467a-9c1c-3d6f1a2b4c5d');
      expect(document.bookingRef, 'BMS-883921');
      expect(document.status, 'confirmed');
      expect(document.currency, 'INR');
      expect(document.paymentRef, 'pay_dev_test_001');
      expect(document.paymentProvider, 'razorpay');
      expect(document.paymentMethod, 'upi');
      expect(document.totalPaid, 1770);
      expect(document.issuedAt, DateTime.utc(2026, 9, 1, 9, 30));
      expect(document.lineItems.baseAmount, 1500);
      expect(document.lineItems.taxAmount, 270);
      expect(document.lineItems.discountAmount, 0);
      expect(document.lineItems.taxRateReference, 18);
      expect(document.lineItems.platformFee, isNull);
      expect(document.omissions, ['platform_fee']);
    });

    test('maps the nested venue, slot and guest blocks', () {
      final document = ReceiptDocument.fromJson(serverDocument());

      expect(document.venue.name, 'Indiranagar Rooftop Arena');
      expect(
        document.venue.formattedAddress,
        '12th Main Road, Indiranagar, Bengaluru, Karnataka, 560038, IN',
      );
      expect(document.slot.label, 'Evening Prime');
      expect(document.slot.bookDate, DateTime(2026, 9, 20));
      expect(document.slot.startTime, '18:00:00');
      expect(document.slot.endTime, '19:00:00');
      expect(document.slot.quantity, 1);
      expect(document.guest.name, 'Asha Menon');
      expect(document.guest.email, 'asha@example.com');
      expect(document.guest.phone, '+91 98450 12345');
    });

    test('survives a document with missing blocks', () {
      final document = ReceiptDocument.fromJson(<String, dynamic>{
        'booking_id': 'abc',
      });

      expect(document.bookingId, 'abc');
      expect(document.bookingRef, '');
      expect(document.currency, 'INR', reason: 'defaulted, not blank');
      expect(document.totalPaid, 0);
      expect(document.lineItems.baseAmount, 0);
      expect(document.omissions, isEmpty);
      expect(document.venue.formattedAddress, isEmpty);
    });

    test('omits blank address parts instead of emitting stray commas', () {
      final document = ReceiptDocument.fromJson(<String, dynamic>{
        'venue': <String, dynamic>{
          'name': 'Bare Venue',
          'address_line1': '1 Road',
          'address_line2': '   ',
          'city': '',
        },
      });

      expect(document.venue.formattedAddress, '1 Road');
    });
  });

  group('line items', () {
    test('orders base, discount, tax and prints the discount as a credit', () {
      final items = ReceiptLineItems.fromJson(<String, dynamic>{
        'base_amount': 1500,
        'tax_amount': 270,
        'discount_amount': 200,
        'platform_fee': null,
      });

      final rows = items.rows();
      expect(
          rows.map((row) => row.label), ['Base amount', 'Discount', 'Taxes']);

      final discount = rows[1];
      expect(discount.isCredit, isTrue);
      expect(discount.amount, 200, reason: 'magnitude stays positive');
      expect(discount.signedAmount, -200, reason: 'sign is carried separately');
    });

    test('omits zero-valued lines rather than printing them', () {
      final items = ReceiptLineItems.fromJson(<String, dynamic>{
        'base_amount': 1500,
        'tax_amount': 0,
        'discount_amount': 0,
        'platform_fee': null,
      });

      expect(items.rows().map((row) => row.label), ['Base amount']);
    });

    test('omits the platform fee line while it is unrecorded', () {
      final items = ReceiptLineItems.fromJson(<String, dynamic>{
        'base_amount': 100,
        'platform_fee': null,
      });

      expect(
        items.rows().map((row) => row.label),
        isNot(contains('Platform fee')),
        reason: 'a zero-valued fee line asserts a fact nobody recorded',
      );
    });

    test('includes the platform fee line once a real value exists', () {
      final items = ReceiptLineItems.fromJson(<String, dynamic>{
        'base_amount': 100,
        'platform_fee': 15,
      });

      expect(items.rows().map((row) => row.label), contains('Platform fee'));
      expect(items.componentTotal, 115);
    });

    test('subtracts the discount when totalling', () {
      final items = ReceiptLineItems.fromJson(<String, dynamic>{
        'base_amount': 1500,
        'tax_amount': 270,
        'discount_amount': 200,
      });

      expect(items.componentTotal, 1570);
    });
  });

  group('reconciliation', () {
    test('reports agreement when the lines add up to the charge', () {
      final document = ReceiptDocument.fromJson(serverDocument());

      expect(document.lineItemsReconcile, isTrue);
      expect(document.unreconciledDifference, 0);
    });

    test('reports a mismatch rather than hiding it', () {
      final document = ReceiptDocument.fromJson(
        serverDocument(base: 1500, tax: 270, discount: 0, total: 1900),
      );

      expect(document.lineItemsReconcile, isFalse);
      expect(document.unreconciledDifference, 130);
    });

    test('recomputes rather than trusting the server flag', () {
      // The server claims the components add up; they do not. The client must
      // notice, or a breakdown that is wrong gets printed as if it were right.
      final raw = serverDocument(base: 1000, tax: 180, total: 9999);
      raw['reconciles'] = true;

      expect(ReceiptDocument.fromJson(raw).lineItemsReconcile, isFalse);
    });

    test('tolerates sub-paise float noise', () {
      final document = ReceiptDocument.fromJson(
        serverDocument(base: 0.1, tax: 0.2, discount: 0, total: 0.3),
      );

      expect(document.lineItemsReconcile, isTrue);
    });
  });

  group('money formatting', () {
    test('uses en_IN lakh grouping for rupee amounts', () {
      expect(formatReceiptMoney(1770, 'INR'), '₹1,770.00');
      expect(formatReceiptMoney(1234567.5, 'INR'), '₹12,34,567.50');
    });

    test('falls back to the ISO code rather than guessing a symbol', () {
      expect(currencySymbol('JPY'), 'JPY ');
      expect(formatReceiptMoney(500, 'JPY'), 'JPY 500.00');
    });

    test('knows the symbols for the currencies it trades in', () {
      expect(currencySymbol('INR'), '₹');
      expect(currencySymbol('USD'), r'$');
      expect(currencySymbol('EUR'), '€');
      expect(currencySymbol('GBP'), '£');
      expect(currencySymbol('sgd'), r'S$', reason: 'case-insensitive');
    });

    test('signs a credit amount with a leading hyphen', () {
      expect(formatReceiptMoney(-200, 'INR'), '-₹200.00');
    });
  });
}
