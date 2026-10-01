class ListingCustomField {
  const ListingCustomField({
    required this.id,
    required this.key,
    required this.label,
    required this.type,
    required this.options,
    required this.required,
    this.value,
  });

  final String id;
  final String key;
  final String label;
  final String type;
  final List<String> options;
  final bool required;
  final dynamic value;

  factory ListingCustomField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return ListingCustomField(
      id: json['field_id'] as String? ?? json['id'] as String? ?? '',
      key: json['field_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['field_type'] as String? ?? 'text',
      options: rawOptions is List
          ? rawOptions.whereType<String>().toList()
          : const [],
      required: json['required'] as bool? ?? false,
      value: json['value'],
    );
  }
}

abstract interface class ListingCustomFieldRepository {
  Future<List<ListingCustomField>> forVenue(String venueId);
}
