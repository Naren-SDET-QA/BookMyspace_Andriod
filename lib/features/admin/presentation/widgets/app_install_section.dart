import 'package:flutter/material.dart';

import '../../domain/app_install_config.dart';

/// Admin settings section for the web, Play Store, and APK install offer.
class AppInstallSection extends StatefulWidget {
  const AppInstallSection({
    super.key,
    required this.install,
    required this.onSave,
  });

  final Map<String, dynamic> install;
  final Future<void> Function(Map<String, dynamic> values) onSave;

  @override
  State<AppInstallSection> createState() => _AppInstallSectionState();
}

class _AppInstallSectionState extends State<AppInstallSection> {
  late Map<String, dynamic> values;
  late final TextEditingController _play;
  late final TextEditingController _apk;
  late final TextEditingController _title;
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    values = {...AppInstallConfig.defaultMap, ...widget.install};
    _play = TextEditingController(text: values['play_store_url']?.toString());
    _apk = TextEditingController(text: values['apk_url']?.toString());
    _title = TextEditingController(text: values['title']?.toString());
    _message = TextEditingController(text: values['message']?.toString());
  }

  @override
  void dispose() {
    _play.dispose();
    _apk.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
    ...values,
    'play_store_url': _play.text,
    'apk_url': _apk.text,
    'title': _title.text,
    'message': _message.text,
  };

  Future<bool> _persist(
    Map<String, dynamic> payload, {
    required String success,
  }) async {
    final config = AppInstallConfig.fromMap(payload);
    final error = config.saveError;
    if (error != null) {
      _snack(error);
      return false;
    }
    try {
      await widget.onSave(config.toMap());
      if (!mounted) return false;
      _snack(success);
      return true;
    } catch (_) {
      if (mounted) _snack('Settings could not be saved');
      return false;
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('App install'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Customers see only the options you turn on. Web offers Add to '
            'Home Screen. Android opens the Play Store or downloads the APK. '
            'iPhone users only see the web option.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('admin-install-web'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Web app'),
            subtitle: const Text('Offer Add to Home Screen in the browser.'),
            value: values['web_enabled'] == true,
            onChanged: (v) => setState(() => values['web_enabled'] = v),
          ),
          SwitchListTile(
            key: const Key('admin-install-android'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Android — Play Store'),
            subtitle: const Text('https://play.google.com/store link.'),
            value: values['android_enabled'] == true,
            onChanged: (v) => setState(() => values['android_enabled'] = v),
          ),
          TextFormField(
            key: const Key('admin-install-play-url'),
            controller: _play,
            decoration: const InputDecoration(
              labelText: 'Play Store URL',
              hintText: 'https://play.google.com/store/apps/details?id=',
            ),
            keyboardType: TextInputType.url,
          ),
          SwitchListTile(
            key: const Key('admin-install-apk'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Android — APK file'),
            subtitle: const Text('Direct https link to the APK file.'),
            value: values['apk_enabled'] == true,
            onChanged: (v) => setState(() => values['apk_enabled'] = v),
          ),
          TextFormField(
            key: const Key('admin-install-apk-url'),
            controller: _apk,
            decoration: const InputDecoration(labelText: 'APK download URL'),
            keyboardType: TextInputType.url,
          ),
          TextFormField(
            key: const Key('admin-install-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Card title'),
          ),
          TextFormField(
            key: const Key('admin-install-message'),
            controller: _message,
            decoration: const InputDecoration(labelText: 'Card message'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('admin-install-reset'),
                  onPressed: () async {
                    final restored = await _persist(
                      Map<String, dynamic>.from(AppInstallConfig.defaultMap),
                      success: 'Defaults restored',
                    );
                    if (!restored || !mounted) return;
                    setState(() {
                      values = Map<String, dynamic>.from(
                        AppInstallConfig.defaultMap,
                      );
                      _play.text = '';
                      _apk.text = '';
                      _title.text = AppInstallConfig.defaultTitle;
                      _message.text = AppInstallConfig.defaultMessage;
                    });
                  },
                  child: const Text('Reset/default'),
                ),
                FilledButton.icon(
                  key: const Key('admin-install-save'),
                  onPressed: () =>
                      _persist(_payload(), success: 'Settings saved'),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
