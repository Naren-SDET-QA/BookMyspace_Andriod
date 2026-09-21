import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralised Material 3 theme for BookMySpace.
///
/// Supports light and dark mode with a warm, trustworthy brand palette.
class AppTheme {
  AppTheme._();

  /// Brand colours for the dark+purple BookMySpace redesign (Phase: UI
  /// match to approved reference design). `brand` stays teal and is kept
  /// for the logo mark / success-adjacent accents; `violet`/`violetDeep`
  /// are the new primary interactive colour (buttons, active states,
  /// the location pill, the "Book Now" CTAs) matching the reference.
  static const Color brand = Color(0xFF00C9A7);
  static const Color brandLight = Color(0xFF5EEAD4);
  static const Color brandDark = Color(0xFF00A084);
  static const Color action = Color(0xFF2979FF);
  static const Color accent = Color(0xFFFF6B4A);
  static const Color success = Color(0xFF22C55E);
  // Reference-matched dark canvas/card surfaces (near-black navy, not the
  // previous lighter navy-blue) and the new violet/purple primary accent.
  static const Color darkCanvas = Color(0xFF0B0E1A);
  static const Color darkCard = Color(0xFF151A2C);
  static const Color darkCardElevated = Color(0xFF1C2238);
  static const Color lightCanvas = Color(0xFFF3F7FA);
  static const Color textPrimary = Color(0xFF0B1F33);
  static const Color textSecondary = Color(0xFF475569);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color violetSoft = Color(0xFF818CF8);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDeep = Color(0xFF6D28D9);
  static const Color spotlightAmber = Color(0xFFF59E0B);

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

  /// Violet gradient for the location pill / primary CTAs in the redesign.
  static const LinearGradient violetGradient = LinearGradient(
    colors: [violetDeep, violet],
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
      // Light and dark both use violet as the interactive primary so Home
      // actions (Search, Book, selected tabs) match the customer mockup.
      primary: violet,
      onPrimary: isLight ? Colors.white : Colors.white,
      primaryContainer:
          isLight ? const Color(0xFFEDE9FE) : const Color(0xFF3E2A78),
      onPrimaryContainer: isLight ? violetDeep : const Color(0xFFE4DBFF),
      secondary: isLight ? action : cyan,
      onSecondary: isLight ? Colors.white : darkCanvas,
      secondaryContainer:
          isLight ? const Color(0xFFDCE9FF) : const Color(0xFF1D4F9E),
      onSecondaryContainer:
          isLight ? const Color(0xFF062E6F) : const Color(0xFFD9E6FF),
      tertiary: isLight ? accent : spotlightAmber,
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
          side: BorderSide(
            color: isLight
                ? scheme.outlineVariant.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
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
        height: 72,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : darkCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.12 : 0.22),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: -0.1,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }
}
