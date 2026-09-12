class CmsBanner {
  const CmsBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.ctaText,
    this.ctaRoute,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? ctaText;
  final String? ctaRoute;
  final int sortOrder;
  final bool isActive;

  factory CmsBanner.fromJson(Map<String, dynamic> json) {
    return CmsBanner(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      ctaText: json['cta_text'] as String?,
      ctaRoute: json['cta_route'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toWriteJson() => {
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'cta_text': ctaText,
        'cta_route': ctaRoute,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}
