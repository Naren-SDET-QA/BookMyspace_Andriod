import 'package:flutter/material.dart';

/// A server-backed theme variant for one brightness mode.
@immutable
class AppThemeVariant {
  const AppThemeVariant({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.text,
    required this.card,
    required this.glassTint,
  });

  static const AppThemeVariant defaultLight = AppThemeVariant(
    primary: Color(0xFF00C9A7),
    secondary: Color(0xFF2979FF),
    background: Color(0xFFF3F7FA),
    surface: Colors.white,
    surfaceVariant: Color(0xFFE9F0F5),
    text: Color(0xFF0B1F33),
    card: Colors.white,
    glassTint: Colors.white,
  );

  static const AppThemeVariant defaultDark = AppThemeVariant(
    primary: Color(0xFF5EEAD4),
    secondary: Color(0xFF2979FF),
    background: Color(0xFF071422),
    surface: Color(0xFF102433),
    surfaceVariant: Color(0xFF1D3447),
    text: Color(0xFFF8FAFC),
    card: Color(0xFF102433),
    glassTint: Colors.white,
  );

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color card;
  final Color glassTint;

  AppThemeVariant copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? text,
    Color? card,
    Color? glassTint,
  }) {
    return AppThemeVariant(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      text: text ?? this.text,
      card: card ?? this.card,
      glassTint: glassTint ?? this.glassTint,
    );
  }

  factory AppThemeVariant.fromJson(
    Object? value, {
    required AppThemeVariant fallback,
  }) {
    final map = value is Map ? value : const <Object?, Object?>{};
    final background = _color(map['background']) ?? fallback.background;
    final text = _readableText(
      _color(map['text']) ?? fallback.text,
      background,
      fallback.text,
    );
    return AppThemeVariant(
      primary: _color(map['primary']) ?? fallback.primary,
      secondary: _color(map['secondary']) ?? fallback.secondary,
      background: background,
      surface: _color(map['surface']) ?? fallback.surface,
      surfaceVariant: _color(map['surface_variant']) ?? fallback.surfaceVariant,
      text: text,
      card: _color(map['card']) ?? fallback.card,
      glassTint: _color(map['glass_tint']) ?? fallback.glassTint,
    );
  }

  Map<String, dynamic> toJson() => {
    'primary': hexOf(primary),
    'secondary': hexOf(secondary),
    'background': hexOf(background),
    'surface': hexOf(surface),
    'surface_variant': hexOf(surfaceVariant),
    'text': hexOf(text),
    'card': hexOf(card),
    'glass_tint': hexOf(glassTint),
  };

  static Color? colorFromHex(Object? value) => _color(value);

  static String hexOf(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    final normalized = argb.toUpperCase();
    return color.a == 1.0 ? '#${normalized.substring(2)}' : '#$normalized';
  }

  static Color? _color(Object? value) {
    if (value is! String) return null;
    final source = value.trim();
    if (!RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(source)) {
      return null;
    }
    final hex = source.substring(1);
    final argb = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.parse(argb, radix: 16));
  }

  static Color _readableText(
    Color candidate,
    Color background,
    Color fallback,
  ) {
    if (_contrast(candidate, background) >= 4.5) return candidate;
    if (_contrast(fallback, background) >= 4.5) return fallback;
    return _contrast(Colors.white, background) >= 4.5
        ? Colors.white
        : Colors.black;
  }

  static double contrast(Color first, Color second) => _contrast(first, second);

  static double _contrast(Color first, Color second) {
    final a = first.computeLuminance();
    final b = second.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// The complete customer-facing theme configuration.
@immutable
class AppThemeConfig {
  const AppThemeConfig({
    required this.light,
    required this.dark,
    this.cardRadius = 16,
    this.buttonRadius = 14,
    this.inputRadius = 14,
    this.cardElevation = 0,
    this.glassOpacity = 0.72,
    this.glassBorderOpacity = 0.55,
    this.bannerStyle = 'gradient',
    this.buttonStyle = 'filled',
  });

  static const AppThemeConfig defaults = AppThemeConfig(
    light: AppThemeVariant.defaultLight,
    dark: AppThemeVariant.defaultDark,
  );

  final AppThemeVariant light;
  final AppThemeVariant dark;
  final double cardRadius;
  final double buttonRadius;
  final double inputRadius;
  final double cardElevation;
  final double glassOpacity;
  final double glassBorderOpacity;
  final String bannerStyle;
  final String buttonStyle;

  AppThemeVariant variantFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Same config with [primary] as the interactive colour in both modes.
  AppThemeConfig withPrimary(Color primary) => copyWith(
        light: light.copyWith(primary: primary),
        dark: dark.copyWith(primary: primary),
      );

  AppThemeConfig copyWith({
    AppThemeVariant? light,
    AppThemeVariant? dark,
    double? cardRadius,
    double? buttonRadius,
    double? inputRadius,
    double? cardElevation,
    double? glassOpacity,
    double? glassBorderOpacity,
    String? bannerStyle,
    String? buttonStyle,
  }) {
    return AppThemeConfig(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      cardElevation: cardElevation ?? this.cardElevation,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      bannerStyle: bannerStyle ?? this.bannerStyle,
      buttonStyle: buttonStyle ?? this.buttonStyle,
    );
  }

  factory AppThemeConfig.fromJson(Object? value) {
    final map = value is Map ? value : const <Object?, Object?>{};
    final defaults = AppThemeConfig.defaults;
    return AppThemeConfig(
      light: AppThemeVariant.fromJson(map['light'], fallback: defaults.light),
      dark: AppThemeVariant.fromJson(map['dark'], fallback: defaults.dark),
      cardRadius: _boundedNumber(
        map['card_radius'],
        defaults.cardRadius,
        0,
        32,
      ),
      buttonRadius: _boundedNumber(
        map['button_radius'],
        defaults.buttonRadius,
        0,
        32,
      ),
      inputRadius: _boundedNumber(
        map['input_radius'],
        defaults.inputRadius,
        0,
        32,
      ),
      cardElevation: _boundedNumber(
        map['card_elevation'],
        defaults.cardElevation,
        0,
        12,
      ),
      glassOpacity: _boundedNumber(
        map['glass_opacity'],
        defaults.glassOpacity,
        0,
        1,
      ),
      glassBorderOpacity: _boundedNumber(
        map['glass_border_opacity'],
        defaults.glassBorderOpacity,
        0,
        1,
      ),
      bannerStyle: _allowed(map['banner_style'], const {
        'gradient',
        'solid',
        'minimal',
      }, defaults.bannerStyle),
      buttonStyle: _allowed(map['button_style'], const {
        'filled',
        'soft',
        'outline',
      }, defaults.buttonStyle),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'light': light.toJson(),
    'dark': dark.toJson(),
    'card_radius': cardRadius,
    'button_radius': buttonRadius,
    'input_radius': inputRadius,
    'card_elevation': cardElevation,
    'glass_opacity': glassOpacity,
    'glass_border_opacity': glassBorderOpacity,
    'banner_style': bannerStyle,
    'button_style': buttonStyle,
  };

  static double _boundedNumber(
    Object? value,
    double fallback,
    double min,
    double max,
  ) {
    final number = value is num ? value.toDouble() : fallback;
    if (!number.isFinite) return fallback;
    return number.clamp(min, max).toDouble();
  }

  static String _allowed(Object? value, Set<String> allowed, String fallback) {
    return value is String && allowed.contains(value) ? value : fallback;
  }
}
