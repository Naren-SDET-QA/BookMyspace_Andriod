import 'package:flutter/material.dart';

import '../../domain/listing_custom_field.dart';

class CustomListingFieldsSection extends StatelessWidget {
  const CustomListingFieldsSection({super.key, required this.fields});

  final List<ListingCustomField> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Listing details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: fields.map((field) {
              final value = _displayValue(field.value);
              if (value.isEmpty) return const SizedBox.shrink();
              return ListTile(
                dense: true,
                title: Text(field.label),
                subtitle: Text(value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.map((item) => '$item').join(', ');
    return '$value';
  }
}
