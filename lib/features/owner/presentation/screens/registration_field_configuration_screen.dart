import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/registration_field_config.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../owner_providers.dart';

/// Admin-only configuration for the fields shown during owner registration.
class RegistrationFieldConfigurationScreen extends ConsumerStatefulWidget {
  const RegistrationFieldConfigurationScreen({super.key});

  @override
  ConsumerState<RegistrationFieldConfigurationScreen> createState() =>
      _RegistrationFieldConfigurationScreenState();
}

class _RegistrationFieldConfigurationScreenState
    extends ConsumerState<RegistrationFieldConfigurationScreen> {
  late Future<List<RegistrationFieldConfig>> _future;
  final _search = TextEditingController();
  String _audience = 'all';

  @override
  void initState() {
    super.initState();
    _future = ref.read(registrationConfigRepositoryProvider).allFields();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _future = ref.read(registrationConfigRepositoryProvider).allFields();
  });

  Future<void> _update(
    RegistrationFieldConfig field,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref
          .read(registrationConfigRepositoryProvider)
          .updateFieldConfig(field.key, changes);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update field: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Schema & KYC'),
        actions: [
          IconButton(
            tooltip: 'Add field',
            icon: const Icon(Icons.add),
            onPressed: _showEditor,
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return const Center(child: Text('Administrator access required'));
          }
          return FutureBuilder<List<RegistrationFieldConfig>>(
            future: _future,
            builder: (context, fieldsSnapshot) {
              if (fieldsSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (fieldsSnapshot.hasError) {
                return Center(
                  child: Text('Could not load fields: ${fieldsSnapshot.error}'),
                );
              }
              final fields =
                  fieldsSnapshot.data ?? const <RegistrationFieldConfig>[];
              if (fields.isEmpty) {
                return const Center(
                  child: Text('No registration fields configured'),
                );
              }
              final query = _search.text.trim().toLowerCase();
              final visible = fields.where((field) {
                final audienceOk = switch (_audience) {
                  'customer' => field.customerVisible,
                  'owner' => field.ownerVisible,
                  _ => true,
                };
                if (!audienceOk) return false;
                if (query.isEmpty) return true;
                return field.label.toLowerCase().contains(query) ||
                    field.key.toLowerCase().contains(query);
              }).toList();
              final quick = fields.where(_isQuickToggle).toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search fields (photo, aadhaar, dob...)',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final audience in const [
                              'all',
                              'customer',
                              'owner',
                            ])
                              ChoiceChip(
                                label: Text(
                                  audience == 'all'
                                      ? 'All User Types (${fields.length})'
                                      : audience == 'customer'
                                      ? 'Customer / Member'
                                      : 'Venue Owner',
                                ),
                                selected: _audience == audience,
                                onSelected: (_) =>
                                    setState(() => _audience = audience),
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.data_object_rounded, size: 18),
                              label: const Text('JSON Schema'),
                              onPressed: () => _showSchema(fields),
                            ),
                          ],
                        ),
                        if (quick.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Quick mandatory toggles',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final field in quick)
                                FilterChip(
                                  label: Text(
                                    field.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  selected: field.required,
                                  onSelected: (value) => _update(field, {
                                    'required': value,
                                  }),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Fields: ${visible.length} shown, '
                          '${fields.where((field) => field.required).length} mandatory, '
                          '${fields.where((field) => field.enabled).length} active',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final field = visible[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        field.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: field.enabled,
                                      onChanged: (value) =>
                                          _update(field, {'enabled': value}),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${field.key} · ${field.type.name} · '
                                  '${field.required ? 'mandatory' : 'optional'}'
                                  '${field.customerVisible ? ' · customer' : ''}'
                                  '${field.ownerVisible ? ' · owner' : ''}',
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () => _showEditor(field),
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: () => _update(field, {
                                        'required': !field.required,
                                      }),
                                      child: Text(
                                        field.required
                                            ? 'Make optional'
                                            : 'Make mandatory',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(field),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _isQuickToggle(RegistrationFieldConfig field) {
    final haystack = '${field.key} ${field.label}'.toLowerCase();
    return haystack.contains('aadhaar') ||
        haystack.contains('identity') ||
        haystack.contains('dob') ||
        haystack.contains('birth') ||
        haystack.contains('company') ||
        haystack.contains('photo');
  }

  Future<void> _showSchema(List<RegistrationFieldConfig> fields) async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': '2.0',
      'description': 'BookMySpace owner registration fields',
      'totalFields': fields.length,
      'requiredCount': fields.where((field) => field.required).length,
      'fields': [
        for (final field in fields)
          {
            'key': field.key,
            'label': field.label,
            'type': field.type.name,
            'required': field.required,
            'enabled': field.enabled,
            'customerVisible': field.customerVisible,
            'ownerVisible': field.ownerVisible,
          },
      ],
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('JSON Schema Configuration'),
        content: SizedBox(
          width: math.min(
            520,
            math.max(0, MediaQuery.sizeOf(dialogContext).width - 128),
          ),
          child: SingleChildScrollView(child: SelectableText(json)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor([RegistrationFieldConfig? field]) async {
    final key = TextEditingController(text: field?.key ?? '');
    final label = TextEditingController(text: field?.label ?? '');
    final regex = TextEditingController(text: field?.regexPattern ?? '');
    final preset = TextEditingController(text: field?.presetKey ?? '');
    final options = TextEditingController(
      text: field?.options.join(', ') ?? '',
    );
    var type = field?.type.name ?? 'text';
    var required = field?.required ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            field == null ? 'Add New Registration Field' : 'Edit field',
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: math.min(
                420,
                math.max(0, MediaQuery.sizeOf(context).width - 128),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(labelText: 'Display Label *'),
                  ),
                  TextField(
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Internal Key * (e.g. aadhaar_number)',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: RegistrationFieldType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value.name,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  TextField(
                    controller: options,
                    decoration: const InputDecoration(
                      labelText: 'Options (comma separated)',
                    ),
                  ),
                  TextField(
                    controller: regex,
                    decoration: const InputDecoration(
                      labelText: 'Validation regex (optional)',
                    ),
                  ),
                  TextField(
                    controller: preset,
                    decoration: const InputDecoration(
                      labelText: 'JSON preset key (optional)',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Required'),
                    value: required,
                    onChanged: (value) =>
                        setDialogState(() => required = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(field == null ? 'Add Field' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ref
          .read(registrationConfigRepositoryProvider)
          .saveField(
            key: key.text,
            label: label.text,
            type: type,
            required: required,
            regexPattern: regex.text,
            presetKey: preset.text,
            validationRules: {
              'options': options.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
            },
            displayOrder: field == null ? 9999 : 0,
          );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save field: $error')));
    }
    key.dispose();
    label.dispose();
    regex.dispose();
    preset.dispose();
    options.dispose();
  }

  Future<void> _delete(RegistrationFieldConfig field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${field.label}?'),
        content: const Text(
          'Existing owner values for this field will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(registrationConfigRepositoryProvider)
          .deleteField(field.key);
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete field: $error')));
    }
  }

  Future<bool> _isAdmin() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId);
    return rows.any(
      (row) =>
          row['role'] == 'administrator' ||
          row['role'] == 'super_administrator',
    );
  }
}
