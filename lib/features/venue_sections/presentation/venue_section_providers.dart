import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/venue_section.dart';
import '../domain/venue_section_repository.dart';
import '../infrastructure/supabase_venue_section_repository.dart';

/// Venue section repository instance.
final venueSectionRepositoryProvider = Provider<VenueSectionRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseVenueSectionRepository(client);
});

/// The Admin-managed catalog of section types an Owner may add.
final venueSectionTypesProvider =
    FutureProvider.autoDispose<List<VenueSectionType>>((ref) {
  return ref.watch(venueSectionRepositoryProvider).sectionTypes();
});

/// Live draft sections for one venue, scoped by RLS to its own owner (or an
/// admin). Another owner's venue simply never emits anything visible here.
final ownerVenueSectionsProvider =
    StreamProvider.autoDispose.family<List<VenueSection>, String>(
        (ref, venueId) {
  return ref
      .watch(venueSectionRepositoryProvider)
      .ownerVenueSectionsStream(venueId);
});

/// Customer-facing published sections for one venue. Always goes through
/// the server-side `list_published_venue_sections` function.
final publishedVenueSectionsProvider = FutureProvider.autoDispose
    .family<List<PublishedVenueSection>, String>((ref, venueId) {
  return ref.watch(venueSectionRepositoryProvider).publishedSections(venueId);
});

/// Adds a section type instance to a venue.
final addVenueSectionProvider = FutureProvider.autoDispose.family<VenueSection,
    ({String venueId, VenueSectionType type})>((ref, params) async {
  final section = await ref.watch(venueSectionRepositoryProvider).addSection(
        venueId: params.venueId,
        type: params.type,
      );
  ref.invalidate(ownerVenueSectionsProvider(params.venueId));
  return section;
});

/// Saves draft edits for one section.
final updateVenueSectionProvider =
    FutureProvider.autoDispose.family<VenueSection, VenueSection>(
        (ref, section) async {
  final updated =
      await ref.watch(venueSectionRepositoryProvider).updateSection(section);
  ref.invalidate(ownerVenueSectionsProvider(section.venueId));
  return updated;
});

/// Removes a section from a venue.
final deleteVenueSectionProvider = FutureProvider.autoDispose
    .family<void, ({String venueId, String sectionId})>((ref, params) async {
  await ref
      .watch(venueSectionRepositoryProvider)
      .deleteSection(params.sectionId);
  ref.invalidate(ownerVenueSectionsProvider(params.venueId));
});

/// Persists a new section order for one venue.
final reorderVenueSectionsProvider = FutureProvider.autoDispose
    .family<void, ({String venueId, List<String> sectionIds})>(
        (ref, params) async {
  await ref.watch(venueSectionRepositoryProvider).reorderSections(
        params.venueId,
        params.sectionIds,
      );
  ref.invalidate(ownerVenueSectionsProvider(params.venueId));
});

/// Publishes every current draft for a venue.
final publishVenueSectionsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, venueId) async {
  final result = await ref.watch(venueSectionRepositoryProvider).publish(
        venueId,
      );
  ref.invalidate(ownerVenueSectionsProvider(venueId));
  ref.invalidate(publishedVenueSectionsProvider(venueId));
  return result;
});
