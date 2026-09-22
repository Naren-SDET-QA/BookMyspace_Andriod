import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// PROD has an imported-venue discovery review flow, but no owner-claim
/// contract. Keep those workflows clearly distinct until claims are deployed.
class AdminVenueClaimsScreen extends StatelessWidget {
  const AdminVenueClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Venue claims unavailable')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.info_outline, size: 40),
        const SizedBox(height: 16),
        Text(
          'Owner venue claims are not enabled in this production release. '
          'The available review queue is for imported venue listings; '
          'approval there creates an inactive, unverified draft and does not '
          'verify ownership.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.adminVenueDiscoveryReview),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Open imported-venue review'),
        ),
      ],
    ),
  );
}
