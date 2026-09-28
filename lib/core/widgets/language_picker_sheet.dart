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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Choose language',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('language-search'),
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search languages',
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
                              title: Text(
                                AppLocalizations.languageLabel(locale),
                              ),
                              subtitle: Text(languageEnglishName(locale)),
                              selected: locale.languageCode == widget.current,
                              trailing: locale.languageCode == widget.current
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () => widget.onSelected(locale),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
