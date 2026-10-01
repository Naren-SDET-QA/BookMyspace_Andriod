import 'package:flutter/material.dart';

import '../../domain/payment.dart';

/// Payment choices are a UI projection of server rules. The checkout RPC
/// repeats every rule check; this widget never decides whether a payment is
/// allowed on its own.
class PaymentOptionsCard extends StatelessWidget {
  const PaymentOptionsCard({
    super.key,
    required this.selectedMethod,
    required this.paymentPlan,
    required this.rules,
    required this.quote,
    required this.onMethodChanged,
    required this.onPlanChanged,
    required this.walletCreditAmount,
    required this.onWalletCreditChanged,
  });

  final PaymentMethodType selectedMethod;
  final String paymentPlan;
  final VenuePaymentRules rules;
  final CheckoutQuote? quote;
  final ValueChanged<PaymentMethodType> onMethodChanged;
  final ValueChanged<String> onPlanChanged;
  final double walletCreditAmount;
  final ValueChanged<double> onWalletCreditChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuote = quote != null;
    final advanceAvailable = quote?.advanceEnabled ?? false;
    final walletAvailable = quote?.walletEnabled ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment options',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<PaymentMethodType>(
              groupValue: selectedMethod,
              onChanged: (method) {
                if (method != null && rules.allows(method)) {
                  onMethodChanged(method);
                }
              },
              child: Column(
                children: [
                  _methodTile(
                    context,
                    PaymentMethodType.razorpayCheckout,
                    enabled: rules.allows(PaymentMethodType.razorpayCheckout),
                  ),
                  _methodTile(
                    context,
                    PaymentMethodType.payAtVenue,
                    enabled: rules.allows(PaymentMethodType.payAtVenue),
                  ),
                ],
              ),
            ),
            if (!hasQuote) ...[
              const SizedBox(height: 6),
              Text(
                'Loading the latest server pricing…',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (advanceAvailable) ...[
              const Divider(height: 20),
              Text(
                'How much would you like to pay now?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              RadioGroup<String>(
                groupValue: paymentPlan,
                onChanged: (plan) {
                  if (plan != null) onPlanChanged(plan);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'full',
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pay in full'),
                      subtitle: Text(
                        quote == null
                            ? ''
                            : '₹${quote!.fullAmount.toStringAsFixed(2)}',
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'advance',
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pay advance'),
                      subtitle: Text(
                        quote == null
                            ? ''
                            : '₹${quote!.advanceAmount.toStringAsFixed(2)} now · '
                                  '₹${quote!.balanceDue.toStringAsFixed(2)} later',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (walletAvailable && quote!.walletBalance > 0) ...[
              const Divider(height: 20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: walletCreditAmount > 0,
                title: Text(
                  'Use wallet credit (up to ₹${quote!.walletBalance.toStringAsFixed(2)})',
                ),
                subtitle: const Text(
                  'The server applies the available balance at checkout.',
                ),
                onChanged: (enabled) => onWalletCreditChanged(
                  enabled == true ? quote!.walletBalance : 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _methodTile(
    BuildContext context,
    PaymentMethodType method, {
    required bool enabled,
  }) {
    return RadioListTile<PaymentMethodType>(
      value: method,
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      title: Text(method.title),
      subtitle: Text(method.subtitle),
    );
  }
}
