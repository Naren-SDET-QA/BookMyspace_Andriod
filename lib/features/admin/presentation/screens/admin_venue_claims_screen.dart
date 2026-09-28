import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venue_discovery/presentation/venue_discovery_providers.dart';

/// Administrator review for owner claims on discovered places.
///
/// Approval only attaches the place to the owner's organization as an
/// inactive, unverified draft. Publishing remains a separate moderation step.
class AdminVenueClaimsScreen extends ConsumerStatefulWidget {
  const AdminVenueClaimsScreen({super.key});

  @override
  ConsumerState<AdminVenueClaimsScreen> createState() =>
      _AdminVenueClaimsScreenState();
}

class _AdminVenueClaimsScreenState
    extends ConsumerState<AdminVenueClaimsScreen> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(pendingVenueClaimsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Owner venue claims')),
      body: claims.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(pendingVenueClaimsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No claims waiting',
              message: 'Owner claims will appear here after submission.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingVenueClaimsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ClaimCard(
                row: items[index],
                busy: _busy.contains(items[index]['id'] as String? ?? ''),
                onReview: _review,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _review(String claimId, {required bool approve}) async {
    setState(() => _busy.add(claimId));
    try {
      await ref
          .read(discoveryRepositoryProvider)
          .reviewClaim(claimId, approve: approve);
      ref.invalidate(pendingVenueClaimsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Claim approved.' : 'Claim rejected.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not review claim: $error')));
    } finally {
      if (mounted) setState(() => _busy.remove(claimId));
    }
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.row,
    required this.busy,
    required this.onReview,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final void Function(String claimId, {required bool approve}) onReview;

  @override
  Widget build(BuildContext context) {
    final staging = row['venue_discovery_staging'] is Map
        ? Map<String, dynamic>.from(row['venue_discovery_staging'] as Map)
        : const <String, dynamic>{};
    final name = staging['name'] as String? ?? 'Unnamed place';
    final location = [
      staging['city'],
      staging['state'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');
    final proof = row['proof_note'] as String?;
    final claimId = row['id'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            if (location.isNotEmpty) Text(location),
            Text(
              'Owner: ${row['owner_user_id'] ?? 'unknown'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (proof != null && proof.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Proof note: $proof'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy || claimId.isEmpty
                      ? null
                      : () => onReview(claimId, approve: true),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: busy || claimId.isEmpty
                      ? null
                      : () => onReview(claimId, approve: false),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
