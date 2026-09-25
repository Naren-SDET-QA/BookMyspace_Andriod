import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/configurable_form.dart';

/// Student-facing renderer. Only [ConfigurableFormSchema.activeFields] are
/// built, so disabled/hidden/Aadhaar-off fields never appear.
class ConfigurableFormFields extends StatelessWidget {
  const ConfigurableFormFields({
    super.key,
    required this.schema,
    required this.values,
    required this.onChanged,
    this.autovalidate = false,
  });

  final ConfigurableFormSchema schema;
  final Map<String, dynamic> values;
  final void Function(String key, dynamic value) onChanged;
  final bool autovalidate;

  @override
  Widget build(BuildContext context) {
    final fields = schema.activeFields;
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          _Field(
            field: field,
            value: values[field.key],
            onChanged: (value) => onChanged(field.key, value),
            autovalidate: autovalidate,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.autovalidate,
  });

  final ConfigurableFieldDefinition field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool autovalidate;

  String? _validator(String? input) {
    final answers = {field.key: input ?? value};
    return ConfigurableFormSchema(
      publishedFields: [field],
    ).validateAnswers(answers)[field.key];
  }

  @override
  Widget build(BuildContext context) {
    final label = field.required ? '${field.label} *' : field.label;
    switch (field.type) {
      case ConfigurableFieldType.multiline:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          minLines: 3,
          maxLines: 5,
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decoration(label),
          validator: field.required ? _validator : null,
          onChanged: onChanged,
        );
      case ConfigurableFieldType.number:
      case ConfigurableFieldType.mobile:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decoration(label),
          validator: _validator,
          onChanged: onChanged,
        );
      case ConfigurableFieldType.email:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.emailAddress,
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decoration(label),
          validator: _validator,
          onChanged: onChanged,
        );
      case ConfigurableFieldType.date:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(
            value is DateTime
                ? (value as DateTime).toIso8601String().split('T').first
                : (value?.toString().isNotEmpty == true
                    ? value.toString()
                    : 'Pick a date'),
          ),
          trailing: const Icon(Icons.event_rounded),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 80),
              lastDate: now,
            );
            if (picked != null) onChanged(picked.toIso8601String());
          },
        );
      case ConfigurableFieldType.dropdown:
      case ConfigurableFieldType.radio:
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(value) ? value as String : null,
          decoration: _decoration(label),
          items: field.options
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          validator: field.required
              ? (v) => (v == null || v.isEmpty)
                  ? '${field.label} is required.'
                  : null
              : null,
          onChanged: onChanged,
        );
      case ConfigurableFieldType.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: field.helpText.isEmpty ? null : Text(field.helpText),
          value: value == true,
          onChanged: (v) => onChanged(v ?? false),
        );
      case ConfigurableFieldType.multiSelect:
        final selected = (value is List)
            ? value!.whereType<String>().toList()
            : const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final option in field.options)
                  FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: (on) {
                      final next = [...selected];
                      if (on) {
                        next.add(option);
                      } else {
                        next.remove(option);
                      }
                      onChanged(next);
                    },
                  ),
              ],
            ),
          ],
        );
      case ConfigurableFieldType.fileUpload:
      case ConfigurableFieldType.imageUpload:
      case ConfigurableFieldType.documentUpload:
        return InputDecorator(
          decoration: _decoration(label),
          child: Text(
            value == null || value.toString().isEmpty
                ? 'Upload from the device when submitting (URL stored).'
                : value.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          decoration: _decoration(label),
          validator: _validator,
          onChanged: onChanged,
          obscureText: field.sensitive && field.key == 'aadhaar',
        );
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      hintText: field.placeholder.isEmpty ? null : field.placeholder,
      helperText: field.helpText.isEmpty ? null : field.helpText,
    );
  }
}
