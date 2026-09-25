// release/v1.0 version of this test double (the main-lineage version
// lives next to it). Extra interface members fall through noSuchMethod.
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/domain/payment_repository.dart';

/// In-memory payment repository for tests and widget tests.
class MockPaymentRepository implements PaymentRepository {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  MockPaymentRepository();

  bool failCreateOrder = false;
  bool failRefund = false;
  bool failStatus = false;

  /// Set to make [selectPayAtVenue] throw. Defaults to a generic
  /// [Exception]; set [payAtVenueError] for a specific typed exception
  /// (e.g. to simulate a server-side rejection like
  /// `payment_in_progress`).
  bool failSelectPayAtVenue = false;
  Object? payAtVenueError;

  BookingStatus statusResult = BookingStatus.confirmed;
  int statusCalls = 0;

  /// Result returned by a successful [selectPayAtVenue] call. Pay-at-venue
  /// never auto-confirms — it always lands in the owner-approval queue,
  /// same as a captured online payment.
  BookingStatus payAtVenueResult = BookingStatus.pendingOwnerApproval;

  Refund? createdRefund;
  String? lastOrderBookingId;
  String? lastPayAtVenueBookingId;
  String? lastRefundBookingId;
  double? lastRefundAmount;

  static const List<Payment> defaultPayments = [
    Payment(
      id: 'p1',
      bookingId: 'b1',
      providerOrderId: 'order_1',
      providerPaymentId: 'pay_1',
      amount: 41300,
      currency: 'INR',
      status: PaymentStatus.captured,
    ),
  ];

  static PaymentOrder sampleOrder({String orderId = 'order_1'}) =>
      PaymentOrder(orderId: orderId, amount: 41300, currency: 'INR');

  static Refund sampleRefund() => const Refund(
    id: 'r1',
    paymentId: 'p1',
    bookingId: 'b1',
    amount: 41300,
    status: 'processed',
    reason: '',
    providerRefundId: 'rfnd_1',
  );

  @override
  Future<PaymentOrder> createOrder({required String bookingId}) async {
    if (failCreateOrder) throw Exception('order creation failed');
    lastOrderBookingId = bookingId;
    return sampleOrder();
  }

  @override
  Future<BookingStatus> selectPayAtVenue({required String bookingId}) async {
    if (failSelectPayAtVenue) {
      throw payAtVenueError ?? Exception('pay at venue failed');
    }
    lastPayAtVenueBookingId = bookingId;
    return payAtVenueResult;
  }

  @override
  Future<BookingStatus> bookingStatus(String bookingId) async {
    statusCalls++;
    if (failStatus) throw Exception('status failed');
    return statusResult;
  }

  @override
  Future<Refund> requestRefund({
    required String bookingId,
    required double amount,
    String reason = '',
  }) async {
    if (failRefund) throw Exception('refund failed');
    lastRefundBookingId = bookingId;
    lastRefundAmount = amount;
    createdRefund = sampleRefund();
    return createdRefund!;
  }

  @override
  Future<List<Payment>> myPayments() async {
    return List.of(defaultPayments);
  }
}

/// A checkout service that records the opened order and returns a fixed
/// outcome, so payment widget tests never touch the native SDK.
class FakeCheckoutService implements CheckoutService {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  FakeCheckoutService([this.result = CheckoutResult.paid]);

  CheckoutResult result;
  String? lastOrderId;
  double? lastAmount;
  String? lastCurrency;
  String? lastKeyId;

  @override
  CheckoutSuccessDetails? get lastSuccessDetails => null;

  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
    String? venueName,
    String? bookingRef,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    Map<String, dynamic>? notes,
  }) async {
    lastOrderId = orderId;
    lastAmount = amount;
    lastCurrency = currency;
    lastKeyId = keyId;
    return result;
  }
}
