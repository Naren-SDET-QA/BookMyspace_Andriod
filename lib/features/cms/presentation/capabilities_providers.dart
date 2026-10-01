import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_content.dart';
import '../domain/facility_capabilities.dart';
import 'catalog_content_providers.dart';

/// Resolved capabilities for a specific subsection, after inheritance through
/// the full hierarchy (subsection → section → facility type → defaults).
final resolvedCapabilitiesProvider =
    Provider.family<FacilityCapabilities, SubsectionRef>((ref, subsectionRef) {
  final content = ref.watch(catalogContentProvider);
  final type = content.facilityTypeFor(subsectionRef.typeKey);
  final section = type?.sections.cast<CatalogSection?>().firstWhere(
        (s) => s?.key == subsectionRef.sectionKey,
        orElse: () => null,
      );
  final subsection = section?.subsections.cast<CatalogSubsection?>().firstWhere(
        (s) => s?.key == subsectionRef.subsectionKey,
        orElse: () => null,
      );

  return FacilityCapabilities.resolve(
    subsection: subsection?.capabilities,
    section: section?.capabilities,
    type: type?.capabilities,
  );
});

/// Resolved capabilities for a section, after inheritance through
/// facility type → defaults.
final resolvedSectionCapabilitiesProvider =
    Provider.family<FacilityCapabilities, SectionRef>((ref, sectionRef) {
  final content = ref.watch(catalogContentProvider);
  final type = content.facilityTypeFor(sectionRef.typeKey);
  final section = type?.sections.cast<CatalogSection?>().firstWhere(
        (s) => s?.key == sectionRef.sectionKey,
        orElse: () => null,
      );

  return FacilityCapabilities.resolve(
    section: section?.capabilities,
    type: type?.capabilities,
  );
});

/// Resolved capabilities for a facility type, using defaults for anything not set.
final resolvedTypeCapabilitiesProvider =
    Provider.family<FacilityCapabilities, String>((ref, typeKey) {
  final content = ref.watch(catalogContentProvider);
  final type = content.facilityTypeFor(typeKey);

  return FacilityCapabilities.resolve(
    type: type?.capabilities,
  );
});

/// Resolved constraints for a subsection, after inheritance.
final resolvedConstraintsProvider =
    Provider.family<CapabilityConstraints?, SubsectionRef>(
        (ref, subsectionRef) {
  final content = ref.watch(catalogContentProvider);
  final type = content.facilityTypeFor(subsectionRef.typeKey);
  final section = type?.sections.cast<CatalogSection?>().firstWhere(
        (s) => s?.key == subsectionRef.sectionKey,
        orElse: () => null,
      );
  final subsection = section?.subsections.cast<CatalogSubsection?>().firstWhere(
        (s) => s?.key == subsectionRef.subsectionKey,
        orElse: () => null,
      );

  return _mergeConstraints(
    _mergeConstraints(subsection?.constraints, section?.constraints),
    type?.constraints,
  );
});

/// Resolved constraints for a section.
final resolvedSectionConstraintsProvider =
    Provider.family<CapabilityConstraints?, SectionRef>(
        (ref, sectionRef) {
  final content = ref.watch(catalogContentProvider);
  final type = content.facilityTypeFor(sectionRef.typeKey);
  final section = type?.sections.cast<CatalogSection?>().firstWhere(
        (s) => s?.key == sectionRef.sectionKey,
        orElse: () => null,
      );

  return _mergeConstraints(
    section?.constraints,
    type?.constraints,
  );
});

/// Merges constraints from child to parent, taking non-null values from child.
CapabilityConstraints? _mergeConstraints(
  CapabilityConstraints? child,
  CapabilityConstraints? parent,
) {
  return child?.mergeWith(parent ?? const CapabilityConstraints()) ?? parent;
}

/// Reference to a subsection in the hierarchy.
class SubsectionRef {
  const SubsectionRef({
    required this.typeKey,
    required this.sectionKey,
    required this.subsectionKey,
  });

  final String typeKey;
  final String sectionKey;
  final String subsectionKey;

  @override
  bool operator ==(Object other) =>
      other is SubsectionRef &&
      other.typeKey == typeKey &&
      other.sectionKey == sectionKey &&
      other.subsectionKey == subsectionKey;

  @override
  int get hashCode => Object.hash(typeKey, sectionKey, subsectionKey);
}

/// Reference to a section in the hierarchy.
class SectionRef {
  const SectionRef({
    required this.typeKey,
    required this.sectionKey,
  });

  final String typeKey;
  final String sectionKey;

  @override
  bool operator ==(Object other) =>
      other is SectionRef &&
      other.typeKey == typeKey &&
      other.sectionKey == sectionKey;

  @override
  int get hashCode => Object.hash(typeKey, sectionKey);
}
