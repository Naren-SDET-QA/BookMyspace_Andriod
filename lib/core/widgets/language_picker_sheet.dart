import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/settings_controller.dart';
import '../localization/app_localizations.dart';

/// English names for the locales in [AppLocalizations.supportedLocales]; the
/// native-script names come from [AppLocalizations.languageLabel].
const Map<String, String> kLanguageEnglishNames = {
  'en': 'English',
  'te': 'Telugu',
  'hi': 'Hindi',
  'ta': 'Tamil',
  'kn': 'Kannada',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'gu': 'Gujarati',
  'ml': 'Malayalam',
  'es': 'Spanish',
};

String languageEnglishName(Locale locale) =>
    kLanguageEnglishNames[locale.languageCode] ?? locale.languageCode;

/// Supported locales whose English name, native name or language code
/// contains [query] (case-insensitive). An empty query returns all.
List<Locale> filterLanguages(
  String query, {
  List<Locale> locales = AppLocalizations.supportedLocales,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.of(locales);
  return locales.where((locale) {
    return languageEnglishName(locale).toLowerCase().contains(q) ||
        AppLocalizations.languageLabel(locale).toLowerCase().contains(q) ||
        locale.languageCode.toLowerCase() == q;
  }).toList();
}

/// Opens the searchable language picker and applies the chosen locale via
/// [localeProvider]. [keyPrefix] keys each option as `<prefix>-<code>`.
Future<void> showLanguagePickerSheet(
  BuildContext context,
  WidgetRef ref, {
  String keyPrefix = 'language-option',
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => LanguagePickerSheet(
      keyPrefix: keyPrefix,
      current: ref.read(localeProvider).languageCode,
      onSelected: (locale) {
        ref.read(localeProvider.notifier).setLocale(locale);
        Navigator.pop(sheetContext);
      },
    ),
  );
}

class LanguagePickerSheet extends StatefulWidget {
  const LanguagePickerSheet({
    super.key,
    required this.current,
    required this.onSelected,
    this.keyPrefix = 'language-option',
  });

  final String current;
  final ValueChanged<Locale> onSelected;
  final String keyPrefix;

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final locales = filterLanguages(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: media.size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Language',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select your language for instant localized navigation & voice assistance:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    key: const Key('language-search'),
                    controller: _controller,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search language…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: locales.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No languages match "$_query"',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final locale in locales)
                              ListTile(
                                key: Key(
                                  '${widget.keyPrefix}-${locale.languageCode}',
                                ),
                                leading: Text(
                                  _flagFor(locale.languageCode),
                                  style: const TextStyle(fontSize: 20),
                                ),
                                title: Text(
                                  AppLocalizations.languageLabel(locale),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(languageEnglishName(locale)),
                                selected: locale.languageCode == widget.current,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 18,
                                      ),
                                      tooltip: 'Listen pronunciation',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Playing voice sample: ${languageEnglishName(locale)}',
                                            ),
                                            duration: const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                    if (locale.languageCode == widget.current)
                                      Icon(
                                        Icons.check_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                                onTap: () => widget.onSelected(locale),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _flagFor(String code) {
    return switch (code) {
      'en' => '🇬🇧',
      'te' => '🇮🇳',
      'hi' => '🇮🇳',
      'ta' => '🇮🇳',
      'kn' => '🇮🇳',
      _ => '🌐',
    };
  }
}
