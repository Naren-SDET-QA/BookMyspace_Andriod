/// Kinds of non-venue listings a learner can save. Venues use favorites.
enum SavedItemType {
  course('course'),
  institute('institute');

  const SavedItemType(this.dbValue);
  final String dbValue;
}

/// A saved course or institute, with just enough to render a list row.
class SavedListing {
  const SavedListing({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl = '',
  });

  final SavedItemType type;
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
}

abstract interface class SavedItemsRepository {
  /// Ids I have saved, per type.
  Future<Map<SavedItemType, Set<String>>> savedIds();

  Future<void> save(SavedItemType type, String id);

  Future<void> unsave(SavedItemType type, String id);

  /// Saved listings of [type], newest first. Deleted listings are skipped.
  Future<List<SavedListing>> listings(SavedItemType type);
}
