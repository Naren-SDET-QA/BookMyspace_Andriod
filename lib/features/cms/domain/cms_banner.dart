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
    this.slot,
    this.updatedAt,
    this.iconName,
    this.accentColor,
    this.gradientStartColor,
    this.gradientEndColor,
    this.badgeColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? ctaText;
  final String? ctaRoute;
  final int sortOrder;
  final bool isActive;

  /// When set, targets this banner at a specific home surface (e.g.
  /// 'category_function_halls') instead of the generic offer carousel.
  /// Null/empty means "generic banner", unchanged from before this field
  /// existed.
  final String? slot;

  /// Server-side last-modified time (`updated_at`). Used purely as a
  /// cache-busting key for the image URL -- when an admin republishes a
  /// new image at the SAME url, or Postgres bumps this on any edit, the
  /// rendered `<img>`/CachedNetworkImage url changes too, so browsers and
  /// the image cache can't keep serving the stale bytes.
  final DateTime? updatedAt;

  /// Raw, UNVALIDATED visual-style overrides from the CMS row. Never read
  /// these directly to render -- always go through
  /// `CmsCategoryStyle.resolve()` (home_category_catalog.dart), which
  /// validates the icon against a curated allowlist and each color as a
  /// well-formed hex string, and falls back to the section's built-in
  /// theme defaults on anything empty or malformed. That's what keeps a
  /// typo'd admin value from ever crashing the app.
  final String? iconName;
  final String? accentColor;
  final String? gradientStartColor;
  final String? gradientEndColor;
  final String? badgeColor;

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
      slot: json['slot'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      iconName: json['icon_name'] as String?,
      accentColor: json['accent_color'] as String?,
      gradientStartColor: json['gradient_start_color'] as String?,
      gradientEndColor: json['gradient_end_color'] as String?,
      badgeColor: json['badge_color'] as String?,
    );
  }

  CmsBanner copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    bool clearImageUrl = false,
    String? ctaText,
    String? ctaRoute,
    int? sortOrder,
    bool? isActive,
    String? slot,
    String? iconName,
    String? accentColor,
    String? gradientStartColor,
    String? gradientEndColor,
    String? badgeColor,
  }) {
    return CmsBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      ctaText: ctaText ?? this.ctaText,
      ctaRoute: ctaRoute ?? this.ctaRoute,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      slot: slot ?? this.slot,
      updatedAt: updatedAt,
      iconName: iconName ?? this.iconName,
      accentColor: accentColor ?? this.accentColor,
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      badgeColor: badgeColor ?? this.badgeColor,
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
        'slot': slot,
        'icon_name': iconName,
        'accent_color': accentColor,
        'gradient_start_color': gradientStartColor,
        'gradient_end_color': gradientEndColor,
        'badge_color': badgeColor,
      };
}
