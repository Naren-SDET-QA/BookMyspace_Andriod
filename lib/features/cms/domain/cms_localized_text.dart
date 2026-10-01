import 'package:flutter/foundation.dart';

/// A base string plus optional per-language overrides.
///
/// This is the shape already used by `HomeBlockConfig.titles` / `.subtitles`
/// and by `venue_categories.name_i18n`, lifted into one type so every CMS
/// object resolves and serializes localized text the same way instead of each
/// screen re-implementing it.
///
/// Resolution order is deliberately forgiving, because a half-translated
/// catalogue must still render:
///
///   overrides[languageCode] -> base -> ''
///
/// A blank or whitespace-only override never wins. Clearing a field in an
/// admin editor therefore restores the base text rather than blanking the UI,
/// and an override that exists only as `""` in stored JSON is treated as
/// absent.
///
/// This type carries **content**, not shipped UI chrome. Interface strings
/// stay in `AppLocalizations`; the two meet at the call site, where a caller
/// passes the l10n default as [base] when the CMS supplies no value.
@immutable
class CmsLocalizedText {
  const CmsLocalizedText({this.base = '', this.overrides = const {}});

  /// Text used for any language without its own override.
  final String base;

  /// Per-language text keyed by language code (`en`, `te`, `hi`, `kn`, `ta`).
  final Map<String, String> overrides;

  static const CmsLocalizedText empty = CmsLocalizedText();

  /// True when neither the base nor any override carries text.
  bool get isEmpty => base.trim().isEmpty && overrides.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Languages that carry an explicit override, in no guaranteed order.
  Iterable<String> get translatedLanguages => overrides.keys;

  /// The text to render for [languageCode].
  String resolve(String languageCode) {
    final override = overrides[languageCode];
    if (override != null && override.trim().isNotEmpty) return override;
    return base;
  }

  /// [resolve], but falling back to [fallback] when this carries no text at
  /// all. Call sites pass the shipped `AppLocalizations` string here so a
  /// missing CMS value renders today's wording instead of an empty widget.
  String resolveOr(String languageCode, String fallback) {
    final value = resolve(languageCode);
    return value.trim().isEmpty ? fallback : value;
  }

  /// Sets one language, leaving the rest untouched.
  ///
  /// Clearing a language removes the override rather than storing `''`, which
  /// is what makes "clear the field to go back to the base text" work.
  CmsLocalizedText withLanguage(String languageCode, String value) {
    final next = Map<String, String>.from(overrides);
    if (value.trim().isEmpty) {
      next.remove(languageCode);
    } else {
      next[languageCode] = value;
    }
    return CmsLocalizedText(base: base, overrides: next);
  }

  CmsLocalizedText withBase(String value) {
    return CmsLocalizedText(base: value, overrides: overrides);
  }

  /// Reads either shape this codebase already stores:
  ///
  /// * a bare string  -> base only
  /// * `{"base": "...", "i18n": {"te": "..."}}`
  /// * a bare map `{"en": "...", "te": "..."}` -> overrides only
  ///
  /// Anything else yields [empty] rather than throwing, so one malformed field
  /// can never take down a whole catalogue document.
  factory CmsLocalizedText.fromJson(Object? json) {
    if (json is String) {
      return CmsLocalizedText(base: json);
    }
    if (json is! Map) return empty;

    final hasEnvelope = json.containsKey('base') || json.containsKey('i18n');
    if (hasEnvelope) {
      final rawBase = json['base'];
      return CmsLocalizedText(
        base: rawBase is String ? rawBase : '',
        overrides: readOverrides(json['i18n']),
      );
    }
    return CmsLocalizedText(overrides: readOverrides(json));
  }

  /// Emits the envelope form. Empty halves are omitted so a document stays
  /// small and diffable, and an all-empty value serializes to `{}`.
  Map<String, dynamic> toJson() => {
        if (base.isNotEmpty) 'base': base,
        if (overrides.isNotEmpty) 'i18n': Map<String, String>.from(overrides),
      };

  /// Reads a `{language: text}` map, dropping non-string and blank entries.
  @visibleForTesting
  static Map<String, String> readOverrides(Object? value) {
    if (value is! Map) return const {};
    final out = <String, String>{};
    value.forEach((key, entry) {
      if (entry is! String) return;
      if (entry.trim().isEmpty) return;
      out[key.toString()] = entry;
    });
    return out;
  }

  @override
  bool operator ==(Object other) {
    return other is CmsLocalizedText &&
        other.base == base &&
        mapEquals(other.overrides, overrides);
  }

  @override
  int get hashCode => Object.hash(
      base,
      Object.hashAllUnordered(
        overrides.entries.map((e) => Object.hash(e.key, e.value)),
      ));

  @override
  String toString() => 'CmsLocalizedText(base: $base, overrides: $overrides)';
}
