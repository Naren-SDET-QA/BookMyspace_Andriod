import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/review.dart';
import '../review_providers.dart';

/// Venue-details reviews block: list, empty, error/retry, and add-review.
class VenueReviewsSection extends ConsumerWidget {
  const VenueReviewsSection({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviews = ref.watch(venueReviewsProvider(venueId));
    final myReview = ref.watch(myReviewProvider(venueId));
    final signedIn = ref.watch(currentUserProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reviews',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (signedIn && myReview.valueOrNull == null)
              TextButton.icon(
                onPressed: () => _showReviewSheet(context, ref),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Write a review'),
              )
            else if (!signedIn)
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.login),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign in to review'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ReviewError(
            message: error.toString(),
            onRetry: () => ref.invalidate(venueReviewsProvider(venueId)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No reviews yet. Be the first to review this venue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final review in items) _ReviewTile(review: review),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showReviewSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WriteReviewSheet(venueId: venueId),
    );
  }
}

class _ReviewError extends StatelessWidget {
  const _ReviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try Again')),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (review.userName != null && review.userName!.trim().isNotEmpty)
        ? review.userName!.trim()
        : 'BookMySpace guest';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        borderRadius: 16,
        isInteractive: false,
        enableEntrance: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.brand.withValues(alpha: 0.16),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.brandDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (review.isVerified)
                  const Text(
                    'Verified',
                    style: TextStyle(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                if (review.createdAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (review.body != null && review.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                review.body!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (review.ownerReply != null &&
                review.ownerReply!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Owner reply: ${review.ownerReply!.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.venueId});

  final String venueId;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewControllerProvider).submit(
            venueId: widget.venueId,
            rating: _rating,
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
            body: _bodyController.text.trim().isEmpty
                ? null
                : _bodyController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write a review',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: _busy ? null : () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppTheme.accent,
                    size: 32,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _titleController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            enabled: !_busy,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your review',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Please wait...' : 'Submit review'),
          ),
        ],
      ),
    );
  }
}
