import 'package:flutter/material.dart';

/// Blocks an admin can enable, order and theme on the customer Home screen.
///
/// Customer Home is a *composer*: the backend config chooses which blocks
/// appear, in what order, and how each one is painted. Every field carries a
/// safe default, so a missing, partial or malformed config renders exactly
/// like the shipped design instead of throwing.
enum HomeBlockKind {
  offerBanner('offer_banner', 'Offer banner'),
  categoryMatrix('category_matrix', 'Category 3D matrix'),
  spotlight('spotlight', 'Spotlight carousel'),
  categoryChips('category_chips', 'Listed categories'),
  liveRadar('live_radar', 'Live space radar'),
  recentBookings('recent_bookings', 'Recent bookings');

  const HomeBlockKind(this.id, this.label);

  final String id;
  final String label;

  static HomeBlockKind? fromId(Object? id) {
    if (id is! String) return null;
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Admin-controlled paint for a single home block.
///
/// Colours arrive as `#RRGGBB` / `#AARRGGBB` strings so the same config is
/// portable across Flutter, web and the admin console. An empty
/// [backgroundColors] list means "use the built-in brand look".
@immutable
class HomeBlockStyle {
  const HomeBlockStyle({
    this.backgroundColors = const [],
    this.borderColor,
    this.borderWidth = 0,
    this.radius = 24,
    this.glow = false,
    this.titleColor,
    this.height,
  });

  final List<Color> backgroundColors;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final bool glow;
  final Color? titleColor;
  final double? height;

  bool get hasGradient => backgroundColors.length > 1;
  Color? get solidColor => backgroundColors.length == 1
      ? backgroundColors.first
      : null;

  HomeBlockStyle copyWith({
    List<Color>? backgroundColors,
    Color? borderColor,
    double? borderWidth,
    double? radius,
    bool? glow,
    Color? titleColor,
    double? height,
  }) {
    return HomeBlockStyle(
      backgroundColors: backgroundColors ?? this.backgroundColors,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      radius: radius ?? this.radius,
      glow: glow ?? this.glow,
      titleColor: titleColor ?? this.titleColor,
      height: height ?? this.height,
    );
  }

  factory HomeBlockStyle.fromJson(Object? json) {
    if (json is! Map) return const HomeBlockStyle();
    return HomeBlockStyle(
      backgroundColors: _colorList(json['background_colors']),
      borderColor: _color(json['border_color']),
      borderWidth: _double(json['border_width']) ?? 0,
      radius: _double(json['radius']) ?? 24,
      glow: json['glow'] == true,
      titleColor: _color(json['title_color']),
      height: _double(json['height']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (backgroundColors.isNotEmpty)
          'background_colors': [
            for (final color in backgroundColors) hexOf(color),
          ],
        if (borderColor != null) 'border_color': hexOf(borderColor!),
        if (borderWidth > 0) 'border_width': borderWidth,
        'radius': radius,
        if (glow) 'glow': true,
        if (titleColor != null) 'title_color': hexOf(titleColor!),
        if (height != null) 'height': height,
      };

  /// Renders `#AARRGGBB`.
  static String hexOf(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

/// One composable block on the customer Home screen.
@immutable
class HomeBlockConfig {
  const HomeBlockConfig({
    required this.kind,
    this.enabled = true,
    this.order = 0,
    this.title = '',
    this.subtitle = '',
    this.images = const [],
    this.style = const HomeBlockStyle(),
  });

  final HomeBlockKind kind;
  final bool enabled;
  final int order;
  final String title;
  final String subtitle;

  /// Admin-supplied artwork (4-6 per section). Empty means "use live data".
  final List<String> images;
  final HomeBlockStyle style;

  HomeBlockConfig copyWith({
    bool? enabled,
    int? order,
    String? title,
    String? subtitle,
    List<String>? images,
    HomeBlockStyle? style,
  }) {
    return HomeBlockConfig(
      kind: kind,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      images: images ?? this.images,
      style: style ?? this.style,
    );
  }

  factory HomeBlockConfig.fromJson(Map json, HomeBlockKind fallbackKind) {
    final kind = HomeBlockKind.fromId(json['kind']) ?? fallbackKind;
    final rawImages = json['images'];
    return HomeBlockConfig(
      kind: kind,
      enabled: json['enabled'] != false,
      order: _int(json['order']) ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      images: rawImages is List
          ? rawImages
              .whereType<String>()
              .where((url) => url.trim().isNotEmpty)
              .toList(growable: false)
          : const [],
      style: HomeBlockStyle.fromJson(json['style']),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.id,
        'enabled': enabled,
        'order': order,
        if (title.isNotEmpty) 'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        if (images.isNotEmpty) 'images': images,
        'style': style.toJson(),
      };
}

/// The complete, ordered Home composition.
@immutable
class HomeAppearance {
  const HomeAppearance(this.blocks);

  final List<HomeBlockConfig> blocks;

  /// Blocks the customer should actually see, in admin order.
  List<HomeBlockConfig> get visible {
    final list = blocks.where((block) => block.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  HomeBlockConfig? blockFor(HomeBlockKind kind) {
    for (final block in blocks) {
      if (block.kind == kind) return block;
    }
    return null;
  }

  HomeAppearance copyWithBlock(HomeBlockConfig updated) {
    final next = <HomeBlockConfig>[];
    var replaced = false;
    for (final block in blocks) {
      if (block.kind == updated.kind) {
        next.add(updated);
        replaced = true;
      } else {
        next.add(block);
      }
    }
    if (!replaced) next.add(updated);
    return HomeAppearance(next);
  }

  /// Shipped default: identical to the current production Home.
  static const HomeAppearance defaults = HomeAppearance([
    HomeBlockConfig(kind: HomeBlockKind.offerBanner, order: 10),
    HomeBlockConfig(kind: HomeBlockKind.categoryMatrix, order: 20),
    HomeBlockConfig(
      kind: HomeBlockKind.spotlight,
      order: 30,
      title: 'Top-rated spaces',
    ),
    HomeBlockConfig(kind: HomeBlockKind.categoryChips, order: 40),
    HomeBlockConfig(kind: HomeBlockKind.recentBookings, order: 50),
  ]);

  factory HomeAppearance.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final rawBlocks = json['blocks'];
    if (rawBlocks is! List) return defaults;

    final parsed = <HomeBlockConfig>[];
    for (final entry in rawBlocks) {
      if (entry is! Map) continue;
      final kind = HomeBlockKind.fromId(entry['kind']);
      if (kind == null) continue;
      parsed.add(HomeBlockConfig.fromJson(entry, kind));
    }
    if (parsed.isEmpty) return defaults;

    // A block the admin never mentioned keeps its shipped default so that
    // adding a new block type never silently disappears from Home.
    for (final fallback in defaults.blocks) {
      if (!parsed.any((block) => block.kind == fallback.kind)) {
        parsed.add(fallback);
      }
    }
    return HomeAppearance(parsed);
  }

  Map<String, dynamic> toJson() => {
        'blocks': [for (final block in blocks) block.toJson()],
      };
}

Color? _color(Object? value) {
  if (value is! String) return null;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

List<Color> _colorList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (_color(entry) case final color?) color,
  ];
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
