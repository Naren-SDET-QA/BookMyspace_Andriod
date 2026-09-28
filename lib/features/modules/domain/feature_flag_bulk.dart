import 'dart:convert';

import 'feature_flag.dart';

/// Admin-authored composition documents that share the `feature_flags` table
/// but are not on/off features. Presets and bulk toggles never touch them;
/// JSON import may still restore their configuration.
const kCompositionDocumentKeys = {
  'home_appearance',
  'nav_tabs',
  'category_catalog',
};

/// Modules the backend refuses to disable
/// (`validate_feature_flag_config`: payments, notifications, courses).
const kLockedOnModuleKeys = {'payments', 'notifications', 'courses'};

/// Modules kept on by "Disable non-core". Core auth, search, booking,
/// payments and profile surfaces are not optional modules in this app (they
/// have no flag), so the only flag-backed core keys are the server-locked
/// ones.
const kCoreModuleKeys = kLockedOnModuleKeys;

const kValidFlagPlatforms = {'ios', 'android', 'web'};

/// Curated module mixes, ported from the reference feature hub and mapped
/// onto the optional module keys this app actually has.
enum FeaturePreset {
  fullSuite('Full suite', 'Every optional module on.', {
    'offers': true,
    'events': true,
    'courses': true,
    'demo_registration': true,
    'course_feedback': true,
    'reviews': true,
    'favorites': true,
    'support': true,
    'analytics': true,
    'integrations': true,
    'referrals': true,
    'ai_booking': true,
  }),
  hospitalityAndPg(
    'Hospitality & PG',
    'Venues, stays and PG booking with offers, reviews and assistant; '
        'events and course modules off.',
    {
      'offers': true,
      'reviews': true,
      'favorites': true,
      'support': true,
      'analytics': true,
      'integrations': true,
      'ai_booking': true,
      'events': false,
      'courses': false,
      'demo_registration': false,
      'course_feedback': false,
    },
  ),
  eventsAndBanquets(
    'Events & banquets',
    'Function halls and events with offers and reviews; course modules and '
        'referrals off.',
    {
      'events': true,
      'offers': true,
      'reviews': true,
      'favorites': true,
      'support': true,
      'analytics': true,
      'integrations': true,
      'ai_booking': true,
      'courses': false,
      'demo_registration': false,
      'course_feedback': false,
      'referrals': false,
    },
  );

  const FeaturePreset(this.label, this.description, this.targets);

  final String label;
  final String description;

  /// Module key -> desired enabled state. Keys absent here are unchanged.
  final Map<String, bool> targets;
}

/// One pending write in a bulk operation.
class FlagChange {
  const FlagChange({required this.before, required this.after});

  final FeatureFlag before;
  final FeatureFlag after;

  String get key => after.key;
  bool get enabledChanged => before.enabled != after.enabled;
  bool get platformsChanged => !_sameList(before.platforms, after.platforms);
  bool get configChanged =>
      jsonEncode(before.config) != jsonEncode(after.config);

  /// Short human summary, e.g. `off → on · config`.
  String get summary {
    final parts = <String>[
      if (enabledChanged)
        '${before.enabled ? 'on' : 'off'} → ${after.enabled ? 'on' : 'off'}',
      if (platformsChanged) 'platforms: ${after.platforms.join(', ')}',
      if (configChanged) 'config updated',
    ];
    return parts.join(' · ');
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

FeatureFlag _withEnabled(FeatureFlag flag, bool enabled) => FeatureFlag(
  key: flag.key,
  enabled: enabled,
  platforms: flag.platforms,
  config: flag.config,
);

/// Toggle changes needed to reach [targets] from [current], skipping
/// composition documents, server-locked disables and no-ops.
List<FlagChange> planToggles(
  Map<String, FeatureFlag> current,
  Map<String, bool> targets,
) {
  final changes = <FlagChange>[];
  for (final entry in current.entries) {
    final key = entry.key;
    final target = targets[key];
    if (target == null || kCompositionDocumentKeys.contains(key)) continue;
    if (!target && kLockedOnModuleKeys.contains(key)) continue;
    if (entry.value.enabled == target) continue;
    changes.add(
      FlagChange(before: entry.value, after: _withEnabled(entry.value, target)),
    );
  }
  return changes;
}

List<FlagChange> planPreset(
  Map<String, FeatureFlag> current,
  FeaturePreset preset,
) => planToggles(current, preset.targets);

List<FlagChange> planEnableAll(Map<String, FeatureFlag> current) =>
    planToggles(current, {for (final key in current.keys) key: true});

List<FlagChange> planDisableNonCore(Map<String, FeatureFlag> current) =>
    planToggles(current, {
      for (final key in current.keys) key: kCoreModuleKeys.contains(key),
    });

/// Changes that restore every module in [current] to its manifest default
/// ([defaults]), including platforms and configuration.
List<FlagChange> planResetToDefaults(
  Map<String, FeatureFlag> current,
  Map<String, FeatureFlag> defaults,
) {
  final changes = <FlagChange>[];
  for (final entry in current.entries) {
    final fallback = defaults[entry.key];
    if (fallback == null) continue;
    if (!fallback.enabled && kLockedOnModuleKeys.contains(entry.key)) continue;
    final change = FlagChange(before: entry.value, after: fallback);
    if (change.enabledChanged ||
        change.platformsChanged ||
        change.configChanged) {
      changes.add(change);
    }
  }
  return changes;
}

/// Pretty-printed export of [flags] (sorted by key).
String exportFlagsJson(Map<String, FeatureFlag> flags, {DateTime? now}) {
  final keys = flags.keys.toList()..sort();
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'bookmyspace.feature_flags',
    'version': 1,
    if (now != null) 'exported_at': now.toUtc().toIso8601String(),
    'flags': [
      for (final key in keys)
        {
          'key': key,
          'enabled': flags[key]!.enabled,
          'platforms': flags[key]!.platforms,
          'config': flags[key]!.config,
        },
    ],
  });
}

/// Result of validating pasted JSON: either [errors] or [changes].
class FlagImportResult {
  const FlagImportResult({this.changes = const [], this.errors = const []});

  final List<FlagChange> changes;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// Parses an export produced by [exportFlagsJson] (or a bare list of flag
/// objects, or a `{key: bool}` map) and diffs it against [current].
///
/// Only keys present in [current] are accepted; `enabled` must be a bool,
/// `platforms` a non-empty subset of ios/android/web, `config` an object.
/// Omitted fields keep their current value.
FlagImportResult parseFlagsImport(
  String source,
  Map<String, FeatureFlag> current,
) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    return FlagImportResult(errors: ['Invalid JSON: ${e.message}']);
  }

  final List<Map<String, dynamic>> entries;
  if (decoded is Map && decoded['flags'] is List) {
    entries = [
      for (final item in decoded['flags'] as List)
        if (item is Map) Map<String, dynamic>.from(item) else {'_bad': item},
    ];
  } else if (decoded is List) {
    entries = [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item) else {'_bad': item},
    ];
  } else if (decoded is Map) {
    entries = [
      for (final e in decoded.entries)
        e.value is Map
            ? {
                'key': e.key.toString(),
                ...Map<String, dynamic>.from(e.value as Map),
              }
            : {'key': e.key.toString(), 'enabled': e.value},
    ];
  } else {
    return const FlagImportResult(
      errors: ['Expected an exported flags object or a list of flags.'],
    );
  }
  if (entries.isEmpty) {
    return const FlagImportResult(errors: ['No flags found in the JSON.']);
  }

  final errors = <String>[];
  final changes = <FlagChange>[];
  final seen = <String>{};
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final key = entry['key'];
    if (key is! String || key.isEmpty) {
      errors.add('Entry ${i + 1}: missing "key".');
      continue;
    }
    final before = current[key];
    if (before == null) {
      errors.add('Unknown module "$key".');
      continue;
    }
    if (!seen.add(key)) {
      errors.add('Duplicate module "$key".');
      continue;
    }
    final enabled = entry.containsKey('enabled')
        ? entry['enabled']
        : before.enabled;
    if (enabled is! bool) {
      errors.add('$key: "enabled" must be true or false.');
      continue;
    }
    if (!enabled && kLockedOnModuleKeys.contains(key)) {
      errors.add('$key cannot be disabled.');
      continue;
    }
    var platforms = before.platforms;
    if (entry.containsKey('platforms')) {
      final raw = entry['platforms'];
      if (raw is! List ||
          raw.isEmpty ||
          raw.any((p) => p is! String || !kValidFlagPlatforms.contains(p))) {
        errors.add(
          '$key: "platforms" must be a non-empty list of ios, android, web.',
        );
        continue;
      }
      platforms = raw.cast<String>().toList(growable: false);
    }
    var config = before.config;
    if (entry.containsKey('config')) {
      final raw = entry['config'];
      if (raw is! Map) {
        errors.add('$key: "config" must be a JSON object.');
        continue;
      }
      config = raw.map((k, v) => MapEntry(k.toString(), v));
    }
    final change = FlagChange(
      before: before,
      after: FeatureFlag(
        key: key,
        enabled: enabled,
        platforms: platforms,
        config: config,
      ),
    );
    if (change.enabledChanged ||
        change.platformsChanged ||
        change.configChanged) {
      changes.add(change);
    }
  }
  if (errors.isNotEmpty) return FlagImportResult(errors: errors);
  return FlagImportResult(changes: changes);
}
