import 'package:flutter/foundation.dart';

import '../../venue_sections/domain/venue_section.dart';
import '../../venue_sections/domain/venue_section_repository.dart';
import '../domain/catalog_content.dart';
import '../domain/catalog_validation.dart';

/// Venue-scoped adapter over the existing CMS models and draft repository.
/// IDs only select a resource; ownership and publication are enforced by RLS/RPC.
class OwnerFacilityController extends ChangeNotifier {
  OwnerFacilityController(this.repository, this.venueId);
  final VenueSectionRepository repository;
  final String venueId;
  static const typeKey = 'owner_facilities';
  CatalogContent content = const CatalogContent([]);
  bool busy = false;
  bool loaded = false;
  bool dirty = false;
  String? error;
  VenueSectionType? _type;
  String? _sectionId;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (busy || dirty) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final types = await repository.sectionTypes();
      _type = types.where((t) => t.key == typeKey).firstOrNull;
      if (_type == null) throw StateError('Builder setup is unavailable');
      final rows = await repository.ownerVenueSections(venueId);
      final row = rows.where((s) => s.type.key == typeKey).firstOrNull;
      final raw = row?.config['facility_types'];
      // CatalogContent.fromJson intentionally adds global defaults. Owner
      // documents must instead parse only the owner's own facility nodes.
      content = CatalogContent(raw is List
          ? raw
              .map(CatalogFacilityType.fromJson)
              .whereType<CatalogFacilityType>()
              .toList()
          : []);
      loaded = true;
    } catch (_) {
      error =
          'Could not load facilities. Check your connection and access, then retry. If this persists, ask an administrator to enable the facility builder.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void edit(CatalogContent next) {
    if (busy) return;
    content = next;
    dirty = true;
    error = null;
    notifyListeners();
  }

  String get summary {
    final lines = <String>[];
    for (final f in content.visible) {
      lines.add(f.title.base);
      if (f.description.isNotEmpty) lines.add(f.description.base);
      for (final s in f.visibleSections) {
        lines.add('  ${s.title.base}');
        if (s.description.isNotEmpty) lines.add('  ${s.description.base}');
        for (final sub in s.visibleSubsections) {
          lines.add('    • ${sub.title.base}');
          if (sub.description.isNotEmpty)
            lines.add('      ${sub.description.base}');
        }
      }
      lines.add('');
    }
    return lines.join('\n').trim();
  }

  String? get validationError {
    for (final f in content.facilityTypes) {
      for (final n in <CatalogNode>[
        f,
        ...f.sections,
        for (final s in f.sections) ...s.subsections
      ]) {
        final problem = CatalogValidator.fieldTitle(n.title.base) ??
            CatalogValidator.fieldDescription(n.description.base) ??
            CatalogValidator.fieldMediaUrl(n.media.url) ??
            CatalogValidator.fieldIcon(n.iconId);
        if (problem != null) return problem;

        if (n.capabilities != null && !n.capabilities!.isEmpty) {
          final capErrors = n.capabilities!.validate(constraints: n.constraints);
          if (capErrors.isNotEmpty) return capErrors.first;
        }
      }
    }
    if (summary.length > 8000)
      return 'Shorten your facility descriptions before saving (8,000 characters total).';
    return null;
  }

  Future<void> _save() async {
    // Re-read before creating so a retry after a lost INSERT response reuses
    // the committed row. The existing non-multiple unique index is the backstop.
    final rows = await repository.ownerVenueSections(venueId);
    var row = rows.where((s) => s.type.key == typeKey).firstOrNull;
    row ??= await repository.addSection(venueId: venueId, type: _type!);
    _sectionId = row.id;
    await repository.updateSection(row.copyWith(
      title: 'Facilities',
      content: summary,
      isEnabled: content.visible.isNotEmpty,
      config: {...row.config, ...content.toJson()},
    ));
    dirty = false;
  }

  Future<bool> save() => _run(publishing: false);
  Future<bool> publish() => _run(publishing: true);
  Future<bool> _run({required bool publishing}) async {
    if (busy || !loaded) return false;
    error = validationError;
    if (error != null) {
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      if (dirty) await _save();
      if (publishing) {
        final result = _sectionId == null
            ? await repository.publish(venueId)
            : await repository.publishSection(venueId, _sectionId!);
        if (result['success'] != true) throw StateError('Publication rejected');
      }
      return true;
    } catch (_) {
      error = publishing && !dirty
          ? 'Your draft is saved, but publishing failed. Check your connection and publishing access, then retry.'
          : 'Could not save. Your edits are still here. Check your connection and access, then retry.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
