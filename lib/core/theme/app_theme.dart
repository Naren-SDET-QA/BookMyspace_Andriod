import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static ThemeData get light => _base(Brightness.light);

  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      primary: isLight ? brand : brandLight,
      onPrimary: isLight ? Colors.white : darkCanvas,
      primaryContainer:
          isLight ? const Color(0xFFD7F8F1) : const Color(0xFF075E52),
      onPrimaryContainer: isLight ? darkCanvas : const Color(0xFFB9FFF1),
      secondary: action,
      onSecondary: Colors.white,
      secondaryContainer:
          isLight ? const Color(0xFFDCE9FF) : const Color(0xFF1D4F9E),
      onSecondaryContainer:
          isLight ? const Color(0xFF062E6F) : const Color(0xFFD9E6FF),
      tertiary: accent,
      surface: isLight ? lightCanvas : darkCanvas,
      onSurface: isLight ? textPrimary : const Color(0xFFF8FAFC),
      onSurfaceVariant: isLight ? textSecondary : const Color(0xFFB6C5D6),
      outline: isLight ? const Color(0xFF94A3B8) : const Color(0xFF59728A),
      outlineVariant:
          isLight ? const Color(0xFFCBD5E1) : const Color(0xFF284560),
      error: isLight ? const Color(0xFFBA1A1A) : const Color(0xFFFFB4AB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
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
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }
}
