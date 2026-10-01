import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared per-category accent colors, matching the palette introduced on the
/// Home screen's category cards (violet / orange / teal / blue / green).
///
/// Venue cards and detail screens use this so the same category keeps the
/// same accent color everywhere in the app, without duplicating the color
/// table in every widget.
///
/// [parentSection] is expected to be one of the `MainHomeSection.id` values
/// (`function_halls`, `lodge_rooms`, `pg_hostels`, `institutes_classes`,
/// `sports_turfs`) as stored on `VenueCategory.parentSection`. Anything else
/// (null, unrecognized) falls back to the app's brand color so this is safe
/// to call for every venue.
Color categoryAccentColor(String? parentSection) {
  switch (parentSection) {
    case 'function_halls':
      return const Color(0xFF8B5CF6); // violet
    case 'lodge_rooms':
      return const Color(0xFFF97316); // orange
    case 'pg_hostels':
      return const Color(0xFF14B8A6); // teal
    case 'institutes_classes':
      return const Color(0xFF3B82F6); // blue
    case 'sports_turfs':
      return const Color(0xFF22C55E); // green
    default:
      return AppTheme.brand;
  }
}

/// Darker variant of [categoryAccentColor], used for gradients/shadows.
Color categoryAccentColorDark(String? parentSection) {
  switch (parentSection) {
    case 'function_halls':
      return const Color(0xFF6D28D9);
    case 'lodge_rooms':
      return const Color(0xFFC2410C);
    case 'pg_hostels':
      return const Color(0xFF0F766E);
    case 'institutes_classes':
      return const Color(0xFF1D4ED8);
    case 'sports_turfs':
      return const Color(0xFF15803D);
    default:
      return AppTheme.brand;
  }
}

/// Convenience gradient built from [categoryAccentColor]/[categoryAccentColorDark].
LinearGradient categoryAccentGradient(String? parentSection) {
  return LinearGradient(
    colors: [
      categoryAccentColor(parentSection),
      categoryAccentColorDark(parentSection),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
