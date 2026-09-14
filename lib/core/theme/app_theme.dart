import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme_config.dart';

/// Centralised Material 3 theme for BookMySpace.
///
/// Supports light and dark mode with a warm, trustworthy brand palette.
class AppTheme {
  AppTheme._();

  /// Brand colours shared with the native Android BookMySpace design system.
  static const Color brand = Color(0xFF00C9A7);
  static const Color brandLight = Color(0xFF5EEAD4);
  static const Color brandDark = Color(0xFF00A084);
  static const Color action = Color(0xFF2979FF);
  static const Color accent = Color(0xFFFF6B4A);
  static const Color success = Color(0xFF22C55E);
  static const Color darkCanvas = Color(0xFF071422);
  static const Color darkCard = Color(0xFF102433);
  static const Color lightCanvas = Color(0xFFF3F7FA);
  static const Color textPrimary = Color(0xFF0B1F33);
  static const Color textSecondary = Color(0xFF475569);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color violetSoft = Color(0xFF818CF8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brand, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient offerBannerGradient = LinearGradient(
    colors: [
      Color(0xFF008F7A),
      Color(0xFF00C9A7),
      Color(0xFF38BDF8),
      Color(0xFF818CF8),
    ],
    stops: [0.0, 0.34, 0.68, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient logoGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF38BDF8), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light =>
      fromConfig(AppThemeConfig.defaults, Brightness.light);

  static ThemeData get dark =>
      fromConfig(AppThemeConfig.defaults, Brightness.dark);

  /// Builds the existing Material 3 design system from safe, server-backed
  /// tokens. Missing or malformed values are normalized by [AppThemeConfig].
  static ThemeData fromConfig(AppThemeConfig config, Brightness brightness) {
    return _base(brightness, config);
  }

  static ThemeData _base(Brightness brightness, AppThemeConfig config) {
    final isLight = brightness == Brightness.light;
    final variant = config.variantFor(brightness);
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: variant.primary,
      brightness: brightness,
    );
    final scheme = generatedScheme.copyWith(
      primary: variant.primary,
      onPrimary: _onColor(variant.primary, variant.text),
      secondary: variant.secondary,
      onSecondary: _onColor(variant.secondary, variant.text),
      tertiary: variant.secondary,
      surface: variant.background,
      surfaceContainerLowest: variant.surface,
      surfaceContainer: variant.surface,
      surfaceContainerHigh: variant.surfaceVariant,
      surfaceContainerHighest: variant.surfaceVariant,
      onSurface: variant.text,
      onSurfaceVariant: _onSurfaceVariant(variant.text, variant.background),
      outline: _withAlpha(variant.text, isLight ? 0.42 : 0.5),
      outlineVariant: _withAlpha(variant.text, isLight ? 0.18 : 0.28),
    );
    final buttonBackground = switch (config.buttonStyle) {
      'soft' => variant.primary.withValues(alpha: 0.16),
      'outline' => Colors.transparent,
      _ => variant.primary,
    };
    final buttonForeground = config.buttonStyle == 'soft'
        ? variant.primary
        : _onColor(variant.primary, variant.text);
    final buttonSide = config.buttonStyle == 'outline'
        ? BorderSide(color: variant.primary, width: 1.2)
        : BorderSide.none;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: variant.background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: variant.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: config.cardElevation,
        color: variant.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBackground,
          foregroundColor: buttonForeground,
          side: buttonSide,
          elevation: config.cardElevation,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: variant.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(config.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: variant.surfaceVariant.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.inputRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.buttonRadius),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.16 : 0.22),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: -0.1,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      extensions: [
        AppThemeExtension(
          bannerStyle: config.bannerStyle,
          cardRadius: config.cardRadius,
          glassOpacity: config.glassOpacity,
          glassBorderOpacity: config.glassBorderOpacity,
        ),
      ],
    );
  }

  static Color _onColor(Color background, Color preferred) {
    if (AppThemeVariant.contrast(preferred, background) >= 4.5) {
      return preferred;
    }
    return AppThemeVariant.contrast(Colors.white, background) >= 4.5
        ? Colors.white
        : Colors.black;
  }

  static Color _onSurfaceVariant(Color text, Color background) {
    final alpha = brightnessFor(background) == Brightness.dark ? 0.72 : 0.68;
    return _withAlpha(text, alpha);
  }

  static Brightness brightnessFor(Color color) =>
      color.computeLuminance() < 0.35 ? Brightness.dark : Brightness.light;

  static Color _withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha);
}

/// Theme data that is not represented by Material's [ColorScheme].
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.bannerStyle,
    required this.cardRadius,
    required this.glassOpacity,
    required this.glassBorderOpacity,
  });

  final String bannerStyle;
  final double cardRadius;
  final double glassOpacity;
  final double glassBorderOpacity;

  @override
  AppThemeExtension copyWith({
    String? bannerStyle,
    double? cardRadius,
    double? glassOpacity,
    double? glassBorderOpacity,
  }) {
    return AppThemeExtension(
      bannerStyle: bannerStyle ?? this.bannerStyle,
      cardRadius: cardRadius ?? this.cardRadius,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
    );
  }

  @override
  AppThemeExtension lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      bannerStyle: t < 0.5 ? bannerStyle : other.bannerStyle,
      cardRadius: _lerp(cardRadius, other.cardRadius, t),
      glassOpacity: _lerp(glassOpacity, other.glassOpacity, t),
      glassBorderOpacity: _lerp(
        glassBorderOpacity,
        other.glassBorderOpacity,
        t,
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
