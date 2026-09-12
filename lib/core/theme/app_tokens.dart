import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared visual tokens. Screens should prefer these over ad-hoc colors.
class AppColors {
  AppColors._();

  static const Color primary = AppTheme.brand;
  static const Color primaryLight = AppTheme.brandLight;
  static const Color primaryDark = AppTheme.brandDark;
  static const Color navy = AppTheme.textPrimary;
  static const Color cyan = AppTheme.cyan;
  static const Color violet = AppTheme.violetSoft;
  static const Color canvasLight = AppTheme.lightCanvas;
  static const Color canvasDark = AppTheme.darkCanvas;
  static const Color cardDark = AppTheme.darkCard;
  static const Color success = AppTheme.success;
}

class AppGradients {
  AppGradients._();

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
        color: (dark ? Colors.white : Colors.white).withValues(
          alpha: dark ? 0.08 : 0.86,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.12 : 0.55),
        ),
        boxShadow: AppShadows.soft(dark: dark),
      );
}
