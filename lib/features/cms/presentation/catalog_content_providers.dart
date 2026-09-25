import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/presentation/module_providers.dart';
import '../domain/catalog_content.dart';

/// Backend-driven discovery catalogue (Facility Type -> Section -> Subsection).
///
/// Reads the `category_catalog` document out of the existing feature-flag
/// config store, exactly as `homeAppearanceProvider` and `navTabsProvider`
/// read theirs. No new repository: [SupabaseFeatureFlagRepository] already
/// loads every document in one request, so adding this one costs no extra
/// round trip and inherits the same caching, invalidation and RLS.
///
/// **Never throws and never renders nothing.** While the request is loading,
/// or when the row is missing, disabled or malformed, this yields
/// [CatalogContent.defaults], which is generated from the hardcoded
/// `home_category_catalog.dart`. That is what keeps discovery working offline,
/// in widget tests, and against a database where no admin has saved anything.
///
/// Nothing renders from this yet. Batch 1 is the model and the read path;
/// migrating `MainHomeSection` call sites is a later batch, done one surface
/// at a time behind the override-else-default rule.
final catalogContentProvider = Provider<CatalogContent>((ref) {
  final flag = ref.watch(moduleFlagProvider(catalogContentFlagKey));

  // A disabled document means "fall back to the shipped catalogue", not "show
  // an empty app". This mirrors how an absent row behaves, so switching the
  // module off is a safe rollback rather than a way to break discovery.
  if (!flag.enabled) return CatalogContent.defaults;

  return CatalogContent.fromJson(flag.config);
});

/// Enabled facility types in admin order.
final visibleFacilityTypesProvider = Provider<List<CatalogFacilityType>>((ref) {
  final visible = ref.watch(catalogContentProvider).visible;
  // An admin who disabled every facility type would otherwise be left with an
  // empty discovery surface. Same guard as `visibleNavTabsProvider`.
  return visible.isEmpty ? CatalogContent.defaults.visible : visible;
});

/// One section by key, or `null` when this build's catalogue has no such
/// section. Callers treat `null` as "fall back to the hardcoded entry".
final catalogSectionProvider =
    Provider.family<CatalogSection?, String>((ref, key) {
  return ref.watch(catalogContentProvider).sectionFor(key);
});

/// Admin write path for the discovery catalogue.
///
/// Deliberately identical in shape to `HomeAppearanceController` and
/// `NavTabsController`: one `saveFlag` through the existing feature-flag
/// repository, then an invalidate. No new repository, no new table, and the
/// same RLS and audit trigger that already govern every other CMS document.
///
/// The write is **not** reported as successful until the backend confirms it.
/// A rejection (RLS, or the `validate_feature_flag_config` allowlist)
/// propagates to the caller so the editor can show it rather than leaving an
/// admin believing a change was published.
class CatalogContentController {
  CatalogContentController(this._ref);

  final Ref _ref;

  /// Publishes [content].
  ///
  /// Callers must validate with `CatalogValidator.canPublish` first. This
  /// method does not re-check: the database and the model parsers are the
  /// backstops, and silently repairing a document here would hide from the
  /// admin that what they saved is not what they will get.
  Future<void> save(CatalogContent content) async {
    final flag = _ref.read(moduleFlagProvider(catalogContentFlagKey));
    await _ref.read(featureFlagRepositoryProvider).saveFlag(
          key: catalogContentFlagKey,
          enabled: true,
          platforms: flag.platforms.isEmpty
              ? const ['ios', 'android', 'web']
              : flag.platforms,
          config: content.toJson(),
        );
    _ref.invalidate(featureFlagsProvider);
  }

  /// Restores the shipped catalogue by publishing an empty document.
  ///
  /// Writing `{}` rather than deleting the row keeps the rollback inside the
  /// same audited write path, and an empty config resolves to
  /// [CatalogContent.defaults] on read.
  Future<void> resetToDefaults() async {
    final flag = _ref.read(moduleFlagProvider(catalogContentFlagKey));
    await _ref.read(featureFlagRepositoryProvider).saveFlag(
      key: catalogContentFlagKey,
      enabled: true,
      platforms: flag.platforms.isEmpty
          ? const ['ios', 'android', 'web']
          : flag.platforms,
      config: const <String, dynamic>{},
    );
    _ref.invalidate(featureFlagsProvider);
  }
}

final catalogContentControllerProvider =
    Provider<CatalogContentController>(CatalogContentController.new);
