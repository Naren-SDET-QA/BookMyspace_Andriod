import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/configurable_form.dart';

/// Non-technical owner/admin editor: enable, require, rename, reorder,
/// add custom fields, preview, publish. No JSON required.
class ConfigurableFormBuilder extends StatelessWidget {
  const ConfigurableFormBuilder({
    super.key,
    required this.schema,
    required this.onChanged,
    this.aadhaarAllowed = false,
    this.onPreview,
    this.onPublish,
    this.busy = false,
  });

  final ConfigurableFormSchema schema;
  final ValueChanged<ConfigurableFormSchema> onChanged;
  final bool aadhaarAllowed;
  final VoidCallback? onPreview;
  final VoidCallback? onPublish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fields = [
      for (final field in schema.editorFields)
        if (aadhaarAllowed ||
            (field.key != 'aadhaar' && field.key != 'aadhaar_upload'))
          field,
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final errors = schema.setupErrors();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              errors.first,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fields.length,
          onReorder: (from, to) {
            final next = [...fields];
            if (to > from) to -= 1;
            final item = next.removeAt(from);
            next.insert(to, item);
            onChanged(
              schema.copyWith(
                draftFields: [
                  for (var i = 0; i < next.length; i++)
                    next[i].copyWith(displayOrder: i),
                ],
                status: 'draft',
              ),
            );
          },
          itemBuilder: (context, index) {
            final field = fields[index];
            return _FieldTile(
              key: ValueKey(field.key),
              field: field,
              onChanged: (updated) {
                final next = [...fields];
                next[index] = updated;
                onChanged(
                  schema.copyWith(draftFields: next, status: 'draft'),
                );
              },
              onDelete: field.custom
                  ? () {
                      onChanged(
                        schema.copyWith(
                          draftFields:
                              fields.where((f) => f.key != field.key).toList(),
                          status: 'draft',
                        ),
                      );
                    }
                  : null,
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addCustom(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add custom field'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (onPreview != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onPreview,
                  child: const Text('Preview'),
                ),
              ),
            if (onPreview != null) const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy || errors.isNotEmpty ? null : onPublish,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
                child: Text(busy ? 'Saving…' : 'Publish form'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addCustom(BuildContext context) async {
    final label = TextEditingController();
    final result = await showDialog<ConfigurableFieldDefinition>(
      context: context,
      builder: (context) {
        var type = ConfigurableFieldType.text;
        return AlertDialog(
          title: const Text('Custom field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ConfigurableFieldType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Field type'),
                items: ConfigurableFieldType.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) type = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = label.text.trim();
                if (name.isEmpty) return;
                final key =
                    'custom_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
                Navigator.pop(
                  context,
                  ConfigurableFieldDefinition(
                    key: key,
                    label: name,
                    type: type,
                    custom: true,
                    enabled: true,
                    visible: true,
                    displayOrder: schema.editorFields.length,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    onChanged(
      schema.copyWith(
        draftFields: [...schema.editorFields, result],
        status: 'draft',
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    super.key,
    required this.field,
    required this.onChanged,
    this.onDelete,
  });

  final ConfigurableFieldDefinition field;
  final ValueChanged<ConfigurableFieldDefinition> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_indicator_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: field.enabled,
                  onChanged: (value) => onChanged(
                    field.copyWith(
                      enabled: value,
                      visible: value ? field.visible : false,
                      required: value ? field.required : false,
                    ),
                  ),
                ),
              ],
            ),
            if (field.enabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Required'),
                value: field.required,
                onChanged: (value) => onChanged(
                  field.copyWith(required: value, visible: true),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Visible on form'),
                value: field.visible,
                onChanged: field.required
                    ? null
                    : (value) => onChanged(field.copyWith(visible: value)),
              ),
              TextFormField(
                initialValue: field.label,
                decoration: const InputDecoration(labelText: 'Display name'),
                onChanged: (value) => onChanged(field.copyWith(label: value)),
              ),
              TextFormField(
                initialValue: field.helpText,
                decoration: const InputDecoration(labelText: 'Help text'),
                onChanged: (value) =>
                    onChanged(field.copyWith(helpText: value)),
              ),
              if (onDelete != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onDelete,
                    child: const Text('Delete custom field'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
