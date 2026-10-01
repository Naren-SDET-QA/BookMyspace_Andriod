import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _future = ref.read(registrationConfigRepositoryProvider).allFields();
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
        title: const Text('Owner registration fields'),
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
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return Card(
                    child: SwitchListTile(
                      title: Text(field.label),
                      subtitle: Text(
                        '${field.key} · ${field.type.name} · '
                        '${field.required ? 'required' : 'optional'}'
                        '${field.sensitive ? ' · sensitive' : ''}'
                        '${field.regexPattern == null ? '' : ' · regex'}'
                        '${field.presetKey == null ? '' : ' · ${field.presetKey}'}',
                      ),
                      value: field.enabled,
                      onChanged: (value) => _update(field, {'enabled': value}),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit field',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditor(field),
                          ),
                          IconButton(
                            tooltip: 'Delete field',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(field),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'required') {
                                _update(field, {'required': !field.required});
                              } else if (action == 'owner') {
                                _update(field, {
                                  'owner_visible': !field.ownerVisible,
                                });
                              } else if (action == 'customer') {
                                _update(field, {
                                  'customer_visible': !field.customerVisible,
                                });
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'required',
                                child: Text(
                                  field.required
                                      ? 'Make optional'
                                      : 'Make required',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'owner',
                                child: Text(
                                  field.ownerVisible
                                      ? 'Hide from owners'
                                      : 'Show to owners',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'customer',
                                child: Text(
                                  field.customerVisible
                                      ? 'Hide from customers'
                                      : 'Show to customers',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
          title: Text(field == null ? 'Add registration field' : 'Edit field'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: key,
                    decoration: const InputDecoration(labelText: 'Key'),
                  ),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(labelText: 'Label'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
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
