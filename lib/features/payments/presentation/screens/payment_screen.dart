import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../qr_checkin/presentation/widgets/pass_actions.dart';
import '../../../qr_checkin/presentation/widgets/qr_code_pass_widget.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/payment.dart';
import '../payment_providers.dart';
import '../widgets/payment_options_card.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/responsive_layout.dart';

/// Payment checkout screen matching the Android native Razorpay payment experience.
///
/// The payment UI reflects the deployed Razorpay order + webhook flow. The
/// payable amount is always the booking total returned by the server order.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethodType _selectedMethod = PaymentMethodType.razorpayCheckout;
  String _paymentPlan = 'full';
  double _walletCreditAmount = 0;
  CheckoutQuote? _quote;
  VenuePaymentRules _paymentRules = const VenuePaymentRules();
  bool _loadingPaymentConfig = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentConfig();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final quoteFuture = repo.checkoutQuote(
        bookingId: widget.booking.id,
        paymentPlan: _paymentPlan,
      );
      final rulesFuture = repo.paymentRules(venueId: widget.booking.venueId);
      final quote = await quoteFuture;
      final rules = await rulesFuture;
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _paymentRules = rules;
        _loadingPaymentConfig = false;
        if (!_paymentRules.allows(_selectedMethod)) {
          _selectedMethod = PaymentMethodType.values.firstWhere(
            _paymentRules.allows,
            orElse: () => PaymentMethodType.razorpayCheckout,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPaymentConfig = false);
    }
  }

  Future<void> _changePaymentPlan(String plan) async {
    if (_paymentPlan == plan) return;
    setState(() {
      _paymentPlan = plan;
      _quote = null;
      _walletCreditAmount = 0;
      _loadingPaymentConfig = true;
    });
    await _loadPaymentConfig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booking = widget.booking;
    final paymentState = ref.watch(paymentNotifierProvider);

    // Pricing calculation
    final fullTotal = booking.totalAmount > 0
        ? booking.totalAmount
        : (booking.amount + booking.taxAmount);
    final quoteAmount = _quote?.advanceAmount ?? fullTotal;
    final payableAmount = (quoteAmount - _walletCreditAmount)
        .clamp(0.0, quoteAmount)
        .toDouble();
    // Razorpay Checkout collects the full booking total; remaining venue due
    // is whatever of that total is not included in the payable amount.
    final remainingDue = (fullTotal - payableAmount)
        .clamp(0.0, fullTotal)
        .toDouble();

    // Deep links and stale navigation extras must not expose a payment
    // surface for an approval request. The Edge Function is the authoritative
    // boundary as well; this is only the matching UI guard.
    if (!booking.canPay) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppNavigationControls(),
          leadingWidth: AppNavigationControls.kLeadingWidth,
          title: const Text('Payment unavailable'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  booking.status == BookingStatus.awaitingOwnerApproval
                      ? 'Payment becomes available after the venue owner accepts this request.'
                      : 'This booking is not ready for payment.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.bookings),
                  child: const Text('Back to bookings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (paymentState.isSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(
          AppRoutes.bookingSuccess.replaceAll(':id', widget.booking.id),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationControls(
          backKey: const Key('checkout_back_btn'),
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secure Checkout 🔒',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '256-Bit SSL Encrypted',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ResponsiveLayoutBuilder(
        builder: (context, responsive) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error banner if any
              if (paymentState.isAwaitingConfirmation) ...[
                _PendingConfirmationCard(
                  message:
                      paymentState.note ??
                      'Payment was submitted. Waiting for confirmation.',
                  onRefresh: _refreshPaymentStatus,
                ),
                const SizedBox(height: 16),
              ] else if (paymentState.errorMessage != null) ...[
                _ErrorRecoveryCard(
                  message: paymentState.errorMessage!,
                  onRetry: () => _executePayment(payableAmount, remainingDue),
                ),
                const SizedBox(height: 16),
              ],

              // Booking summary card
              _BookingSummaryCard(booking: booking),
              const SizedBox(height: 16),

              // Price breakdown card
              _PriceBreakdownCard(booking: booking, totalAmount: fullTotal),
              const SizedBox(height: 16),
              PaymentOptionsCard(
                selectedMethod: _selectedMethod,
                paymentPlan: _paymentPlan,
                rules: _paymentRules,
                quote: _quote,
                onMethodChanged: (method) =>
                    setState(() => _selectedMethod = method),
                onPlanChanged: _changePaymentPlan,
                walletCreditAmount: _walletCreditAmount,
                onWalletCreditChanged: (amount) =>
                    setState(() => _walletCreditAmount = amount),
              ),
              const SizedBox(height: 80), // bottom bar spacing
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomPayBar(
        payableAmount: payableAmount,
        isLoading: paymentState.isLoading,
        isAwaitingConfirmation:
            paymentState.isAwaitingConfirmation || _loadingPaymentConfig,
        onPayPressed: () => _executePayment(payableAmount, remainingDue),
      ),
    );
  }

  Future<void> _executePayment(double payable, double remainingDue) async {
    final notifier = ref.read(paymentNotifierProvider.notifier);
    final success = await notifier.processPayment(
      booking: widget.booking,
      selectedMethod: _selectedMethod,
      payableAmount: payable,
      remainingDueAtVenue: remainingDue,
      paymentPlan: _paymentPlan,
      walletCreditAmount: _walletCreditAmount,
    );

    if (success) {
      ref.invalidate(myBookingsProvider);
      if (mounted) {
        context.go(
          AppRoutes.bookingSuccess.replaceAll(':id', widget.booking.id),
        );
      }
    }
  }

  Future<void> _refreshPaymentStatus() async {
    final success = await ref
        .read(paymentNotifierProvider.notifier)
        .refreshPaymentStatus(bookingId: widget.booking.id);
    if (success && mounted) {
      ref.invalidate(myBookingsProvider);
      context.go(AppRoutes.bookingSuccess.replaceAll(':id', widget.booking.id));
    }
  }
}

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueTitle = booking.venueName.isNotEmpty
        ? booking.venueName
        : 'Space Reservation';

    return Card(
      elevation: 0,
      shape: RoundedCornerShape(12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    venueTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.bookingRef.isNotEmpty
                        ? booking.bookingRef
                        : 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat.yMMMd().format(booking.bookDate),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.displayStart} – ${booking.displayEnd}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.booking, required this.totalAmount});

  final Booking booking;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedCornerShape(12),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Summary',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _RowText(
              label: 'Base Space Rental',
              value: formatInr(booking.amount),
            ),
            const SizedBox(height: 6),
            _RowText(
              label: _storedTaxLabel(booking),
              value: formatInr(booking.taxAmount),
            ),
            const Divider(height: 18),
            _RowText(
              label: 'Total Full Amount',
              value: formatInr(totalAmount),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Names the tax line from the amount the server stored on the booking.
/// A flat "18%" label is only shown when that ratio is actually 18.
String _storedTaxLabel(Booking booking) {
  if (booking.amount <= 0 || booking.taxAmount <= 0) return 'GST & fees';
  final percent = booking.taxAmount / booking.amount * 100;
  final rounded = percent.roundToDouble();
  if ((percent - rounded).abs() > 0.05 || rounded <= 0 || rounded > 100) {
    return 'GST & fees';
  }
  return 'GST & fees (${rounded.toStringAsFixed(0)}%)';
}

class _RowText extends StatelessWidget {
  const _RowText({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({
    required this.payableAmount,
    required this.isLoading,
    required this.isAwaitingConfirmation,
    required this.onPayPressed,
  });

  final double payableAmount;
  final bool isLoading;
  final bool isAwaitingConfirmation;
  final VoidCallback onPayPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Payable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatInr(payableAmount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('pay_now_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 50),
                  shape: RoundedCornerShape(12),
                ),
                onPressed: isLoading || isAwaitingConfirmation
                    ? null
                    : onPayPressed,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock, size: 18),
                label: Text(
                  isLoading
                      ? 'Verifying Securely...'
                      : isAwaitingConfirmation
                      ? 'Awaiting Confirmation'
                      : 'Pay Securely',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingConfirmationCard extends StatelessWidget {
  const _PendingConfirmationCard({
    required this.message,
    required this.onRefresh,
  });

  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Waiting for confirmation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRefresh,
            child: const Text('Refresh status'),
          ),
        ],
      ),
    );
  }
}

class _ErrorRecoveryCard extends StatelessWidget {
  const _ErrorRecoveryCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Payment Issue Detected',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _PaymentSuccessView extends StatelessWidget {
  // ignore: unused_element
  const _PaymentSuccessView({
    required this.booking,
    required this.paymentId,
    required this.orderId,
    required this.selectedMethod,
  });

  final Booking booking;
  final String? paymentId;
  final String? orderId;
  final PaymentMethodType selectedMethod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF2E7D32),
              size: 58,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Booking Confirmed! 🎉',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your space booking is secured and reconciled with the venue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Digital Entry Check-In Token Card
          Card(
            elevation: 0,
            shape: RoundedCornerShape(16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DIGITAL ENTRY PASS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF4CAF50,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CONFIRMED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  QrCodePassWidget(
                    booking: booking,
                    size: 160,
                    showTokenLabel: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entry Token: ${booking.bookingRef}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Show this pass at venue desk for instant check-in',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PassActions(booking: booking),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Transaction details card
          Card(
            elevation: 0,
            shape: RoundedCornerShape(12),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (paymentId != null && paymentId!.isNotEmpty) ...[
                    _RowText(
                      label: 'Transaction ID',
                      value: paymentId!.length > 18
                          ? '${paymentId!.substring(0, 18)}...'
                          : paymentId!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (orderId != null && orderId!.isNotEmpty) ...[
                    _RowText(
                      label: 'Order ID',
                      value: orderId!.length > 18
                          ? '${orderId!.substring(0, 18)}...'
                          : orderId!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  _RowText(
                    label: 'Payment Method',
                    value: selectedMethod.title.split(' ').take(3).join(' '),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Actions
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('view_my_bookings_btn'),
              onPressed: () => context.go(AppRoutes.bookings),
              icon: const Icon(Icons.bookmark_added),
              label: const Text('View in My Bookings'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('return_home_btn'),
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.home),
              label: const Text('Return to Home'),
            ),
          ),
        ],
      ),
    );
  }
}

OutlinedBorder RoundedCornerShape(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
