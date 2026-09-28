import 'catalog_content.dart';

/// Live listing numbers for one or more `venue_categories` slugs.
class CategoryListingStats {
  const CategoryListingStats({this.listings = 0, this.withImages = 0});

  final int listings;

  /// Listings that have at least one `venue_images` row.
  final int withImages;

  int get withoutImages => listings - withImages;

  CategoryListingStats operator +(CategoryListingStats other) =>
      CategoryListingStats(
        listings: listings + other.listings,
        withImages: withImages + other.withImages,
      );
}

enum CategoryHealthStatus {
  healthy('Healthy'),
  needsAttention('Needs attention'),
  critical('Critical');

  const CategoryHealthStatus(this.label);
  final String label;

  static CategoryHealthStatus forScore(int score) {
    if (score >= 80) return CategoryHealthStatus.healthy;
    if (score >= 50) return CategoryHealthStatus.needsAttention;
    return CategoryHealthStatus.critical;
  }
}

/// What the admin can do about an issue.
enum CategoryFixAction { disable, edit }

class CategoryHealthIssue {
  const CategoryHealthIssue({
    required this.message,
    required this.penalty,
    required this.fixLabel,
    required this.action,
  });

  final String message;
  final int penalty;
  final String fixLabel;
  final CategoryFixAction action;
}

/// Health of one catalogue section or subsection.
class CategoryHealth {
  const CategoryHealth({
    required this.typeKey,
    required this.sectionKey,
    required this.subsectionKey,
    required this.title,
    required this.enabled,
    required this.score,
    required this.issues,
    this.stats,
  });

  final String typeKey;
  final String sectionKey;

  /// Null for a section-level entry.
  final String? subsectionKey;
  final String title;
  final bool enabled;
  final int score;
  final List<CategoryHealthIssue> issues;

  /// Null when live listing counts could not be loaded.
  final CategoryListingStats? stats;

  CategoryHealthStatus get status => CategoryHealthStatus.forScore(score);
  bool get needsHealing => status != CategoryHealthStatus.healthy;
  String get key => subsectionKey ?? sectionKey;
}

/// Category health scoring, ported from the reference CategoryHealthEngine:
/// start at 100; -30 missing title or slug; -25 an enabled category with no
/// listings; -15 when some listings have no images. Healthy >= 80, needs
/// attention 50-79, critical < 50.
class CategoryHealthEngine {
  static const missingTitleOrSlugPenalty = 30;
  static const emptyActivePenalty = 25;
  static const missingImagesPenalty = 15;

  static ({int score, List<CategoryHealthIssue> issues}) score({
    required String title,
    required String slug,
    required bool enabled,
    CategoryListingStats? stats,
  }) {
    final issues = <CategoryHealthIssue>[];
    if (title.trim().isEmpty || slug.trim().isEmpty) {
      issues.add(
        const CategoryHealthIssue(
          message: 'Missing title or id',
          penalty: missingTitleOrSlugPenalty,
          fixLabel: 'Add a title',
          action: CategoryFixAction.edit,
        ),
      );
    }
    if (stats != null) {
      if (enabled && stats.listings == 0) {
        issues.add(
          const CategoryHealthIssue(
            message: 'Visible to customers but has no listings',
            penalty: emptyActivePenalty,
            fixLabel: 'Disable empty category',
            action: CategoryFixAction.disable,
          ),
        );
      }
      if (stats.listings > 0 && stats.withoutImages > 0) {
        issues.add(
          CategoryHealthIssue(
            message:
                '${stats.withoutImages} of ${stats.listings} listings have '
                'no images',
            penalty: missingImagesPenalty,
            fixLabel: 'Open editor',
            action: CategoryFixAction.edit,
          ),
        );
      }
    }
    final total = issues.fold<int>(100, (s, i) => s - i.penalty);
    return (score: total.clamp(0, 100), issues: issues);
  }

  /// Health for every section and subsection in [content]. [statsBySlug] maps
  /// `venue_categories.slug` to live listing numbers; pass null when they are
  /// unavailable (listing rules are then skipped). Sorted worst first.
  static List<CategoryHealth> evaluate(
    CatalogContent content, {
    Map<String, CategoryListingStats>? statsBySlug,
  }) {
    CategoryListingStats? statsFor(Iterable<String> slugs) {
      if (statsBySlug == null) return null;
      var total = const CategoryListingStats();
      for (final slug in {...slugs}) {
        total = total + (statsBySlug[slug] ?? const CategoryListingStats());
      }
      return total;
    }

    final out = <CategoryHealth>[];
    for (final type in content.facilityTypes) {
      for (final section in type.sections) {
        final subSlugs = [
          for (final sub in section.subsections) ...[
            sub.key,
            ...sub.aliasSlugs,
          ],
        ];
        final sectionStats = statsFor([...section.searchAliases, ...subSlugs]);
        final sectionScore = score(
          title: section.title.base,
          slug: section.key,
          enabled: section.enabled && type.enabled,
          stats: sectionStats,
        );
        out.add(
          CategoryHealth(
            typeKey: type.key,
            sectionKey: section.key,
            subsectionKey: null,
            title: section.title.base.isEmpty
                ? section.key
                : section.title.base,
            enabled: section.enabled,
            score: sectionScore.score,
            issues: sectionScore.issues,
            stats: sectionStats,
          ),
        );
        for (final sub in section.subsections) {
          final subStats = statsFor([sub.key, ...sub.aliasSlugs]);
          final subScore = score(
            title: sub.title.base,
            slug: sub.key,
            enabled: sub.enabled && section.enabled && type.enabled,
            stats: subStats,
          );
          out.add(
            CategoryHealth(
              typeKey: type.key,
              sectionKey: section.key,
              subsectionKey: sub.key,
              title: sub.title.base.isEmpty ? sub.key : sub.title.base,
              enabled: sub.enabled,
              score: subScore.score,
              issues: subScore.issues,
              stats: subStats,
            ),
          );
        }
      }
    }
    out.sort((a, b) => a.score.compareTo(b.score));
    return out;
  }
}

/// Live listing counts per category slug, for the catalogue health view.
abstract interface class CategoryListingStatsRepository {
  Future<Map<String, CategoryListingStats>> statsBySlug();
}
