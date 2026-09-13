import 'package:flutter/material.dart';

/// Blocks an admin can enable, order and theme on the customer Home screen.
///
/// Customer Home is a *composer*: the backend config chooses which blocks
/// appear, in what order, and how each one is painted. Every field carries a
/// safe default, so a missing, partial or malformed config renders exactly
/// like the shipped design instead of throwing.
enum HomeBlockKind {
  offerBanner('offer_banner', 'Offer banner'),
  aiBooking('ai_booking', 'AI booking assistant'),
  categoryMatrix('category_matrix', 'Category 3D matrix'),
  spotlight('spotlight', 'Spotlight carousel'),
  categoryChips('category_chips', 'Listed categories'),
  /// Nearest venues by real distance from the reader's selected location.
  ///
  /// "Live" refers to the reader's current position, not to availability —
  /// this codebase holds no slot data, so the block never claims a space is
  /// free. Without a location it renders nothing.
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
    this.titles = const {},
    this.subtitles = const {},
    this.images = const [],
    this.videos = const [],
    this.style = const HomeBlockStyle(),
  });

  final HomeBlockKind kind;
  final bool enabled;
  final int order;

  /// The base title, used for every language the admin has not translated.
  final String title;
  final String subtitle;

  /// Per-language overrides keyed by language code (`en`, `te`, `hi`, `kn`,
  /// `ta`). A language the admin never filled in falls back to [title], so a
  /// single-language setup keeps working and no section ever renders blank.
  final Map<String, String> titles;
  final Map<String, String> subtitles;

  /// Admin-supplied artwork (4-6 per section). Empty means "use live data".
  final List<String> images;

  /// Admin-supplied video links for this section.
  ///
  /// These are **links, not uploads**: a clip is far larger than artwork and is
  /// usually already hosted. They open in the platform's own player, so any
  /// source the device understands works — a direct file, YouTube, or a CDN.
  final List<String> videos;

  final HomeBlockStyle style;

  /// The title to render for [languageCode].
  String titleFor(String languageCode) {
    final localized = titles[languageCode];
    if (localized != null && localized.trim().isNotEmpty) return localized;
    return title;
  }

  /// The subtitle to render for [languageCode].
  String subtitleFor(String languageCode) {
    final localized = subtitles[languageCode];
    if (localized != null && localized.trim().isNotEmpty) return localized;
    return subtitle;
  }

  HomeBlockConfig copyWith({
    bool? enabled,
    int? order,
    String? title,
    String? subtitle,
    Map<String, String>? titles,
    Map<String, String>? subtitles,
    List<String>? images,
    List<String>? videos,
    HomeBlockStyle? style,
  }) {
    return HomeBlockConfig(
      kind: kind,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      titles: titles ?? this.titles,
      subtitles: subtitles ?? this.subtitles,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      style: style ?? this.style,
    );
  }

  /// Sets one language's title, leaving every other language untouched.
  ///
  /// Clearing a language removes the override instead of storing an empty
  /// string, so the section falls back to the base title again.
  HomeBlockConfig withTitle(String languageCode, String value) {
    final next = {...titles};
    if (value.trim().isEmpty) {
      next.remove(languageCode);
    } else {
      next[languageCode] = value;
    }
    return copyWith(titles: next);
  }

  /// Sets one language's subtitle, leaving every other language untouched.
  HomeBlockConfig withSubtitle(String languageCode, String value) {
    final next = {...subtitles};
    if (value.trim().isEmpty) {
      next.remove(languageCode);
    } else {
      next[languageCode] = value;
    }
    return copyWith(subtitles: next);
  }

  factory HomeBlockConfig.fromJson(Map json, HomeBlockKind fallbackKind) {
    final kind = HomeBlockKind.fromId(json['kind']) ?? fallbackKind;
    return HomeBlockConfig(
      kind: kind,
      enabled: json['enabled'] != false,
      order: _int(json['order']) ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      titles: _localizedMap(json['titles']),
      subtitles: _localizedMap(json['subtitles']),
      images: _urlList(json['images']),
      videos: _urlList(json['videos']),
      style: HomeBlockStyle.fromJson(json['style']),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.id,
        'enabled': enabled,
        'order': order,
        if (title.isNotEmpty) 'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        if (titles.isNotEmpty) 'titles': titles,
        if (subtitles.isNotEmpty) 'subtitles': subtitles,
        if (images.isNotEmpty) 'images': images,
        if (videos.isNotEmpty) 'videos': videos,
        'style': style.toJson(),
      };

  /// Reads a list of URLs, dropping blanks so a half-typed entry can never
  /// become a broken media reference.
  static List<String> _urlList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// Reads a `{language: text}` map, dropping blanks so a cleared field can
  /// never win over the base text.
  static Map<String, String> _localizedMap(Object? value) {
    if (value is! Map) return const {};
    final out = <String, String>{};
    value.forEach((key, entry) {
      if (entry is! String) return;
      final text = entry.trim();
      if (text.isEmpty) return;
      out[key.toString()] = text;
    });
    return out;
  }
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
  ///
  /// The spotlight heading is left empty on purpose. An empty title falls back
  /// to the localized default, so the shipped Home reads correctly in every
  /// language instead of pinning English text into the config.
  static const HomeAppearance defaults = HomeAppearance([
    HomeBlockConfig(kind: HomeBlockKind.offerBanner, order: 10),
    HomeBlockConfig(kind: HomeBlockKind.aiBooking, order: 15),
    HomeBlockConfig(kind: HomeBlockKind.categoryMatrix, order: 20),
    HomeBlockConfig(kind: HomeBlockKind.spotlight, order: 30),
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
