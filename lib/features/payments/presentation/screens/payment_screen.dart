import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../qr_checkin/presentation/widgets/qr_code_pass_widget.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/payment.dart';
import '../payment_providers.dart';

/// Payment checkout screen matching the Android native Razorpay payment experience.
///
/// Features:
/// - Order creation and authoritative price breakdown (Base + GST Tax)
/// - Wallet balance deduction toggle
/// - Configurable payment methods (Razorpay standard, UPI/GPay, Cards, Netbanking, Pay at Venue, Split Advance)
/// - Native Razorpay SDK invocation for iOS & Android
/// - Web compatibility for browser clients
/// - Real-time signature verification and booking status update
/// - Self-healing autonomous error recovery preventing stuck slot holds
/// - Rich post-payment confirmation screen with entry token and check-in QR details
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  PaymentMethodType _selectedMethod = PaymentMethodType.razorpayCheckout;
  bool _useWallet = false;
  final double _availableWalletBalance = 500.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final booking = widget.booking;
    final paymentState = ref.watch(paymentNotifierProvider);

    // Pricing calculation
    final fullTotal = booking.totalAmount > 0
        ? booking.totalAmount
        : (booking.amount + booking.taxAmount);
    final walletDeduct = _useWallet
        ? _availableWalletBalance.clamp(0.0, fullTotal)
        : 0.0;
    final netAfterWallet = (fullTotal - walletDeduct).clamp(0.0, double.infinity);

    double payableAmount;
    double remainingDueAtVenue;

    if (_selectedMethod == PaymentMethodType.payAtVenue) {
      payableAmount = 0.0;
      remainingDueAtVenue = fullTotal;
    } else if (_selectedMethod == PaymentMethodType.splitAdvanceToken) {
      final advance = (fullTotal * 0.20).clamp(100.0, fullTotal);
      final walletPart = _useWallet
          ? _availableWalletBalance.clamp(0.0, advance)
          : 0.0;
      payableAmount = (advance - walletPart).clamp(0.0, double.infinity);
      remainingDueAtVenue = (fullTotal - payableAmount - walletPart).clamp(0.0, double.infinity);
    } else {
      payableAmount = netAfterWallet;
      remainingDueAtVenue = 0.0;
    }

    if (paymentState.isSuccess) {
      return Scaffold(
        body: SafeArea(
          child: _PaymentSuccessView(
            booking: booking,
            paymentId: paymentState.paymentId ?? 'pay_rzp_confirmed',
            orderId: paymentState.orderId ?? 'order_confirmed',
            note: paymentState.note,
            selectedMethod: _selectedMethod,
            amountPaid: payableAmount,
            remainingDue: remainingDueAtVenue,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('checkout_back_btn'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Secure Checkout 🔒',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Self-Healing Shield',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '256-Bit SSL Encrypted & Auto-Reconciled',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error banner if any
            if (paymentState.errorMessage != null) ...[
              _ErrorRecoveryCard(
                message: paymentState.errorMessage!,
                onRetry: () => _executePayment(payableAmount, remainingDueAtVenue),
                onSelfHeal: () => _executeSelfHealing(payableAmount, remainingDueAtVenue),
              ),
              const SizedBox(height: 16),
            ],

            // Booking summary card
            _BookingSummaryCard(booking: booking),
            const SizedBox(height: 16),

            // Price breakdown card
            _PriceBreakdownCard(
              booking: booking,
              walletDeduction: walletDeduct,
              totalAmount: fullTotal,
              netAmount: netAfterWallet,
            ),
            const SizedBox(height: 16),

            // Wallet balance deduction toggle
            _WalletCard(
              availableBalance: _availableWalletBalance,
              useWallet: _useWallet,
              onChanged: (val) => setState(() => _useWallet = val),
            ),
            const SizedBox(height: 20),

            // Payment Methods Section
            Text(
              'Select Payment Option',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...PaymentMethodType.values.map(
              (method) => _PaymentMethodTile(
                method: method,
                isSelected: _selectedMethod == method,
                onSelected: () => setState(() => _selectedMethod = method),
              ),
            ),
            const SizedBox(height: 80), // bottom bar spacing
          ],
        ),
      ),
      bottomNavigationBar: _BottomPayBar(
        selectedMethod: _selectedMethod,
        payableAmount: payableAmount,
        remainingDue: remainingDueAtVenue,
        isLoading: paymentState.isLoading,
        onPayPressed: () => _executePayment(payableAmount, remainingDueAtVenue),
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
    );

    if (success) {
      ref.invalidate(myBookingsProvider);
    }
  }

  Future<void> _executeSelfHealing(double payable, double remainingDue) async {
    final notifier = ref.read(paymentNotifierProvider.notifier);
    await notifier.processPayment(
      booking: widget.booking,
      selectedMethod: PaymentMethodType.payAtVenue,
      payableAmount: 0.0,
      remainingDueAtVenue: widget.booking.totalAmount,
    );
    ref.invalidate(myBookingsProvider);
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
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: theme.colorScheme.primary),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.bookingRef.isNotEmpty ? booking.bookingRef : 'PENDING',
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
                Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  DateFormat.yMMMd().format(booking.bookDate),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${booking.displayStart} – ${booking.displayEnd}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
  const _PriceBreakdownCard({
    required this.booking,
    required this.walletDeduction,
    required this.totalAmount,
    required this.netAmount,
  });

  final Booking booking;
  final double walletDeduction;
  final double totalAmount;
  final double netAmount;

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
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _RowText(
              label: 'Base Space Rental',
              value: formatInr(booking.amount),
            ),
            const SizedBox(height: 6),
            _RowText(
              label: 'GST & Platform Fee (18%)',
              value: formatInr(booking.taxAmount),
            ),
            if (walletDeduction > 0) ...[
              const SizedBox(height: 6),
              _RowText(
                label: 'Wallet Credits Applied',
                value: '- ${formatInr(walletDeduction)}',
                textColor: const Color(0xFF2E7D32),
              ),
            ],
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

class _RowText extends StatelessWidget {
  const _RowText({
    required this.label,
    required this.value,
    this.isBold = false,
    this.textColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? textColor;

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
            color: textColor ?? (isBold ? theme.colorScheme.primary : null),
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.availableBalance,
    required this.useWallet,
    required this.onChanged,
  });

  final double availableBalance;
  final bool useWallet;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedCornerShape(12),
      color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: theme.colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BookMySpace Wallet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Available Credits: ${formatInr(availableBalance)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('use_wallet_toggle'),
              value: useWallet,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.isSelected,
    required this.onSelected,
  });

  final PaymentMethodType method;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.35)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withOpacity(0.6),
          width: isSelected ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onSelected,
        shape: RoundedCornerShape(12),
        leading: Radio<PaymentMethodType>(
          value: method,
          groupValue: isSelected ? method : null,
          onChanged: (_) => onSelected(),
        ),
        title: Text(
          method.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          method.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({
    required this.selectedMethod,
    required this.payableAmount,
    required this.remainingDue,
    required this.isLoading,
    required this.onPayPressed,
  });

  final PaymentMethodType selectedMethod;
  final double payableAmount;
  final double remainingDue;
  final bool isLoading;
  final VoidCallback onPayPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    if (selectedMethod == PaymentMethodType.payAtVenue) {
      label = 'Pay on Arrival';
    } else if (selectedMethod == PaymentMethodType.splitAdvanceToken) {
      label = 'Pay Advance Token';
    } else {
      label = 'Total Payable';
    }

    return Surface(
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
                      label,
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
                    if (remainingDue > 0)
                      Text(
                        '${formatInr(remainingDue)} due on arrival',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF9800),
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
                onPressed: isLoading ? null : onPayPressed,
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
                      : (selectedMethod == PaymentMethodType.payAtVenue
                          ? 'Confirm Reservation'
                          : 'Pay Securely'),
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

class _ErrorRecoveryCard extends StatelessWidget {
  const _ErrorRecoveryCard({
    required this.message,
    required this.onRetry,
    required this.onSelfHeal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSelfHeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
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
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onSelfHeal,
                child: const Text('Self-Healing Recovery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView({
    required this.booking,
    required this.paymentId,
    required this.orderId,
    this.note,
    required this.selectedMethod,
    required this.amountPaid,
    required this.remainingDue,
  });

  final Booking booking;
  final String paymentId;
  final String orderId;
  final String? note;
  final PaymentMethodType selectedMethod;
  final double amountPaid;
  final double remainingDue;

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
              color: const Color(0xFF4CAF50).withOpacity(0.12),
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
            note ?? 'Your space booking is secured and reconciled with the venue.',
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.15),
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
                  _RowText(
                    label: 'Transaction ID',
                    value: paymentId.length > 18 ? '${paymentId.substring(0, 18)}...' : paymentId,
                  ),
                  const SizedBox(height: 6),
                  _RowText(
                    label: 'Order ID',
                    value: orderId.length > 18 ? '${orderId.substring(0, 18)}...' : orderId,
                  ),
                  const SizedBox(height: 6),
                  _RowText(
                    label: 'Payment Method',
                    value: selectedMethod.title.split(' ').take(3).join(' '),
                  ),
                  if (remainingDue > 0) ...[
                    const SizedBox(height: 6),
                    _RowText(
                      label: 'Remaining Due on Arrival',
                      value: formatInr(remainingDue),
                      textColor: const Color(0xFFFF9800),
                    ),
                  ],
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

ShapeBorder RoundedCornerShape(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

