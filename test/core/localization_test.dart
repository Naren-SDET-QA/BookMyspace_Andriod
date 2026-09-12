import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported locales include Indian languages without UI code changes', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'te', 'hi', 'kn', 'ta']),
    );
  });

  test('Telugu and Tamil nav labels are not English fallbacks', () {
    final te = AppLocalizations(const Locale('te'));
    final ta = AppLocalizations(const Locale('ta'));
    final en = AppLocalizations(const Locale('en'));
    expect(te.navHome, isNot(en.navHome));
    expect(ta.navSearch, isNot(en.navSearch));
    expect(te.apply, isNotEmpty);
    expect(ta.filters, isNotEmpty);
  });
}
