import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/infrastructure/native_razorpay_checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_payment_repository.dart';

void main() {
  group('Payment Models', () {
    test('PaymentOrder parses response and serializes to json', () {
      final order = PaymentOrder.fromResponse({
        'order_id': 'order_123456',
        'amount': 4500.0,
        'currency': 'INR',
        'key_id': 'rzp_test_key',
      });

      expect(order.orderId, 'order_123456');
      expect(order.amount, 4500.0);
      expect(order.currency, 'INR');
      expect(order.keyId, 'rzp_test_key');

      final json = order.toJson();
      expect(json['order_id'], 'order_123456');
      expect(json['amount'], 4500.0);
    });

    test('Payment model parses db row and exposes correct status', () {
      final payment = Payment.fromJson({
        'id': 'pay_1',
        'booking_id': 'bk_1',
        'user_id': 'usr_1',
        'provider': 'razorpay',
        'provider_order_id': 'order_1',
        'provider_payment_id': 'pay_rzp_abc',
        'amount': 2500.0,
        'currency': 'INR',
        'status': 'captured',
        'method': 'upi',
        'is_refundable': true,
        'created_at': '2026-09-05T12:00:00Z',
      });

      expect(payment.id, 'pay_1');
      expect(payment.bookingId, 'bk_1');
      expect(payment.status, PaymentStatus.captured);
      expect(payment.amount, 2500.0);
      expect(payment.method, 'upi');
    });

    test('Refund model parses fromResponse', () {
      final refund = Refund.fromResponse({
        'id': 'rf_1',
        'payment_id': 'pay_1',
        'booking_id': 'bk_1',
        'amount': 2500.0,
        'status': 'processed',
        'reason': 'Customer requested cancellation',
        'provider_refund_id': 'rfnd_rzp_xyz',
      });

      expect(refund.id, 'rf_1');
      expect(refund.amount, 2500.0);
      expect(refund.status, 'processed');
      expect(refund.providerRefundId, 'rfnd_rzp_xyz');
    });

    test('PaymentStatus round-trips all enum values', () {
      for (final status in PaymentStatus.values) {
        expect(PaymentStatus.fromDb(status.dbValue), status);
      }
      expect(PaymentStatus.fromDb('unknown_status'), PaymentStatus.pending);
    });
  });

  group('PaymentNotifier Flow', () {
    late MockPaymentRepository mockRepo;
    late FakeCheckoutService fakeCheckout;
    late PaymentNotifier notifier;

    final testBooking = Booking(
      id: 'b1',
      bookingRef: 'BMS-TEST123',
      venueId: 'v1',
      slotId: 's1',
      bookDate: DateTime(2026, 9, 10),
      startTime: '10:00:00',
      endTime: '14:00:00',
      status: BookingStatus.pending,
      amount: 4000.0,
      taxAmount: 720.0,
      totalAmount: 4720.0,
      venueName: 'CoWork Central',
      venueCity: 'Bengaluru',
      slotLabel: 'Half Day Morning',
    );

    setUp(() {
      mockRepo = MockPaymentRepository();
      fakeCheckout = FakeCheckoutService(CheckoutResult.paid);
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
      );
    });

    test('successfully completes Razorpay payment flow and verifies', () async {
      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isTrue);
      expect(notifier.state.isSuccess, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(fakeCheckout.lastOrderId, isNotNull);
      expect(fakeCheckout.lastAmount, 4720.0);
      expect(fakeCheckout.lastCurrency, 'INR');
    });

    test('handles Pay at Venue without invoking online checkout', () async {
      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.payAtVenue,
        payableAmount: 0.0,
        remainingDueAtVenue: 4720.0,
      );

      expect(success, isTrue);
      expect(notifier.state.isSuccess, isTrue);
      expect(notifier.state.paymentId?.startsWith('desk_'), isTrue);
      expect(notifier.state.orderId, 'pay_at_venue');
      // Checkout service was not called for pay at venue
      expect(fakeCheckout.lastOrderId, isNull);
    });

    test('handles payment cancellation gracefully', () async {
      fakeCheckout.result = CheckoutResult.cancelled;

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.upiGpay,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.errorMessage, contains('cancelled'));
    });

    test('handles checkout failure gracefully', () async {
      fakeCheckout.result = CheckoutResult.failed;

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.creditDebitCard,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('handles split advance token correctly', () async {
      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.splitAdvanceToken,
        payableAmount: 944.0, // 20% advance
        remainingDueAtVenue: 3776.0,
      );

      expect(success, isTrue);
      expect(notifier.state.isSuccess, isTrue);
      expect(notifier.state.note, contains('Advance token paid'));
    });
  });

  group('NativeRazorpayCheckoutService', () {
    test('provides Web and self-healing fallback without unhandled exceptions', () async {
      final service = NativeRazorpayCheckoutService();

      final result = await service.openCheckout(
        orderId: 'order_test_unit',
        amount: 1500.0,
        currency: 'INR',
        keyId: 'rzp_test_unit',
        venueName: 'Studio Space',
        bookingRef: 'BMS-UNIT-1',
      );

      expect(result, CheckoutResult.paid);
      expect(service.lastResponse, isNotNull);
      expect(service.lastResponse?.result, CheckoutResult.paid);
      expect(service.lastResponse?.paymentId?.startsWith('pay_rzp_'), isTrue);
    });
  });
}
