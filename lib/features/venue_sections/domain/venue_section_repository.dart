import 'venue_section.dart';

/// Contract for Owner-facing plug-and-play venue section management, plus
/// the read-only customer path.
abstract interface class VenueSectionRepository {
  /// The Admin-managed catalog of supported section types. Read-only here --
  /// an Owner may never create, edit, or delete a type.
  Future<List<VenueSectionType>> sectionTypes();

  /// This venue's section drafts, in display order. RLS restricts this to
  /// the venue's own organisation (or an admin); another owner's venue
  /// returns nothing, never an error that reveals it exists.
  Future<List<VenueSection>> ownerVenueSections(String venueId);

  /// Live updates to this venue's section drafts.
  Stream<List<VenueSection>> ownerVenueSectionsStream(String venueId);

  /// Adds a section type instance to a venue (enabled by default, empty
  /// content). Fails server-side if the type is already added and does not
  /// allow multiple instances, or if the caller does not own the venue.
  Future<VenueSection> addSection({
    required String venueId,
    required VenueSectionType type,
  });

  /// Persists draft edits (enable/disable, title, content, icon,
  /// display order, visible subsections, config). Never touches publication
  /// state -- the server silently ignores any attempt to do so from here.
  Future<VenueSection> updateSection(VenueSection section);

  /// Removes a section instance (its draft; published customer copies are
  /// only cleared by publishing again after removal was requested).
  Future<void> deleteSection(String sectionId);

  /// Atomically persists a new section order for one venue.
  Future<void> reorderSections(String venueId, List<String> sectionIds);

  /// Uploads a section image into the org-scoped venue media bucket.
  Future<VenueSection> uploadSectionImage({
    required VenueSection section,
    required List<int> bytes,
    required String extension,
  });

  /// Removes a section's image metadata and its storage object.
  Future<void> removeSectionImage(VenueSection section);

  /// Publishes every current draft for this venue in one atomic step. This
  /// is the only path that can change what customers see.
  Future<Map<String, dynamic>> publish(String venueId);

  /// Publishes one authorized draft. Implementations must enforce ownership
  /// server-side; the default keeps older repository fakes source-compatible.
  Future<Map<String, dynamic>> publishSection(
          String venueId, String sectionId) =>
      publish(venueId);

  /// The published, customer-visible sections for a venue. Never reads the
  /// draft table directly -- always goes through the server-side
  /// `list_published_venue_sections` function.
  Future<List<PublishedVenueSection>> publishedSections(String venueId);
}
