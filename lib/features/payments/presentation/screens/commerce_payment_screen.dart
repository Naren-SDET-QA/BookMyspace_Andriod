import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// Safe fallback for commerce checkout, which is not part of the PROD payment
/// contract. Standard venue bookings continue through the existing booking
/// payment screen and its booking_id API.
class CommercePaymentScreen extends StatelessWidget {
  const CommercePaymentScreen({
    super.key,
    required this.referenceId,
    required this.amount,
    required this.currency,
  });

  final String referenceId;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Commerce checkout unavailable')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 40),
          const SizedBox(height: 16),
          const Text(
            'This checkout is not enabled in the production release yet. '
            'No payment has been started. Standard venue bookings continue '
            'to use the existing booking payment flow.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Return to BookMySpace'),
          ),
        ],
      ),
    ),
  );
}
