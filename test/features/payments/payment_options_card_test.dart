import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/presentation/widgets/payment_options_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment order preserves server wallet and advance metadata', () {
    final order = PaymentOrder.fromResponse({
      'order_id': 'order_1',
      'amount': 750,
      'currency': 'INR',
      'payment_plan': 'advance',
      'full_amount': 3000,
      'advance_amount': 1000,
      'balance_due': 2000,
      'wallet_credit_amount': 250,
      'wallet_only': false,
    });

    expect(order.amount, 750);
    expect(order.paymentPlan, 'advance');
    expect(order.fullAmount, 3000);
    expect(order.advanceAmount, 1000);
    expect(order.balanceDue, 2000);
    expect(order.walletCreditAmount, 250);
    expect(order.walletOnly, isFalse);
  });

  testWidgets('payment options use RadioGroup and expose enabled methods', (
    tester,
  ) async {
    PaymentMethodType selected = PaymentMethodType.razorpayCheckout;
    String plan = 'full';
    double wallet = 0;
    final quote = const CheckoutQuote(
      bookingId: 'b1',
      currency: 'INR',
      paymentPlan: 'full',
      fullAmount: 3000,
      advanceAmount: 1000,
      balanceDue: 2000,
      advanceEnabled: true,
      minimumAdvanceAmount: 200,
      walletEnabled: true,
      walletBalance: 250,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => PaymentOptionsCard(
            selectedMethod: selected,
            paymentPlan: plan,
            rules: const VenuePaymentRules(allowPayAtVenue: true),
            quote: quote,
            onMethodChanged: (value) => setState(() => selected = value),
            onPlanChanged: (value) => setState(() => plan = value),
            walletCreditAmount: wallet,
            onWalletCreditChanged: (value) => setState(() => wallet = value),
          ),
        ),
      ),
    );

    expect(find.text('Pay at venue'), findsOneWidget);
    await tester.tap(find.text('Pay at venue'));
    await tester.pump();
    expect(selected, PaymentMethodType.payAtVenue);

    await tester.tap(find.text('Pay advance'));
    await tester.pump();
    expect(plan, 'advance');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(wallet, 250);
  });
}
