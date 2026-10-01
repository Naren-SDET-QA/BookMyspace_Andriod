import 'course.dart';
import 'education_category.dart';

/// Multi-select category + availability filter applied client-side over the
/// already-loaded published courses (the "category checkbox" filter sheet).
///
/// An empty [categories] set means "no category restriction". When
/// [includeFullAndUpcoming] is false, batches that are full or have closed
/// admissions (i.e. only joinable through the waitlist) are hidden.
class ClassCategoryFilter {
  const ClassCategoryFilter({
    this.categories = const {},
    this.mode,
    this.includeFullAndUpcoming = true,
  });

  final Set<EducationCategory> categories;
  final CourseMode? mode;
  final bool includeFullAndUpcoming;

  /// Categories a user can pick in the sheet (everything but "All").
  static List<EducationCategory> get selectable => EducationCategory.values
      .where((c) => c != EducationCategory.all)
      .toList(growable: false);

  bool get hasCategoryRestriction => categories.isNotEmpty;

  ClassCategoryFilter copyWith({
    Set<EducationCategory>? categories,
    CourseMode? mode,
    bool clearMode = false,
    bool? includeFullAndUpcoming,
  }) {
    return ClassCategoryFilter(
      categories: categories ?? this.categories,
      mode: clearMode ? null : (mode ?? this.mode),
      includeFullAndUpcoming:
          includeFullAndUpcoming ?? this.includeFullAndUpcoming,
    );
  }

  ClassCategoryFilter toggle(EducationCategory category) {
    final next = {...categories};
    if (!next.remove(category)) next.add(category);
    return copyWith(categories: next);
  }

  ClassCategoryFilter selectAll() => copyWith(categories: selectable.toSet());

  ClassCategoryFilter clearAll() => copyWith(categories: const {});

  /// Whether [batch] of [course] belongs to [category]; uses the batch's
  /// `category_slug` first, then the course's `category_id`, then keywords.
  static bool batchInCategory(
    EducationCategory category,
    Course course,
    CourseBatch batch,
  ) {
    return category.matches(
      title: course.title,
      subject: batch.subject,
      categorySlug: batch.categorySlug.isNotEmpty
          ? batch.categorySlug
          : course.categoryId,
      instructor: course.instructorName,
    );
  }

  /// Whether [course] belongs to [category] via its own category or any of
  /// its active batches.
  static bool courseInCategory(EducationCategory category, Course course) {
    if (category.matches(
      title: course.title,
      subject: course.description,
      categorySlug: course.categoryId,
      instructor: course.instructorName,
    )) {
      return true;
    }
    return course.batches
        .where((b) => b.isActive)
        .any((b) => batchInCategory(category, course, b));
  }

  /// A batch that can currently only be joined through the waitlist.
  static bool isFullOrClosed(CourseBatch batch) =>
      batch.isFull || !batch.admissionsOpen;

  bool matchesBatch(Course course, CourseBatch batch) {
    if (mode != null && (batch.mode ?? course.mode) != mode) return false;
    if (!includeFullAndUpcoming && isFullOrClosed(batch)) return false;
    if (categories.isEmpty) return true;
    return categories.any((c) => batchInCategory(c, course, batch));
  }

  bool matchesCourse(Course course) {
    if (mode != null && course.mode != mode) return false;
    final active = course.batches.where((b) => b.isActive).toList();
    if (!includeFullAndUpcoming &&
        active.isNotEmpty &&
        active.every(isFullOrClosed)) {
      return false;
    }
    if (categories.isEmpty) return true;
    return categories.any((c) => courseInCategory(c, course));
  }

  /// Number of active batches per selectable category across [courses].
  static Map<EducationCategory, int> batchCounts(List<Course> courses) {
    final counts = {for (final c in selectable) c: 0};
    for (final course in courses) {
      for (final batch in course.batches.where((b) => b.isActive)) {
        for (final c in selectable) {
          if (batchInCategory(c, course, batch)) {
            counts[c] = counts[c]! + 1;
          }
        }
      }
    }
    return counts;
  }
}

/// Client-side class feed used by Education and the courses list.
///
/// Seat counts are not changed here. Enrollment still goes through the
/// server, which is the same path on iOS, web, and Android.
class ClassFeedQuery {
  const ClassFeedQuery({
    this.text = '',
    this.filter = const ClassCategoryFilter(),
    this.ongoingToday = false,
    this.fullOrWaitlistOnly = false,
    this.maxFee,
    this.city,
  });

  final String text;
  final ClassCategoryFilter filter;
  final bool ongoingToday;
  final bool fullOrWaitlistOnly;
  final double? maxFee;
  final String? city;

  List<({Course course, CourseBatch batch})> apply(List<Course> courses) {
    final needle = text.trim().toLowerCase();
    final cityNeedle = city?.trim().toLowerCase() ?? '';
    final matches = <({Course course, CourseBatch batch})>[];
    for (final course in courses) {
      if (cityNeedle.isNotEmpty &&
          course.instituteCity.isNotEmpty &&
          !course.instituteCity.toLowerCase().contains(cityNeedle)) {
        continue;
      }
      for (final batch in course.batches.where((item) => item.isActive)) {
        if (ongoingToday && !batch.isOngoingToday) continue;
        if (fullOrWaitlistOnly && !batch.isFull && !batch.waitlistEnabled) {
          continue;
        }
        if (!filter.matchesBatch(course, batch)) continue;
        final fee =
            batch.feeAmount > 0 ? batch.feeAmount : course.payableAmount;
        if (maxFee != null && fee > maxFee!) continue;
        if (needle.isNotEmpty) {
          final haystack = [
            course.title,
            batch.subject,
            batch.label,
            course.description,
            course.instituteName,
            course.instructorName,
            course.instituteCity,
            for (final faculty in course.faculty) faculty.name,
          ].join(' ').toLowerCase();
          if (!haystack.contains(needle)) continue;
        }
        matches.add((course: course, batch: batch));
      }
    }
    return matches;
  }
}
