import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/auth/presentation/auth_providers.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/presentation/category_configuration_providers.dart';

/// Android listing-fields config, stored as category metadata on Supabase.
class AdminListingFieldsScreen extends ConsumerWidget {
  const AdminListingFieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(categoryConfigurationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing fields'),
        actions: [
          IconButton(
            tooltip: 'Custom listing fields',
            icon: const Icon(Icons.dynamic_form_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: SizedBox(
                  width: 720,
                  height: 620,
                  child: _CustomListingFieldManager(
                    client: ref.read(supabaseProvider),
                    categories: configs.valueOrNull ?? const [],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: configs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(categoryConfigurationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.tune,
              title: 'No category fields',
              message: 'Category configuration is loaded from the database.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    [
                      item.slug,
                      if (item.requiredFields.isNotEmpty)
                        'required: ${item.requiredFields.join(', ')}',
                      if (item.optionalFields.isNotEmpty)
                        'optional: ${item.optionalFields.join(', ')}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(context, ref, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CategoryConfiguration item,
  ) async {
    final required = TextEditingController(
      text: item.requiredFields.join(', '),
    );
    final optional = TextEditingController(
      text: item.optionalFields.join(', '),
    );
    final owner = TextEditingController(text: item.ownerFields.join(', '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.name} fields'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: required,
                decoration: const InputDecoration(
                  labelText: 'Required fields (comma separated)',
                ),
              ),
              TextField(
                controller: optional,
                decoration: const InputDecoration(
                  labelText: 'Optional fields (comma separated)',
                ),
              ),
              TextField(
                controller: owner,
                decoration: const InputDecoration(
                  labelText: 'Owner fields (comma separated)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    List<String> split(String raw) =>
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    try {
      final updated = item.copyWith(
        requiredFields: split(required.text),
        optionalFields: split(optional.text),
        ownerFields: split(owner.text),
      );
      await ref
          .read(categoryConfigurationRepositoryProvider)
          .updateMetadata(categoryId: item.id, metadata: updated.toMetadata());
      ref.invalidate(categoryConfigurationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _CustomListingFieldManager extends StatefulWidget {
  const _CustomListingFieldManager({
    required this.client,
    required this.categories,
  });

  final SupabaseClient client;
  final List<CategoryConfiguration> categories;

  @override
  State<_CustomListingFieldManager> createState() =>
      _CustomListingFieldManagerState();
}

class _CustomListingFieldManagerState
    extends State<_CustomListingFieldManager> {
  late Future<List<Map<String, dynamic>>> _future;

  static const types = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
    'multiselect',
    'url',
    'phone',
    'currency',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.client
        .from('venue_listing_field_definitions')
        .select('*')
        .order('display_order')
        .order('label')
        .then((rows) => rows.map(Map<String, dynamic>.from).toList());
  }

  Future<void> _save([Map<String, dynamic>? existing]) async {
    final key = TextEditingController(
      text: existing?['field_key'] as String? ?? '',
    );
    final label = TextEditingController(
      text: existing?['label'] as String? ?? '',
    );
    final options = TextEditingController(
      text: ((existing?['options'] as List?) ?? const []).join(', '),
    );
    var type = existing?['field_type'] as String? ?? 'text';
    var required = existing?['required'] as bool? ?? false;
    String? categoryId = existing?['category_id'] as String?;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existing == null ? 'Add listing field' : 'Edit listing field',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: key,
                  decoration: const InputDecoration(labelText: 'Field key'),
                ),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: types
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
                DropdownButtonFormField<String?>(
                  value: categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category (blank = all categories)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...widget.categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => categoryId = value),
                ),
                TextField(
                  controller: options,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma separated)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required'),
                  value: required,
                  onChanged: (value) => setState(() => required = value),
                ),
              ],
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
      await widget.client.rpc<Map<String, dynamic>>(
        'admin_save_listing_field_definition',
        params: {
          'p_id': existing?['id'],
          'p_category_id': categoryId,
          'p_field_key': key.text,
          'p_label': label.text,
          'p_field_type': type,
          'p_options': options.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
          'p_required': required,
          'p_enabled': true,
          'p_display_order': existing?['display_order'] ?? 0,
        },
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save field: $error')));
    }
    key.dispose();
    label.dispose();
    options.dispose();
  }

  Future<void> _delete(Map<String, dynamic> field) async {
    try {
      await widget.client.rpc<void>(
        'admin_delete_listing_field_definition',
        params: {'p_id': field['id']},
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete field: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Custom listing fields',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(onPressed: () => _save(), icon: const Icon(Icons.add)),
          ],
        ),
        const Text(
          'Fields are rendered on published venue details and can be scoped to a category.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                  child: Text('Could not load fields: ${snapshot.error}'),
                );
              final fields = snapshot.data ?? const <Map<String, dynamic>>[];
              if (fields.isEmpty)
                return const Center(child: Text('No custom fields configured'));
              return ListView.separated(
                itemCount: fields.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return ListTile(
                    title: Text(field['label']?.toString() ?? ''),
                    subtitle: Text(
                      '${field['field_key']} · ${field['field_type']} · ${field['category_id'] == null ? 'all categories' : 'category scoped'}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => _save(field),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _delete(field),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
