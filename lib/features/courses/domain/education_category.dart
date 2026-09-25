/// Customer-facing coaching categories. Stored as `course_batches.category_slug`
/// when the milestone-6 columns exist; otherwise matched from title/subject.
enum EducationCategory {
  all('all', 'All'),
  coaching('coaching', 'Coaching'),
  sportsFitness('sports_fitness', 'Sports & Fitness'),
  academics('academics', 'Academics'),
  techCoding('tech_coding', 'Tech & Coding'),
  dance('dance', 'Dance'),
  musicArts('music_arts', 'Music & Arts');

  const EducationCategory(this.slug, this.label);

  final String slug;
  final String label;

  static EducationCategory fromSlug(String? value) {
    for (final item in EducationCategory.values) {
      if (item.slug == value) return item;
    }
    return EducationCategory.all;
  }

  bool matches({
    required String title,
    required String subject,
    required String categorySlug,
    required String instructor,
  }) {
    if (this == EducationCategory.all) return true;
    if (categorySlug == slug) return true;
    final haystack = '$title $subject $instructor $categorySlug'.toLowerCase();
    return switch (this) {
      EducationCategory.coaching => _has(haystack, const [
          'coach',
          'tuition',
          'academy',
          'jee',
          'neet',
          'prep',
        ]),
      EducationCategory.sportsFitness => _has(haystack, const [
          'sport',
          'fitness',
          'badminton',
          'cricket',
          'football',
          'turf',
          'yoga',
          'training',
        ]),
      EducationCategory.academics => _has(haystack, const [
          'math',
          'science',
          'tuition',
          'academic',
          'jee',
          'neet',
          'school',
        ]),
      EducationCategory.techCoding => _has(haystack, const [
          'code',
          'coding',
          'python',
          'java',
          'flutter',
          'bootcamp',
          'tech',
          'computer',
        ]),
      EducationCategory.dance => _has(haystack, const ['dance']),
      EducationCategory.musicArts =>
        _has(haystack, const ['music', 'art', 'guitar', 'piano', 'vocal']),
      EducationCategory.all => true,
    };
  }

  static bool _has(String haystack, List<String> tokens) =>
      tokens.any(haystack.contains);
}
