import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';

/// A tappable course card used in listings.
///
/// Visual layout matches the reference design's image-forward space cards
/// (a full-bleed cover photo with a category pill and the title/institute
/// overlaid on a bottom scrim, then a compact detail-and-CTA row below):
/// see `_SectionVenueCard` in home_screen.dart for the same pattern already
/// used for venues. Only real [Course]/[Institute] fields are shown --
/// the reference mock also has a star rating, a distance badge, a discount
/// ribbon and a photo-count indicator, but courses have no rating, no
/// distance, no discount and only a single [Course.coverImage], so those
/// four are intentionally left out rather than shown with invented values.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return GlassmorphicCard(
      borderRadius: 18,
      accentGradient: AppTheme.violetGradient,
      onTap: () =>
          context.push(AppRoutes.courseDetails.replaceAll(':id', course.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 168,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: course.coverImage, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _Pill(
                    text: _modeLabel(l10n, course.mode),
                    background: AppTheme.violet,
                  ),
                ),
                if (course.discountAmount > 0 && course.feeAmount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Pill(
                      text:
                          '${((course.discountAmount / course.feeAmount) * 100).round()}% ${l10n.off}',
                      background: AppTheme.accent,
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      if (course.instituteName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                course.instituteName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (course.instituteVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppTheme.violet,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.isFree
                            ? l10n.freeEvent
                            : '${l10n.courseFee} ${formatInr(course.feeAmount)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.violet,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.durationWeeks.replaceAll(
                          '{weeks}',
                          '${course.durationWeeks}',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.violet,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(AppLocalizations l10n, CourseMode mode) =>
      switch (mode) {
        CourseMode.online => l10n.modeOnline,
        CourseMode.offline => l10n.modeOffline,
        CourseMode.hybrid => l10n.modeHybrid,
      };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.background});

  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
