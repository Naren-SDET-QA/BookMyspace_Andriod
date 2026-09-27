/// Turns a category/subsection `icon` value into something safe to render
/// as text.
///
/// The `icon` column holds emoji for most rows, but some rows (from the
/// admin CMS or older seeds) store Material icon *names* such as `groups`,
/// `menu_book` or `computer`. Rendered as text those showed up literally
/// ("menu_book Coaching & Tuition"). Known names map to an equivalent emoji;
/// any other plain identifier falls back to [fallback]; real emoji pass
/// through unchanged.
String categoryIconText(String? icon, {String fallback = ''}) {
  final value = icon?.trim() ?? '';
  if (value.isEmpty) return fallback;
  if (!_identifier.hasMatch(value)) return value; // already an emoji/symbol
  return _nameToEmoji[value.toLowerCase()] ?? fallback;
}

/// Nullable variant for widgets that treat `null` as "no emoji".
String? categoryIconOrNull(String? icon) {
  final text = categoryIconText(icon);
  return text.isEmpty ? null : text;
}

final _identifier = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

const _nameToEmoji = <String, String>{
  'groups': '👥',
  'group': '👥',
  'people': '👥',
  'menu_book': '📖',
  'book': '📖',
  'school': '🎓',
  'computer': '💻',
  'laptop': '💻',
  'celebration': '🎉',
  'party': '🎉',
  'stadium': '🏟️',
  'sports': '🏅',
  'sports_soccer': '⚽',
  'sports_tennis': '🎾',
  'sports_cricket': '🏏',
  'fitness_center': '🏋️',
  'pool': '🏊',
  'apartment': '🏢',
  'business': '🏢',
  'home_work': '🏘️',
  'home': '🏠',
  'house': '🏠',
  'hotel': '🏨',
  'bed': '🛏️',
  'meeting_room': '🧑‍💼',
  'work': '💼',
  'music_note': '🎵',
  'palette': '🎨',
  'theater_comedy': '🎭',
  'restaurant': '🍽️',
  'local_parking': '🅿️',
  'park': '🌳',
  'nature': '🌿',
  'temple_hindu': '🛕',
  'church': '⛪',
  'mosque': '🕌',
  'store': '🏬',
  'shopping_bag': '🛍️',
  'event': '📅',
  'star': '⭐',
};
