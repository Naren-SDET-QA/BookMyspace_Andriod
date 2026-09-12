import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/infrastructure/native_razorpay_checkout_service.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_payment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('completes checkout only after server booking confirmation', () async {
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

    test('does not turn order creation failure into payment success', () async {
      mockRepo.failCreateOrder = true;

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
      expect(fakeCheckout.lastOrderId, isNull);
    });

    test('uses the deployed Razorpay payment method', () async {
      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.values.first,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isTrue);
      expect(fakeCheckout.lastOrderId, 'order_1');
    });

    test('handles payment cancellation gracefully', () async {
      fakeCheckout.result = CheckoutResult.cancelled;

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
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
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('launches checkout with the server order amount, not the client total',
        () async {
      await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 1.0,
        remainingDueAtVenue: 0.0,
      );

      expect(fakeCheckout.lastAmount, 4720.0);
      expect(fakeCheckout.lastOrderId, 'order_1');
      expect(fakeCheckout.lastCurrency, 'INR');
    });

    test('does not confirm when the webhook is still pending', () async {
      mockRepo.statusResult = BookingStatus.pending;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: Duration.zero,
        confirmationAttempts: 3,
      );

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.isAwaitingConfirmation, isTrue);
      expect(notifier.state.paymentId, 'pay_test');
    });

    test('does not confirm when the backend rejects the booking', () async {
      mockRepo.statusResult = BookingStatus.cancelled;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: Duration.zero,
        confirmationAttempts: 2,
      );

      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.isAwaitingConfirmation, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('status refresh confirms without opening another checkout', () async {
      mockRepo.statusResult = BookingStatus.pending;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: Duration.zero,
        confirmationAttempts: 1,
      );

      await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );
      final checkoutCallsBeforeRefresh = fakeCheckout.checkoutCalls;

      mockRepo.statusResult = BookingStatus.confirmed;
      final refreshed = await notifier.refreshPaymentStatus(
        bookingId: testBooking.id,
      );

      expect(refreshed, isTrue);
      expect(notifier.state.isSuccess, isTrue);
      expect(fakeCheckout.checkoutCalls, checkoutCallsBeforeRefresh);
      expect(mockRepo.lastOrderBookingId, testBooking.id);
    });

    test('pending status refresh remains awaiting without creating an order',
        () async {
      mockRepo.statusResult = BookingStatus.pending;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: Duration.zero,
        confirmationAttempts: 1,
      );

      await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );
      final checkoutCallsBeforeRefresh = fakeCheckout.checkoutCalls;

      final refreshed = await notifier.refreshPaymentStatus(
        bookingId: testBooking.id,
      );

      expect(refreshed, isFalse);
      expect(notifier.state.isAwaitingConfirmation, isTrue);
      expect(notifier.state.isSuccess, isFalse);
      expect(fakeCheckout.checkoutCalls, checkoutCallsBeforeRefresh);
    });

    test('does not start a second checkout while awaiting confirmation',
        () async {
      mockRepo.statusResult = BookingStatus.pending;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: Duration.zero,
        confirmationAttempts: 1,
      );

      await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );
      final checkoutCallsBeforeRetry = fakeCheckout.checkoutCalls;

      final retried = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(retried, isFalse);
      expect(fakeCheckout.checkoutCalls, checkoutCallsBeforeRetry);
      expect(notifier.state.isAwaitingConfirmation, isTrue);
    });

    test('rejects a duplicate in-flight payment attempt', () async {
      fakeCheckout.result = CheckoutResult.paid;
      mockRepo.statusResult = BookingStatus.pending;
      notifier = PaymentNotifier(
        paymentRepository: mockRepo,
        checkoutService: fakeCheckout,
        confirmationPollDelay: const Duration(milliseconds: 30),
        confirmationAttempts: 4,
      );

      final first = notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );
      final second = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );

      expect(second, isFalse);
      await first;
    });

    test('surfaces a duplicate order from the server', () async {
      mockRepo.duplicateOrder = true;
      final success = await notifier.processPayment(
        booking: testBooking,
        selectedMethod: PaymentMethodType.razorpayCheckout,
        payableAmount: 4720.0,
        remainingDueAtVenue: 0.0,
      );
      expect(success, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.errorMessage, contains('already exists'));
      expect(fakeCheckout.lastOrderId, isNull);
    });
  });

  group('NativeRazorpayCheckoutService', () {
    test('does not report success when native checkout is unavailable',
        () async {
      final service = NativeRazorpayCheckoutService();

      final result = await service.openCheckout(
        orderId: 'order_test_unit',
        amount: 1500.0,
        currency: 'INR',
        keyId: 'rzp_test_unit',
        venueName: 'Studio Space',
        bookingRef: 'BMS-UNIT-1',
      );

      expect(result, CheckoutResult.failed);
      expect(service.lastResponse, isNotNull);
      expect(service.lastResponse?.result, CheckoutResult.failed);
      expect(service.lastResponse?.errorCode, 'native_checkout_unavailable');
    });
  });
}
