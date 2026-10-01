import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared visual tokens. Screens should prefer these over ad-hoc colors.
///
/// `primary` is the violet accent used for CTAs, active nav indicators,
/// date chips, location pills and other interactive highlights. `brand`
/// (teal) is reserved for the logo mark and success-adjacent accents.
class AppColors {
  AppColors._();

  /// Violet primary – interactive accent (buttons, active states, chips).
  static const Color primary = AppTheme.violet;

  /// Teal brand – logo / success accent, not for generic CTAs.
  static const Color brand = AppTheme.brand;
  static const Color brandLight = AppTheme.brandLight;
  static const Color brandDark = AppTheme.brandDark;
  static const Color navy = AppTheme.textPrimary;
  static const Color cyan = AppTheme.cyan;
  static const Color violet = AppTheme.violet;
  static const Color violetSoft = AppTheme.violetSoft;
  static const Color violetDeep = AppTheme.violetDeep;
  static const Color canvasLight = AppTheme.lightCanvas;
  static const Color canvasDark = AppTheme.darkCanvas;
  static const Color cardDark = AppTheme.darkCard;
  static const Color cardElevated = AppTheme.darkCardElevated;
  static const Color success = AppTheme.success;
  static const Color spotlightAmber = AppTheme.spotlightAmber;
}

class AppGradients {
  AppGradients._();

  /// Primary violet gradient – used for CTAs, location pill, Book Now.
  static const LinearGradient primary = AppTheme.violetGradient;

  /// Teal brand gradient – logo mark / success accents.
  static const LinearGradient brand = AppTheme.brandGradient;
  static const LinearGradient offer = AppTheme.offerBannerGradient;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

typedef AppRadii = AppRadius;

class AppGlassStyles {
  AppGlassStyles._();

  static BoxDecoration card({required bool dark, Color? tint}) {
    return BoxDecoration(
      color: (tint ?? Colors.white).withValues(alpha: dark ? 0.08 : 0.72),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: Colors.white.withValues(alpha: dark ? 0.08 : 0.55),
      ),
      boxShadow: AppShadows.soft(dark: dark),
    );
  }
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft({bool dark = false}) => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: dark ? 0.4 : 0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}

class AppTypography {
  AppTypography._();

  static TextStyle title(Color color) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle subtitle(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color,
      );

  static TextStyle body(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );
}

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration banner = Duration(milliseconds: 900);
  static const Curve standard = Curves.easeOutCubic;
}

class AppGlass {
  AppGlass._();

  static BoxDecoration surface({required bool dark}) => BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? 0.06 : 0.86),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.08 : 0.55),
        ),
        boxShadow: AppShadows.soft(dark: dark),
      );

  /// Dark glass surface for cards and panels on the dark canvas.
  static BoxDecoration darkCard({Color? tint}) => BoxDecoration(
        color: (tint ?? Colors.white).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: AppShadows.soft(dark: true),
      );

  /// Violet-tinted glass surface for highlighted cards.
  static BoxDecoration violetHighlight() => BoxDecoration(
        color: AppTheme.violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppTheme.violet.withValues(alpha: 0.25),
        ),
        boxShadow: AppShadows.soft(dark: true),
      );
}
