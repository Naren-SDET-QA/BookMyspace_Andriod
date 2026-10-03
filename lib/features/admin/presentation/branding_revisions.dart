import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_settings.dart';
import 'admin_settings_providers.dart';
import 'app_branding_providers.dart';

/// Minimal read/write contract over global `module_feature_configs` rows.
///
/// Implemented by `SupabaseAdminSettingsRepository`; tests pass an in-memory
/// fake. Writes stay behind the existing admin-only RLS policy.
abstract class BrandingSectionStore {
  Future<Map<String, dynamic>> loadSection(String section);
  Future<void> saveSection(String section, Map<String, dynamic> values);
}

class _RepositorySectionStore implements BrandingSectionStore {
  _RepositorySectionStore(this._ref);
  final Ref _ref;

  @override
  Future<Map<String, dynamic>> loadSection(String section) =>
      _ref.read(adminSettingsRepositoryProvider).loadSection(section);

  @override
  Future<void> saveSection(String section, Map<String, dynamic> values) =>
      _ref.read(adminSettingsRepositoryProvider).saveSection(section, values);
}

/// One published snapshot of global branding.
class BrandingRevision {
  const BrandingRevision({
    required this.values,
    required this.label,
    this.publishedAt,
  });

  final Map<String, dynamic> values;
  final String label;
  final DateTime? publishedAt;

  AppBranding get branding => AppBranding.fromMap(values);

  factory BrandingRevision.fromMap(Map<String, dynamic> map) {
    final raw = map['values'];
    return BrandingRevision(
      values: raw is Map ? Map<String, dynamic>.from(raw) : const {},
      label: (map['label'] as String?)?.trim().isNotEmpty == true
          ? (map['label'] as String).trim()
          : 'Published',
      publishedAt: DateTime.tryParse(map['published_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
    'values': values,
    'label': label,
    'published_at': publishedAt?.toUtc().toIso8601String(),
  };
}

/// An unpublished branding draft saved by an admin.
class BrandingDraft {
  const BrandingDraft({required this.values, this.savedAt});

  final Map<String, dynamic> values;
  final DateTime? savedAt;

  AppBranding get branding => AppBranding.fromMap(values);

  /// Returns `null` for an empty / cleared draft row.
  static BrandingDraft? fromMap(Map<String, dynamic> map) {
    final raw = map['values'];
    if (raw is! Map || raw.isEmpty) return null;
    return BrandingDraft(
      values: Map<String, dynamic>.from(raw),
      savedAt: DateTime.tryParse(map['saved_at']?.toString() ?? ''),
    );
  }
}

/// Draft / publish / history workflow for global branding (logo + loading
/// animation + wordmark). Published values stay in the single existing
/// `branding` row that every customer widget reads ([appBrandingProvider]);
/// the draft and the bounded history live in two sibling global rows of the
/// same table, so there is no new table, column or RLS policy.
class BrandingRevisionService {
  BrandingRevisionService(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const publishedSection = AdminSettings.brandingSection;
  static const draftSection = 'branding_draft';
  static const historySection = 'branding_history';
  static const maxHistory = 20;

  final BrandingSectionStore _store;
  final DateTime Function() _clock;

  /// Normalises [values] through [AppBranding] so only valid values persist.
  static Map<String, dynamic> normalise(Map<String, dynamic> values) =>
      AppBranding.fromMap(values).toMap();

  Future<BrandingDraft?> loadDraft() async =>
      BrandingDraft.fromMap(await _store.loadSection(draftSection));

  Future<void> saveDraft(Map<String, dynamic> values) =>
      _store.saveSection(draftSection, {
        'values': normalise(values),
        'saved_at': _clock().toUtc().toIso8601String(),
      });

  Future<void> discardDraft() => _store.saveSection(draftSection, const {});

  Future<List<BrandingRevision>> loadHistory() async =>
      parseHistory(await _store.loadSection(historySection));

  static List<BrandingRevision> parseHistory(Map<String, dynamic> meta) {
    final entries = meta['entries'];
    if (entries is! List) return const [];
    return [
      for (final e in entries)
        if (e is Map) BrandingRevision.fromMap(Map<String, dynamic>.from(e)),
    ];
  }

  /// Publishes [values] to the live `branding` row, records the snapshot in
  /// history (keeping the pre-existing live values as the first entry when
  /// history is empty, so the very first publish can still be undone) and
  /// clears the draft.
  Future<Map<String, dynamic>> publish(
    Map<String, dynamic> values, {
    String label = 'Published',
  }) async {
    final next = normalise(values);
    final previousRaw = await _store.loadSection(publishedSection);
    final history = await loadHistory();

    await _store.saveSection(publishedSection, next);

    final now = _clock();
    final entries = <BrandingRevision>[
      BrandingRevision(values: next, label: label, publishedAt: now),
      ...history,
      if (history.isEmpty)
        BrandingRevision(
          values: normalise(previousRaw),
          label: 'Before first Studio publish',
        ),
    ].take(maxHistory).toList();
    await _store.saveSection(historySection, {
      'entries': [for (final e in entries) e.toMap()],
    });
    await discardDraft();
    return next;
  }

  /// Re-publishes an earlier snapshot (history restore / undo).
  Future<Map<String, dynamic>> restore(BrandingRevision revision) =>
      publish(revision.values, label: 'Restored ${_describe(revision)}');

  /// Undo = re-publish the snapshot before the current live one.
  Future<Map<String, dynamic>?> undoLastPublish() async {
    final history = await loadHistory();
    if (history.length < 2) return null;
    return publish(history[1].values, label: 'Undo');
  }

  static String _describe(BrandingRevision r) {
    final at = r.publishedAt;
    if (at == null) return r.label.toLowerCase();
    final l = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'from ${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }
}

final brandingRevisionServiceProvider = Provider<BrandingRevisionService>(
  (ref) => BrandingRevisionService(_RepositorySectionStore(ref)),
);

final brandingDraftProvider = FutureProvider.autoDispose<BrandingDraft?>(
  (ref) => ref.watch(brandingRevisionServiceProvider).loadDraft(),
);

final brandingHistoryProvider =
    FutureProvider.autoDispose<List<BrandingRevision>>(
      (ref) => ref.watch(brandingRevisionServiceProvider).loadHistory(),
    );
