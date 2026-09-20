import 'package:flutter/material.dart';

import '../../venues/domain/venue.dart';
import '../../cms/domain/cms_banner.dart';

/// Resolved, VALIDATED visual style for a category card -- icon, accent,
/// gradient and badge color, each independently falling back to the
/// section's built-in theme default when the CMS value is missing or
/// malformed. This is the ONLY place that should read
/// [CmsBanner.iconName]/[CmsBanner.accentColor]/etc: consumers always call
/// [CmsCategoryStyle.resolve] rather than touching the raw CMS strings, so
/// a bad admin value (typo'd icon name, invalid hex) can never crash a
/// render -- it just silently falls back.
class CmsCategoryStyle {
  const CmsCategoryStyle({
    required this.icon,
    required this.accentColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.badgeColor,
  });

  /// Null means "use the section's built-in emoji", not "no icon" --
  /// callers should keep their existing emoji fallback when this is null.
  final IconData? icon;
  final Color accentColor;
  final Color gradientStart;
  final Color gradientEnd;
  final Color badgeColor;

  /// Curated allowlist: only these names can ever come from the CMS and
  /// resolve to a real icon. Anything else (typo, empty, unrecognized)
  /// resolves to null (== "use the emoji"), never a broken/blank icon.
  static const Map<String, IconData> iconAllowlist = {
    'celebration': Icons.celebration_rounded,
    'stadium': Icons.stadium_rounded,
    'sports': Icons.sports_rounded,
    'apartment': Icons.apartment_rounded,
    'home_work': Icons.home_work_rounded,
    'school': Icons.school_rounded,
    'menu_book': Icons.menu_book_rounded,
    'hotel': Icons.hotel_rounded,
    'bed': Icons.bed_rounded,
    'groups': Icons.groups_rounded,
  };

  /// Parses `#RRGGBB` or `#AARRGGBB` (case-insensitive, `#` optional).
  /// Anything else -- empty, wrong length, non-hex characters -- returns
  /// null so the caller's fallback color is used instead of crashing.
  static Color? tryParseHex(String? value) {
    if (value == null) return null;
    var hex = value.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static CmsCategoryStyle resolve(MainHomeSection section, CmsBanner? banner) {
    final fallbackAccent = section.accentColor;
    final validBanner = banner != null && banner.isActive;
    final accent = validBanner
        ? tryParseHex(banner.accentColor) ?? fallbackAccent
        : fallbackAccent;
    return CmsCategoryStyle(
      icon: validBanner ? iconAllowlist[banner.iconName] : null,
      accentColor: accent,
      gradientStart: validBanner
          ? tryParseHex(banner.gradientStartColor) ?? accent
          : accent,
      gradientEnd: validBanner
          ? tryParseHex(banner.gradientEndColor) ??
              fallbackAccent.withValues(alpha: 0.55)
          : fallbackAccent.withValues(alpha: 0.55),
      badgeColor:
          validBanner ? tryParseHex(banner.badgeColor) ?? accent : accent,
    );
  }
}

/// Presentation-only sub-section used by the Home discovery matrix.
///
/// [slug] is the preferred search category slug. It is not a database column.
/// Counts are never stored here — they are resolved from live [VenueCategory]
/// / venue records at render time.
class HomeSubSection {
  const HomeSubSection({
    required this.label,
    required this.emoji,
    required this.slug,
    this.aliasSlugs = const [],
  });

  final String label;
  final String emoji;
  final String slug;
  final List<String> aliasSlugs;

  /// First live category whose slug or name matches this sub-section.
  VenueCategory? match(List<VenueCategory> categories) {
    for (final cat in categories) {
      if (!cat.isActive) continue;
      final slugLower = cat.slug.toLowerCase();
      if (slugLower == slug || aliasSlugs.contains(slugLower)) return cat;
      if (cat.name.toLowerCase() == label.toLowerCase()) return cat;
    }
    return null;
  }
}

/// The five master discovery categories. IDs stay aligned with
/// `categoryAccentColor` / `VenueCategory.parentSection` comments.
enum MainHomeSection {
  functionHalls,
  sportsTurfs,
  pgHostels,
  institutesClasses,
  lodgeRooms;

  /// Carousel order requested by product: Function Halls first.
  static const List<MainHomeSection> discoveryOrder = [
    functionHalls,
    sportsTurfs,
    pgHostels,
    institutesClasses,
    lodgeRooms,
  ];

  String get id {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'function_halls';
      case MainHomeSection.sportsTurfs:
        return 'sports_turfs';
      case MainHomeSection.pgHostels:
        return 'pg_hostels';
      case MainHomeSection.institutesClasses:
        return 'institutes_classes';
      case MainHomeSection.lodgeRooms:
        return 'lodge_rooms';
    }
  }

  /// Slugs that exist (or used to exist) in deployed `venue_categories`.
  List<String> get searchAliases {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const ['function_hall', 'function_halls'];
      case MainHomeSection.sportsTurfs:
        return const ['sports_turfs', 'sports_ground', 'sports'];
      case MainHomeSection.pgHostels:
        return const ['pg_hostels', 'pg_hostel'];
      case MainHomeSection.institutesClasses:
        return const ['institutes_classes'];
      case MainHomeSection.lodgeRooms:
        return const ['lodge_rooms', 'hotel_stay'];
    }
  }

  String get title {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Function Halls';
      case MainHomeSection.sportsTurfs:
        return 'Sports';
      case MainHomeSection.pgHostels:
        return 'PG & Hostels';
      case MainHomeSection.institutesClasses:
        return 'Education';
      case MainHomeSection.lodgeRooms:
        return 'Lodges';
    }
  }

  String get displayTitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Function Halls & Celebrations';
      case MainHomeSection.sportsTurfs:
        return 'Sports & Recreation';
      case MainHomeSection.pgHostels:
        return 'PG & Hostels';
      case MainHomeSection.institutesClasses:
        return 'Education & Institutes';
      case MainHomeSection.lodgeRooms:
        return 'Lodges & Stays';
    }
  }

  String get subtitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Marriage halls, banquets, convention centers, party halls, lawns and premium celebration spaces.';
      case MainHomeSection.sportsTurfs:
        return 'Turfs, gyms, studios and recreation spaces.';
      case MainHomeSection.pgHostels:
        return 'Gents, ladies, student hostels and co-living.';
      case MainHomeSection.institutesClasses:
        return 'Coaching, tuition, IT academies, dance and music.';
      case MainHomeSection.lodgeRooms:
        return 'Hotels, lodges, hourly rooms and homestays.';
    }
  }

  String get emoji {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '🏛️';
      case MainHomeSection.sportsTurfs:
        return '🏆';
      case MainHomeSection.pgHostels:
        return '🏠';
      case MainHomeSection.institutesClasses:
        return '🎓';
      case MainHomeSection.lodgeRooms:
        return '🏨';
    }
  }

  IconData get iconData {
    switch (this) {
      case MainHomeSection.functionHalls:
        return Icons.account_balance_outlined;
      case MainHomeSection.sportsTurfs:
        return Icons.sports_soccer_outlined;
      case MainHomeSection.pgHostels:
        return Icons.home_outlined;
      case MainHomeSection.institutesClasses:
        return Icons.school_outlined;
      case MainHomeSection.lodgeRooms:
        return Icons.hotel_outlined;
    }
  }

  Color get accentColor {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const Color(0xFF8B5CF6);
      case MainHomeSection.sportsTurfs:
        return const Color(0xFF22C55E);
      case MainHomeSection.pgHostels:
        return const Color(0xFF14B8A6);
      case MainHomeSection.institutesClasses:
        return const Color(0xFF3B82F6);
      case MainHomeSection.lodgeRooms:
        return const Color(0xFFF97316);
    }
  }

  Color get accentColorDark {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const Color(0xFF6D28D9);
      case MainHomeSection.sportsTurfs:
        return const Color(0xFF15803D);
      case MainHomeSection.pgHostels:
        return const Color(0xFF0F766E);
      case MainHomeSection.institutesClasses:
        return const Color(0xFF1D4ED8);
      case MainHomeSection.lodgeRooms:
        return const Color(0xFFC2410C);
    }
  }

  /// CMS `cms_banners.slot` key an admin can use to override this
  /// section's image (see admin CMS screen). Not a fabricated 6th
  /// category set -- these map 1:1 onto the five real master sections.
  String get imageSlot {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'category_function_halls';
      case MainHomeSection.sportsTurfs:
        return 'category_sports_turfs';
      case MainHomeSection.pgHostels:
        return 'category_pg_hostels';
      case MainHomeSection.institutesClasses:
        return 'category_institutes_classes';
      case MainHomeSection.lodgeRooms:
        return 'category_lodge_rooms';
    }
  }

  /// Stock-photo placeholder used ONLY until an admin uploads a real image
  /// for [imageSlot] via the CMS. TODO(product): replace with a properly
  /// licensed/branded local asset per category -- these Unsplash URLs are
  /// a temporary bootstrap, not the intended long-term source, which is
  /// why every real render path prefers the CMS-configured slot image
  /// first (see `_resolveCategoryImage` in category_glass_matrix.dart).
  String get fallbackImageUrl {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.sportsTurfs:
        return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.pgHostels:
        return 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.institutesClasses:
        return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.lodgeRooms:
        return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=900&auto=format&fit=crop&q=80';
    }
  }

  /// Deployed parent_section values used when matching live categories.
  List<String> get parentSectionAliases {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const ['venues', 'function_halls'];
      case MainHomeSection.sportsTurfs:
        return const ['sports', 'sports_turfs', 'classes'];
      case MainHomeSection.pgHostels:
        return const ['pgs', 'pg_hostels'];
      case MainHomeSection.institutesClasses:
        return const ['classes', 'institutes_classes'];
      case MainHomeSection.lodgeRooms:
        return const ['hotels', 'lodge_rooms'];
    }
  }

  List<HomeSubSection> get subSections {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const [
          HomeSubSection(
            label: 'Marriage Halls',
            emoji: '💍',
            slug: 'marriage_hall',
            aliasSlugs: ['marriage_halls'],
          ),
          HomeSubSection(
            label: 'Banquet Halls',
            emoji: '🎉',
            slug: 'banquet_hall',
            aliasSlugs: ['banquet', 'banquet_halls'],
          ),
          HomeSubSection(
            label: 'Convention Halls',
            emoji: '🏢',
            slug: 'convention_center',
            aliasSlugs: ['convention_hall', 'convention_halls'],
          ),
          HomeSubSection(
            label: 'Party Halls & Lawns',
            emoji: '🎈',
            slug: 'party_hall',
            aliasSlugs: ['party_halls', 'party_lawn'],
          ),
          HomeSubSection(
            label: 'Engagement Halls',
            emoji: '🌸',
            slug: 'engagement_hall',
            aliasSlugs: ['engagement_halls'],
          ),
          HomeSubSection(
            label: 'Reception Halls',
            emoji: '🥂',
            slug: 'reception_hall',
            aliasSlugs: ['reception_halls'],
          ),
          HomeSubSection(
            label: 'Premium / Luxury Halls',
            emoji: '👑',
            slug: 'premium_hall',
            aliasSlugs: ['luxury_hall', 'premium_halls'],
          ),
          HomeSubSection(
            label: 'Outdoor / Garden Venues',
            emoji: '🌿',
            slug: 'outdoor_venue',
            aliasSlugs: ['garden_venue', 'outdoor_hall'],
          ),
          HomeSubSection(
            label: 'Auditoriums',
            emoji: '🎭',
            slug: 'auditorium',
          ),
          HomeSubSection(
            label: 'Community Halls',
            emoji: '🤝',
            slug: 'community_hall',
          ),
          HomeSubSection(
            label: 'Exhibition Halls',
            emoji: '🖼️',
            slug: 'exhibition_hall',
          ),
          HomeSubSection(
            label: 'Government Halls',
            emoji: '🏦',
            slug: 'govt_hall',
          ),
          HomeSubSection(
            label: 'Meeting Rooms',
            emoji: '👔',
            slug: 'meeting_room',
          ),
          HomeSubSection(
            label: 'Temples',
            emoji: '🛕',
            slug: 'temple',
          ),
        ];
      case MainHomeSection.sportsTurfs:
        return const [
          HomeSubSection(
            label: 'Box Cricket & Turf',
            emoji: '⚽',
            slug: 'sports',
            aliasSlugs: ['sports_ground', 'sports_turfs'],
          ),
          HomeSubSection(
            label: 'Gym & Fitness',
            emoji: '🏋️',
            slug: 'gym',
          ),
          HomeSubSection(
            label: 'Co-Working Desks',
            emoji: '💼',
            slug: 'coworking',
            aliasSlugs: ['coworking_space'],
          ),
          HomeSubSection(
            label: 'Photo & Film Studios',
            emoji: '📸',
            slug: 'photography_studio',
          ),
        ];
      case MainHomeSection.pgHostels:
        return const [
          HomeSubSection(
            label: 'Gents PG',
            emoji: '👨',
            slug: 'gents_pg',
          ),
          HomeSubSection(
            label: 'Ladies PG',
            emoji: '👩',
            slug: 'ladies_pg',
          ),
          HomeSubSection(
            label: 'Student Hostels',
            emoji: '🎒',
            slug: 'student_hostel',
          ),
          HomeSubSection(
            label: 'Co-Living Spaces',
            emoji: '🛋️',
            slug: 'coliving',
          ),
        ];
      case MainHomeSection.institutesClasses:
        return const [
          HomeSubSection(
            label: 'Coaching Centers',
            emoji: '📚',
            slug: 'coaching',
          ),
          HomeSubSection(
            label: 'Tuition & Test Prep',
            emoji: '✏️',
            slug: 'tuition',
          ),
          HomeSubSection(
            label: 'IT & Computer Training',
            emoji: '💻',
            slug: 'computer',
          ),
          HomeSubSection(
            label: 'Dance & Music Studios',
            emoji: '🎵',
            slug: 'dance',
            aliasSlugs: ['music'],
          ),
        ];
      case MainHomeSection.lodgeRooms:
        return const [
          HomeSubSection(
            label: 'Hotels & Suites',
            emoji: '🏨',
            slug: 'hotel',
            aliasSlugs: ['hotel_stay'],
          ),
          HomeSubSection(
            label: 'Hourly Day Rooms',
            emoji: '🧳',
            slug: 'hourly_room',
          ),
          HomeSubSection(
            label: 'Budget Lodges',
            emoji: '🛏️',
            slug: 'lodge',
          ),
          HomeSubSection(
            label: 'Resorts & Homestay',
            emoji: '🌴',
            slug: 'resort',
            aliasSlugs: ['homestay'],
          ),
          HomeSubSection(
            label: 'Guest Houses',
            emoji: '🛎️',
            slug: 'guest_house',
          ),
        ];
    }
  }

  /// 3×3 Function Halls layout: center cell is the master card (null).
  List<HomeSubSection?> get matrixCells {
    if (this != MainHomeSection.functionHalls) {
      return subSections;
    }
    final items = subSections;
    HomeSubSection bySlug(String slug) =>
        items.firstWhere((item) => item.slug == slug);
    return [
      bySlug('engagement_hall'),
      bySlug('marriage_hall'),
      bySlug('reception_hall'),
      bySlug('banquet_hall'),
      null,
      bySlug('convention_center'),
      bySlug('premium_hall'),
      bySlug('party_hall'),
      bySlug('outdoor_venue'),
    ];
  }

  VenueCategory? matchMaster(List<VenueCategory> categories) {
    for (final cat in categories) {
      if (!cat.isActive) continue;
      if (searchAliases.contains(cat.slug.toLowerCase())) return cat;
    }
    return null;
  }
}
