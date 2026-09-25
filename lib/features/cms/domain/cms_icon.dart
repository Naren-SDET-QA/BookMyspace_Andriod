import 'package:flutter/material.dart';

/// Resolves a stable, backend-safe icon **id** to a concrete [IconData].
///
/// Backend content never stores an `IconData`. Two reasons, both load-bearing:
///
/// 1. `IconData` is a code point plus a font family. Serializing it would pin
///    admin-authored content to Flutter's private glyph numbering, so a
///    Material Icons update could silently repaint saved content as a
///    different symbol.
/// 2. `flutter build --tree-shake-icons` can only keep glyphs it can prove are
///    used, which it does by looking for *const* `IconData` constructions. An
///    icon built at runtime from a backend integer defeats that analysis:
///    either the build fails, or every glyph in the font ships. A const
///    lookup table keeps tree-shaking working, because every icon this app can
///    render is written out literally below.
///
/// So the wire format is a short semantic id (`'hall'`, `'turf'`), deliberately
/// named for *meaning* rather than for the Material glyph behind it. That
/// lets the glyph be changed later without rewriting stored content.
///
/// An unknown id is never an error: [resolve] falls back so that content
/// authored against a newer build still renders on an older client instead of
/// throwing or showing a blank box.
class CmsIcon {
  const CmsIcon._();

  /// Rendered when an id is missing, empty or unknown to this build.
  static const IconData fallback = Icons.category_outlined;

  /// Id used when content omits an icon entirely.
  static const String fallbackId = 'category';

  /// Every icon backend content may reference, keyed by stable id.
  ///
  /// Additive only. Removing an id would blank out content that already
  /// references it; repointing one to a different glyph is allowed and is the
  /// reason ids are semantic rather than Material names.
  static const Map<String, IconData> _byId = <String, IconData>{
    // Generic
    'category': Icons.category_outlined,
    'star': Icons.star_outline_rounded,
    'bolt': Icons.bolt_outlined,
    'tag': Icons.local_offer_outlined,
    'calendar': Icons.calendar_today_outlined,
    'clock': Icons.schedule_outlined,
    'location': Icons.place_outlined,
    'search': Icons.search_outlined,
    'info': Icons.info_outline_rounded,

    // Facility types / sections
    'hall': Icons.account_balance_outlined,
    'celebration': Icons.celebration_outlined,
    'turf': Icons.sports_soccer_outlined,
    'trophy': Icons.emoji_events_outlined,
    'home': Icons.home_outlined,
    'bed': Icons.bed_outlined,
    'school': Icons.school_outlined,
    'hotel': Icons.hotel_outlined,
    'business': Icons.business_outlined,

    // Subsections
    'ring': Icons.favorite_outline_rounded,
    'banquet': Icons.dinner_dining_outlined,
    'convention': Icons.apartment_outlined,
    'party': Icons.nightlife_outlined,
    'garden': Icons.park_outlined,
    'crown': Icons.workspace_premium_outlined,
    'toast': Icons.local_bar_outlined,
    'gym': Icons.fitness_center_outlined,
    'desk': Icons.desk_outlined,
    'camera': Icons.photo_camera_outlined,
    'person': Icons.person_outline_rounded,
    'group': Icons.groups_outlined,
    'backpack': Icons.backpack_outlined,
    'sofa': Icons.chair_outlined,
    'book': Icons.menu_book_outlined,
    'pencil': Icons.edit_outlined,
    'computer': Icons.computer_outlined,
    'music': Icons.music_note_outlined,
    'suitcase': Icons.luggage_outlined,
    'palm': Icons.beach_access_outlined,
  };

  /// Ids this build understands, for validation and for a future admin picker.
  static Iterable<String> get knownIds => _byId.keys;

  /// True when [id] resolves to a real glyph in this build.
  static bool isKnown(Object? id) => id is String && _byId.containsKey(id);

  /// The glyph for [id], or [fallback] when it is missing or unknown.
  static IconData resolve(Object? id) {
    if (id is! String) return fallback;
    return _byId[id] ?? fallback;
  }

  /// Normalizes an incoming id, collapsing anything unusable to [fallbackId].
  ///
  /// Used on write paths so stored content never carries an id this build
  /// cannot render back.
  static String normalize(Object? id) {
    if (id is! String) return fallbackId;
    final trimmed = id.trim();
    return _byId.containsKey(trimmed) ? trimmed : fallbackId;
  }
}
