import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../booking/domain/booking.dart';
import '../domain/checkout_service.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../infrastructure/checkout_service_factory.dart';
import '../infrastructure/supabase_payment_repository.dart';

/// Provider for the [PaymentRepository].
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return SupabasePaymentRepository(Supabase.instance.client);
});

/// Provider for the platform-aware [CheckoutService].
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return createCheckoutService();
});

/// Provider fetching payments for the current user.
final myPaymentsProvider =
    FutureProvider.autoDispose<List<Payment>>((ref) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.myPayments();
});

/// State representing the payment process on the PaymentScreen.
class PaymentState {
  const PaymentState({
    this.isLoading = false,
    this.isSuccess = false,
    this.isAwaitingConfirmation = false,
    this.errorMessage,
    this.paymentId,
    this.orderId,
    this.signature,
    this.note,
  });

  final bool isLoading;
  final bool isSuccess;
  final bool isAwaitingConfirmation;
  final String? errorMessage;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? note;

  PaymentState copyWith({
    bool? isLoading,
    bool? isSuccess,
    bool? isAwaitingConfirmation,
    String? errorMessage,
    String? paymentId,
    String? orderId,
    String? signature,
    String? note,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      isAwaitingConfirmation:
          isAwaitingConfirmation ?? this.isAwaitingConfirmation,
      errorMessage: errorMessage,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      signature: signature ?? this.signature,
      note: note ?? this.note,
    );
  }
}

/// Notifier handling server-order creation, checkout launch, and webhook
/// confirmation. Razorpay secrets and booking confirmation remain server-side.
class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier({
    required this.paymentRepository,
    required this.checkoutService,
    this.confirmationPollDelay = const Duration(seconds: 2),
    this.confirmationAttempts = 10,
  }) : super(const PaymentState());

  final PaymentRepository paymentRepository;
  final CheckoutService checkoutService;
  final Duration confirmationPollDelay;
  final int confirmationAttempts;

  Future<bool> processPayment({
    required Booking booking,
    required PaymentMethodType selectedMethod,
    required double payableAmount,
    required double remainingDueAtVenue,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    if (state.isLoading || state.isAwaitingConfirmation) return false;
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      isAwaitingConfirmation: false,
      errorMessage: null,
    );

    try {
      if (selectedMethod != PaymentMethodType.razorpayCheckout) {
        throw const BusinessException(
          'This payment option is not available yet. Use Razorpay Checkout.',
          code: 'payment_method_unavailable',
        );
      }

      // The Edge Function calculates the amount from the booking. The values
      // passed from the widget are display-only and are never trusted here.
      final order = await paymentRepository.createOrder(bookingId: booking.id);
      if (order.orderId.isEmpty || order.amount <= 0) {
        throw const ServerException(
          'Payment service returned an invalid order.',
          code: 'invalid_payment_order',
        );
      }

      // Public key may come from the order function; never a secret key.
      final result = await checkoutService.openCheckout(
        orderId: order.orderId,
        amount: order.amount,
        currency: order.currency,
        keyId: order.keyId ?? AppConfig.razorpayKeyId,
        venueName: booking.venueName,
        bookingRef: booking.bookingRef,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (result == CheckoutResult.cancelled) {
        state = state.copyWith(
          isLoading: false,
          isSuccess: false,
          isAwaitingConfirmation: false,
          errorMessage:
              'Payment was cancelled. Your slot hold is still reserved.',
        );
        return false;
      }

      if (result == CheckoutResult.failed) {
        final lastResp = checkoutService.lastResponse;
        state = state.copyWith(
          isLoading: false,
          isSuccess: false,
          isAwaitingConfirmation: false,
          errorMessage:
              lastResp?.errorMessage ?? 'Payment failed. Please try again.',
        );
        return false;
      }

      final lastResp = checkoutService.lastResponse;
      final paymentId = lastResp?.paymentId;
      if (paymentId == null || paymentId.isEmpty) {
        throw const ServerException(
          'The payment provider returned no payment reference.',
          code: 'missing_payment_reference',
        );
      }

      // Confirmation is performed by the deployed Razorpay webhook. The
      // client only observes the booking row; it never marks payment captured
      // from a client callback or signature.
      final confirmed = await _waitForBookingConfirmation(booking.id);
      if (!confirmed) {
        final latest = await paymentRepository.bookingStatus(booking.id);
        if (latest == BookingStatus.cancelled ||
            latest == BookingStatus.refunded) {
          state = state.copyWith(
            isLoading: false,
            isSuccess: false,
            isAwaitingConfirmation: false,
            paymentId: paymentId,
            orderId: order.orderId,
            errorMessage:
                'The booking was not confirmed. Please contact support if you were charged.',
          );
          return false;
        }
        state = state.copyWith(
          isLoading: false,
          isSuccess: false,
          isAwaitingConfirmation: true,
          paymentId: paymentId,
          orderId: order.orderId,
          note:
              'Payment was submitted. Waiting for BookMySpace to confirm the booking.',
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        isAwaitingConfirmation: false,
        paymentId: paymentId,
        orderId: order.orderId,
        signature: lastResp?.signature,
        note: 'Payment confirmed by BookMySpace.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: _messageFor(e),
      );
      return false;
    }
  }

  Future<bool> _waitForBookingConfirmation(String bookingId) async {
    for (var attempt = 0; attempt < confirmationAttempts; attempt++) {
      final status = await paymentRepository.bookingStatus(bookingId);
      if (status == BookingStatus.confirmed) return true;
      if (status == BookingStatus.cancelled ||
          status == BookingStatus.refunded) {
        return false;
      }
      if (attempt < confirmationAttempts - 1 &&
          confirmationPollDelay > Duration.zero) {
        await Future<void>.delayed(confirmationPollDelay);
      }
    }
    return false;
  }

  /// Refreshes the server-owned payment/booking state without starting a new
  /// checkout. This is the only safe action after the initial confirmation
  /// polling window expires because the original provider payment may still
  /// be settling asynchronously.
  Future<bool> refreshPaymentStatus({required String bookingId}) async {
    if (state.isLoading) return false;

    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      isAwaitingConfirmation: true,
      errorMessage: null,
      note: 'Checking the latest booking status…',
    );

    try {
      final latest = await paymentRepository.bookingStatus(bookingId);
      if (latest == BookingStatus.confirmed ||
          latest == BookingStatus.completed) {
        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          isAwaitingConfirmation: false,
          errorMessage: null,
          note: 'Payment confirmed by BookMySpace.',
        );
        return true;
      }

      if (latest == BookingStatus.cancelled ||
          latest == BookingStatus.refunded ||
          latest == BookingStatus.noShow) {
        state = state.copyWith(
          isLoading: false,
          isSuccess: false,
          isAwaitingConfirmation: false,
          errorMessage:
              'The booking was not confirmed. Please contact support if you were charged.',
          note: null,
        );
        return false;
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        isAwaitingConfirmation: true,
        errorMessage: null,
        note:
            'Payment was submitted. Waiting for BookMySpace to confirm the booking.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        isAwaitingConfirmation: true,
        errorMessage: _messageFor(e),
        note: 'Unable to refresh the booking status. Please try again.',
      );
      return false;
    }
  }

  String _messageFor(Object error) {
    if (error is AppException) return error.message;
    return error.toString();
  }

  void reset() {
    state = const PaymentState();
  }
}

final paymentNotifierProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  final checkout = ref.watch(checkoutServiceProvider);
  return PaymentNotifier(paymentRepository: repo, checkoutService: checkout);
});
