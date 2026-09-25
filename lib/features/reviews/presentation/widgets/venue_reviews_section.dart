import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/review.dart';
import '../review_providers.dart';

/// Venue-details reviews block: rating breakdown, star filters, list,
/// empty, error/retry, and add-review.
class VenueReviewsSection extends ConsumerStatefulWidget {
  const VenueReviewsSection({
    super.key,
    required this.venueId,
    this.avgRating,
    this.ratingCount,
  });

  final String venueId;

  /// Venue-row aggregate (real data from the listing). When null the
  /// breakdown computes the average from the fetched reviews instead.
  final double? avgRating;
  final int? ratingCount;

  @override
  ConsumerState<VenueReviewsSection> createState() =>
      _VenueReviewsSectionState();
}

class _VenueReviewsSectionState extends ConsumerState<VenueReviewsSection> {
  int? _starFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviews = ref.watch(venueReviewsProvider(widget.venueId));
    final myReview = ref.watch(myReviewProvider(widget.venueId));
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
              Flexible(
                child: TextButton.icon(
                  onPressed: () => _showReviewSheet(context),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text(
                    'Write a review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else if (!signedIn)
              Flexible(
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'Sign in to review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            onRetry: () => ref.invalidate(venueReviewsProvider(widget.venueId)),
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
            final filtered = _starFilter == null
                ? items
                : items
                    .where((review) => review.rating == _starFilter)
                    .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewsSummaryCard(
                  reviews: items,
                  avgRating: widget.avgRating,
                  ratingCount: widget.ratingCount,
                  selectedStar: _starFilter,
                  onSelectStar: (star) => setState(() => _starFilter = star),
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No ${_starFilter}★ reviews found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  for (final review in filtered) _ReviewTile(review: review),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showReviewSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WriteReviewSheet(venueId: widget.venueId),
    );
  }
}

/// Score box + 5★ distribution bars + star filter chips, mirroring the
/// reference review header. Computed from fetched reviews only.
class _ReviewsSummaryCard extends StatelessWidget {
  const _ReviewsSummaryCard({
    required this.reviews,
    required this.onSelectStar,
    this.avgRating,
    this.ratingCount,
    this.selectedStar,
  });

  final List<Review> reviews;
  final double? avgRating;
  final int? ratingCount;
  final int? selectedStar;
  final ValueChanged<int?> onSelectStar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <int, int>{
      for (var star = 1; star <= 5; star++)
        star: reviews.where((r) => r.rating == star).length,
    };
    final total = reviews.length;
    final average = (avgRating != null && avgRating! > 0)
        ? avgRating!
        : (total == 0
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) / total);

    return GlassmorphicCard(
      borderRadius: 16,
      isInteractive: false,
      enableEntrance: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ratings & reviews',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total verified reviews',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.violetDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    average.toStringAsFixed(1),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.violet,
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          (i + 1) <= average.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                    ],
                  ),
                  Text(
                    'out of 5.0',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '$star★',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: total == 0 ? 0 : counts[star]! / total,
                                  minHeight: 6,
                                  color: AppTheme.accent,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 18,
                              child: Text(
                                '${counts[star]}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                visualDensity: VisualDensity.compact,
                selected: selectedStar == null,
                label: Text('All ($total)'),
                onSelected: (_) => onSelectStar(null),
              ),
              for (var star = 5; star >= 1; star--)
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  selected: selectedStar == star,
                  label: Text('$star★ (${counts[star]})'),
                  onSelected: (_) =>
                      onSelectStar(selectedStar == star ? null : star),
                ),
            ],
          ),
        ],
      ),
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
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.16),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.violetDeep,
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
                      color: AppTheme.violet,
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
