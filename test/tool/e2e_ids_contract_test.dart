import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the Flutter and Playwright copies of the E2E identifiers in sync.
void main() {
  test('every E2eIds constant is mirrored in the Playwright ids', () {
    final dart = File('lib/core/widgets/test_id.dart').readAsStringSync();
    final ts = File('e2e-playwright/support/ids.ts').readAsStringSync();

    final constIds = RegExp(r"static const \w+ = '([a-z0-9_]+)';")
        .allMatches(dart)
        .map((match) => match.group(1)!)
        .toSet();
    final prefixes = RegExp(r"=> '([a-z0-9_]+)_\$")
        .allMatches(dart)
        .map((match) => match.group(1)!)
        .toSet();

    expect(constIds, isNotEmpty);
    expect(prefixes, isNotEmpty);
    for (final id in constIds) {
      expect(ts, contains("'$id'"), reason: 'ids.ts is missing "$id"');
    }
    for (final prefix in prefixes) {
      expect(ts, contains('`${prefix}_\${'), reason: 'ids.ts is missing $prefix');
    }
  });

  test('E2E ids are unique', () {
    final dart = File('lib/core/widgets/test_id.dart').readAsStringSync();
    final ids = RegExp(r"static const \w+ = '([a-z0-9_]+)';")
        .allMatches(dart)
        .map((match) => match.group(1)!)
        .toList();
    expect(ids.toSet().length, ids.length);
  });
}
