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
    this.imageUrl,
    this.linkUrl,
    this.colorValue,
  });

  final String id;
  final String screenKey;
  final String elementKey;
  final String locale;
  final String? text;
  final String? placeholder;
  final bool hidden;
  final bool enabled;

  /// Image URL override (any image / icon / banner / logo slot on screen).
  final String? imageUrl;

  /// Deep-link / route override for tappable elements.
  final String? linkUrl;

  /// Tint / accent hex override (e.g. #7C3AED) for the element.
  final String? colorValue;

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
      imageUrl: json['image_url'] as String?,
      linkUrl: json['link_url'] as String?,
      colorValue: json['color_value'] as String?,
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
      imageUrl: json['image'] as String?,
      linkUrl: json['link'] as String?,
      colorValue: json['color'] as String?,
    );
  }

  String get summary {
    if (hidden) return 'Hidden';
    final parts = <String>[];
    if (text?.trim().isNotEmpty == true) parts.add(text!.trim());
    if (placeholder?.trim().isNotEmpty == true) {
      parts.add('hint: ${placeholder!.trim()}');
    }
    if (imageUrl?.trim().isNotEmpty == true) parts.add('has image');
    if (linkUrl?.trim().isNotEmpty == true) parts.add(linkUrl!.trim());
    if (colorValue?.trim().isNotEmpty == true) parts.add(colorValue!.trim());
    if (parts.isEmpty) return 'No override';
    return parts.join(' · ');
  }
}
