import '../../venues/domain/venue.dart';

/// Client-side search + category filter over the user's saved venues.
abstract final class SavedVenueFilter {
  /// Distinct categories present in [venues], in first-seen order.
  static List<VenueCategory> categoriesOf(List<Venue> venues) {
    final seen = <String>{};
    final result = <VenueCategory>[];
    for (final venue in venues) {
      final category = venue.category;
      if (category == null || category.name.trim().isEmpty) continue;
      final key = _categoryKey(category);
      if (seen.add(key)) result.add(category);
    }
    return result;
  }

  /// Venues whose name or city contains [query] (case-insensitive) and whose
  /// category matches [categoryKey] (from [keyOf]); a null key means any.
  static List<Venue> apply(
    List<Venue> venues, {
    String query = '',
    String? categoryKey,
  }) {
    final q = query.trim().toLowerCase();
    return venues.where((venue) {
      if (categoryKey != null) {
        final category = venue.category;
        if (category == null || _categoryKey(category) != categoryKey) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      return venue.name.toLowerCase().contains(q) ||
          venue.city.toLowerCase().contains(q);
    }).toList();
  }

  static String keyOf(VenueCategory category) => _categoryKey(category);

  static String _categoryKey(VenueCategory category) => category.id.isNotEmpty
      ? category.id
      : (category.slug.isNotEmpty ? category.slug : category.name);
}
