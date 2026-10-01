class UiElementOverride {
  const UiElementOverride({
    required this.id,
    required this.screenKey,
    required this.elementKey,
    required this.locale,
    this.text,
    this.placeholder,
    this.hidden = false,
    this.enabled = true,
  });

  final String id;
  final String screenKey;
  final String elementKey;
  final String locale;
  final String? text;
  final String? placeholder;
  final bool hidden;
  final bool enabled;

  factory UiElementOverride.fromJson(Map<String, dynamic> json) {
    return UiElementOverride(
      id: json['id'] as String? ?? '',
      screenKey: json['screen_key'] as String? ?? '',
      elementKey: json['element_key'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      text: json['text_value'] as String?,
      placeholder: json['placeholder_value'] as String?,
      hidden: json['is_hidden'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  factory UiElementOverride.fromResolvedJson(
    String elementKey,
    Map<String, dynamic> json,
  ) {
    return UiElementOverride(
      id: '',
      screenKey: '',
      elementKey: elementKey,
      locale: 'en',
      text: json['text'] as String?,
      placeholder: json['placeholder'] as String?,
      hidden: json['hidden'] as bool? ?? false,
    );
  }
}
