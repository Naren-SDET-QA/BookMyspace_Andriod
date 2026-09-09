import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../search/presentation/widgets/voice_search_bottom_sheet.dart';

/// Sub-section item representation with counter and highlight flag for 3D Cards
class SubSectionItem {
  const SubSectionItem({
    required this.label,
    required this.emoji,
    required this.count,
    required this.slug,
    this.isHighlight = false,
  });

  final String label;
  final String emoji;
  final int count;
  final String slug;
  final bool isHighlight;
}

/// The primary category sections of BookMySpace
enum MainHomeSection {
  functionHalls,
  lodgeRooms,
  pgHostels,
  institutesClasses,
  sportsTurfs;

  String get id {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'function_halls';
      case MainHomeSection.lodgeRooms:
        return 'lodge_rooms';
      case MainHomeSection.pgHostels:
        return 'pg_hostels';
      case MainHomeSection.institutesClasses:
        return 'institutes_classes';
      case MainHomeSection.sportsTurfs:
        return 'sports_turfs';
    }
  }

  String get title {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Function Halls';
      case MainHomeSection.lodgeRooms:
        return 'Lodge / Rooms';
      case MainHomeSection.pgHostels:
        return 'PG / Hostels';
      case MainHomeSection.institutesClasses:
        return 'Institutes / Classes';
      case MainHomeSection.sportsTurfs:
        return 'Sports / Turfs';
    }
  }

  String get displayTitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Function Halls & Celebrations';
      case MainHomeSection.lodgeRooms:
        return 'Hotels, Lodges & Rooms';
      case MainHomeSection.pgHostels:
        return 'PG Hostels & Co-Living';
      case MainHomeSection.institutesClasses:
        return 'Institutes & Academy Classes';
      case MainHomeSection.sportsTurfs:
        return 'Sports Turfs & Workspaces';
    }
  }

  String get subtitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Marriage, Convention, Party & Community Halls';
      case MainHomeSection.lodgeRooms:
        return 'Hotels, Lodges, Guest Houses & Hourly Rooms';
      case MainHomeSection.pgHostels:
        return 'Gents, Ladies, Co-Living & Student Hostels';
      case MainHomeSection.institutesClasses:
        return 'Coaching, Tuition, Dance, Music & Sports';
      case MainHomeSection.sportsTurfs:
        return 'Floodlit Box Cricket, Football Turfs, Gyms & Studios';
    }
  }

  String get displaySubtitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Grand Marriage Halls, Convention Centers, Banquets & Party Lawns';
      case MainHomeSection.lodgeRooms:
        return '24-Hour Check-in Hotels, Hourly Micro-Stays & Executive Suites';
      case MainHomeSection.pgHostels:
        return 'Verified Gents & Ladies PGs, Co-Living Suites & Student Hostels';
      case MainHomeSection.institutesClasses:
        return 'Coaching Labs, IT Academies, Tuition, Dance & Music Studios';
      case MainHomeSection.sportsTurfs:
        return 'Floodlit Box Cricket, Football Turfs, Gyms, Co-Working & Studios';
    }
  }

  String get emoji {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '🏛️';
      case MainHomeSection.lodgeRooms:
        return '🏨';
      case MainHomeSection.pgHostels:
        return '🏠';
      case MainHomeSection.institutesClasses:
        return '🎓';
      case MainHomeSection.sportsTurfs:
        return '🏆';
    }
  }

  IconData get iconData {
    switch (this) {
      case MainHomeSection.functionHalls:
        return Icons.account_balance_outlined;
      case MainHomeSection.lodgeRooms:
        return Icons.hotel_outlined;
      case MainHomeSection.pgHostels:
        return Icons.home_outlined;
      case MainHomeSection.institutesClasses:
        return Icons.school_outlined;
      case MainHomeSection.sportsTurfs:
        return Icons.emoji_events_outlined;
    }
  }

  String get popularBadge {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '# POPULAR';
      case MainHomeSection.lodgeRooms:
        return '✨ INSTANT STAY';
      case MainHomeSection.pgHostels:
        return '# ZERO BROKERAGE';
      case MainHomeSection.institutesClasses:
        return '# FREE DEMO';
      case MainHomeSection.sportsTurfs:
        return '# FLOODLIT & 24/7';
    }
  }

  int get defaultCount {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 4;
      case MainHomeSection.lodgeRooms:
        return 2;
      case MainHomeSection.pgHostels:
        return 1;
      case MainHomeSection.institutesClasses:
        return 2;
      case MainHomeSection.sportsTurfs:
        return 3;
    }
  }

  String get highlightBadge {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '⚡ 10-Min Royal Hold';
      case MainHomeSection.lodgeRooms:
        return '⏱️ Flexible Hourly Slots';
      case MainHomeSection.pgHostels:
        return '🛡️ Verified Biometric Security';
      case MainHomeSection.institutesClasses:
        return '🎓 Certified Master Instructors';
      case MainHomeSection.sportsTurfs:
        return '⚡ Instant Slot Booking';
    }
  }

  String get startsFromPrice {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '₹25,000/day';
      case MainHomeSection.lodgeRooms:
        return '₹499/hr';
      case MainHomeSection.pgHostels:
        return '₹4,500/mo';
      case MainHomeSection.institutesClasses:
        return '₹1,200/mo';
      case MainHomeSection.sportsTurfs:
        return '₹600/hr';
    }
  }

  List<SubSectionItem> get subSections {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const [
          SubSectionItem(label: 'Marriage Halls', emoji: '💍', count: 2, slug: 'marriage_hall'),
          SubSectionItem(label: 'Banquet Halls', emoji: '💐', count: 1, slug: 'banquet_hall'),
          SubSectionItem(label: 'Convention Halls', emoji: '🏢', count: 1, slug: 'convention_center'),
          SubSectionItem(label: 'Party Halls & Lawns', emoji: '🎈', count: 2, slug: 'party_hall'),
          SubSectionItem(label: 'Other Halls & Spaces', emoji: '✨', count: 4, slug: 'other_hall', isHighlight: true),
        ];
      case MainHomeSection.lodgeRooms:
        return const [
          SubSectionItem(label: 'Hotels & Suites', emoji: '🏨', count: 1, slug: 'hotel'),
          SubSectionItem(label: 'Hourly Day Rooms', emoji: '🧳', count: 1, slug: 'hourly_room'),
          SubSectionItem(label: 'Budget Lodges', emoji: '🛏️', count: 2, slug: 'lodge'),
          SubSectionItem(label: 'Resorts & Homestay', emoji: '🌴', count: 1, slug: 'resort'),
          SubSectionItem(label: 'Other Stays & Homestays', emoji: '✨', count: 2, slug: 'other_stay', isHighlight: true),
        ];
      case MainHomeSection.pgHostels:
        return const [
          SubSectionItem(label: 'Gents PG', emoji: '👨', count: 1, slug: 'gents_pg'),
          SubSectionItem(label: 'Ladies PG', emoji: '👩', count: 1, slug: 'ladies_pg'),
          SubSectionItem(label: 'Student Hostels', emoji: '🎒', count: 1, slug: 'student_hostel'),
          SubSectionItem(label: 'Co-Living Spaces', emoji: '🛋️', count: 1, slug: 'coliving'),
          SubSectionItem(label: 'Other Hostels & Pods', emoji: '✨', count: 1, slug: 'other_pg', isHighlight: true),
        ];
      case MainHomeSection.institutesClasses:
        return const [
          SubSectionItem(label: 'Coaching Centers', emoji: '📚', count: 1, slug: 'coaching'),
          SubSectionItem(label: 'Tuition & Test Prep', emoji: '✏️', count: 1, slug: 'tuition'),
          SubSectionItem(label: 'IT & Computer Training', emoji: '💻', count: 1, slug: 'computer'),
          SubSectionItem(label: 'Dance & Music Studios', emoji: '🎵', count: 1, slug: 'dance'),
        ];
      case MainHomeSection.sportsTurfs:
        return const [
          SubSectionItem(label: 'Box Cricket & Turf', emoji: '⚽', count: 1, slug: 'sports'),
          SubSectionItem(label: 'Gym & Fitness', emoji: '🏋️', count: 1, slug: 'gym'),
          SubSectionItem(label: 'Co-Working Desks', emoji: '💼', count: 1, slug: 'coworking'),
          SubSectionItem(label: 'Photo & Film Studios', emoji: '📸', count: 2, slug: 'photography_studio'),
          SubSectionItem(label: 'Other Turfs & Desks', emoji: '✨', count: 3, slug: 'other', isHighlight: true),
        ];
    }
  }

  String get imageUrl {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.lodgeRooms:
        return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.pgHostels:
        return 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.institutesClasses:
        return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.sportsTurfs:
        return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=900&auto=format&fit=crop&q=80';
    }
  }

  List<SubCategoryOption> get categoryOptions {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const [
          SubCategoryOption('all', 'All Halls', '🏛️'),
          SubCategoryOption('marriage_hall', 'Marriage Hall', '💍'),
          SubCategoryOption('convention_center', 'Convention Hall', '🏢'),
          SubCategoryOption('party_hall', 'Party Hall', '🎉'),
          SubCategoryOption('community_hall', 'Community Hall', '👥'),
          SubCategoryOption('govt_hall', 'Govt Hall', '🏛️'),
          SubCategoryOption('auditorium', 'Auditorium', '🎭'),
        ];
      case MainHomeSection.lodgeRooms:
        return const [
          SubCategoryOption('all', 'All Rooms', '🏨'),
          SubCategoryOption('hotel', 'Hotel', '🛎️'),
          SubCategoryOption('lodge', 'Lodge', '🛏️'),
          SubCategoryOption('guest_house', 'Guest House', '🏡'),
          SubCategoryOption('homestay', 'Homestay', '🌿'),
          SubCategoryOption('resort', 'Resort', '🌴'),
          SubCategoryOption('hourly_room', 'Hourly Room', '⏱️'),
        ];
      case MainHomeSection.pgHostels:
        return const [
          SubCategoryOption('all', 'All PGs', '🏠'),
          SubCategoryOption('gents_pg', 'Gents PG', '👨'),
          SubCategoryOption('ladies_pg', 'Ladies PG', '👩'),
          SubCategoryOption('student_hostel', 'Student Hostel', '🎒'),
          SubCategoryOption('coliving', 'Co-Living', '🛋️'),
          SubCategoryOption('working_men', 'Working Men', '💼'),
          SubCategoryOption('working_women', 'Working Women', '👩‍💼'),
        ];
      case MainHomeSection.institutesClasses:
        return const [
          SubCategoryOption('all', 'All Classes', '🎓'),
          SubCategoryOption('coaching', 'Coaching', '📚'),
          SubCategoryOption('tuition', 'Tuition', '✏️'),
          SubCategoryOption('computer', 'Computer / IT', '💻'),
          SubCategoryOption('dance', 'Dance Academy', '💃'),
          SubCategoryOption('music', 'Music School', '🎵'),
          SubCategoryOption('sports', 'Sports & Gym', '⚽'),
        ];
      case MainHomeSection.sportsTurfs:
        return const [
          SubCategoryOption('all', 'All Turfs & Desks', '🏆'),
          SubCategoryOption('sports', 'Box Cricket & Turf', '⚽'),
          SubCategoryOption('gym', 'Gym & Fitness', '🏋️'),
          SubCategoryOption('coworking', 'Co-Working Desks', '💼'),
          SubCategoryOption('photography_studio', 'Photo & Film Studios', '📸'),
          SubCategoryOption('other', 'Other Turfs & Desks', '✨'),
        ];
    }
  }
}

class SubCategoryOption {
  const SubCategoryOption(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

class AmenityFilter {
  const AmenityFilter(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

const _homeAmenities = [
  AmenityFilter('wifi', 'WiFi', '📶'),
  AmenityFilter('ac', 'Air Conditioned', '❄️'),
  AmenityFilter('parking', 'Parking', '🚗'),
  AmenityFilter('food', 'Food / Catering', '🍽️'),
  AmenityFilter('generator', 'Power Backup', '⚡'),
  AmenityFilter('cctv', 'CCTV Security', '📹'),
  AmenityFilter('lift', 'Elevator', '🛗'),
];

/// Redesigned BookMySpace customer Home Screen:
/// - First Screen: ONLY 4 Main Sections in a fast, responsive, attractive layout
/// - Section Drill-Down: Category Index -> Location -> Search & Voice Booking -> Results -> Direct Booking/Call/WhatsApp
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MainHomeSection? _selectedSection;
  String _selectedCategorySlug = 'all';
  String _currentLocation = 'Hyderabad (Madhapur)';
  String _searchRadius = 'Within 10 km';
  final Set<String> _selectedAmenities = {};
  String _searchQuery = '';

  List<SubCategoryOption> _resolveSectionCategories(
    MainHomeSection section,
    List<VenueCategory> dynamicCats,
  ) {
    final list = <SubCategoryOption>[...section.categoryOptions];
    for (final cat in dynamicCats) {
      if (!cat.isActive) continue;
      final exists = list.any((c) => c.id.toLowerCase() == cat.slug.toLowerCase());
      if (!exists) {
        final parent = cat.parentSection?.toLowerCase() ?? 'general';
        final matches = parent == 'general' ||
            (parent == 'venues' && section == MainHomeSection.functionHalls) ||
            (parent == 'hotels' && section == MainHomeSection.lodgeRooms) ||
            (parent == 'pgs' && section == MainHomeSection.pgHostels) ||
            (parent == 'classes' && section == MainHomeSection.institutesClasses) ||
            (parent == 'sports' && section == MainHomeSection.sportsTurfs);
        if (matches) {
          list.add(SubCategoryOption(
            cat.slug,
            cat.name,
            cat.icon?.isNotEmpty == true ? cat.icon! : '🏷️',
          ));
        }
      }
    }
    return list;
  }

  void _showAddSubSectionDialog(BuildContext context, MainHomeSection section) {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '✨');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(section.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add Sub-Section to ${section.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a new custom sub-section for immediate 1-click filtering:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Sub-Section Name',
                hintText: 'e.g. Banquet Hall, Film Studio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji Icon',
                hintText: 'e.g. 📸, 🌟, 🎪',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                final emoji = emojiCtrl.text.trim().isNotEmpty ? emojiCtrl.text.trim() : '✨';
                ref.read(venueRepositoryProvider).addCategory(
                  VenueCategory(
                    id: slug,
                    name: name,
                    slug: slug,
                    icon: emoji,
                    parentSection: section.id,
                  ),
                );
                ref.invalidate(venueCategoriesProvider);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "$name" to ${section.title}!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Add Sub-Section'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final popularVenuesAsync = ref.watch(popularVenuesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(popularVenuesProvider);
                ref.invalidate(nearbyVenuesProvider);
                ref.invalidate(venueCategoriesProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Top App Bar
                  SliverToBoxAdapter(
                    child: _TopHeaderBar(
                      user: user,
                      responsive: responsive,
                      onLoginTap: () => context.push(AppRoutes.login),
                      onProfileTap: () => context.push(AppRoutes.profile),
                      onNotificationsTap: () => context.push(AppRoutes.notifications),
                    ),
                  ),

                  // =========================================================
                  // 🌟 FIRST SCREEN: 3D CATEGORY SECTIONS (iOS, Android & Web)
                  // =========================================================
                  if (_selectedSection == null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore Spaces by Category',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select a category with 1-click sub-section filters to find your ideal space:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // 3D Responsive Grid for Main Category Sections
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.horizontalPadding,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 440,
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 22,
                          mainAxisExtent: 475,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final section = MainHomeSection.values[index];
                            final dynamicCats = (ref.watch(venueCategoriesProvider).value ?? const []);
                            final cityName = _currentLocation.split('(').first.trim();
                            return _ThreeDimensionalCategoryHeroCard(
                              section: section,
                              cityName: cityName.isNotEmpty ? cityName : 'Hyderabad',
                              dynamicCats: dynamicCats,
                              onTapExplore: () {
                                setState(() {
                                  _selectedSection = section;
                                  _selectedCategorySlug = 'all';
                                });
                              },
                              onSubSectionTap: (slug) {
                                setState(() {
                                  _selectedSection = section;
                                  _selectedCategorySlug = slug;
                                });
                                context.push('${AppRoutes.search}?category=$slug');
                              },
                              onAddSubSectionTap: () {
                                _showAddSubSectionDialog(context, section);
                              },
                            );
                          },
                          childCount: MainHomeSection.values.length,
                        ),
                      ),
                    ),

                    // Dynamic Categories Horizontal Strip
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trending Categories',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: (ref.watch(venueCategoriesProvider).value ?? const [])
                                    .where((c) => c.isActive && c.slug != 'all')
                                    .length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cats = (ref.watch(venueCategoriesProvider).value ?? const [])
                                      .where((c) => c.isActive && c.slug != 'all')
                                      .toList();
                                  final cat = cats[index];
                                  return AnimatedCategoryChip(
                                    selected: false,
                                    label: cat.name,
                                    emoji: cat.icon?.isNotEmpty == true ? cat.icon! : '🏷️',
                                    onTap: () {
                                      context.push('${AppRoutes.search}?category=${cat.slug}');
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Location bar at bottom of first screen
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 24,
                        ),
                        child: _LocationFooterCard(
                          currentLocation: _currentLocation,
                          searchRadius: _searchRadius,
                          onTap: _showLocationPickerModal,
                        ),
                      ),
                    ),
                  ]

                  // =========================================================
                  // 🚀 SECTION DRILL-DOWN: Category Index -> Location -> Results
                  // =========================================================
                  else ...[
                    // Section Back & Title Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSection = null;
                                      _selectedCategorySlug = 'all';
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(120, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  label: const Text(
                                    'All Spaces',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_selectedSection!.emoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedSection!.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_selectedSection!.emoji} ${_selectedSection!.title}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _selectedSection!.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Location selector
                            _LocationSelectorBar(
                              location: _currentLocation,
                              radius: _searchRadius,
                              onTap: _showLocationPickerModal,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 1. Relevant Index / Categories (Horizontal Row)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.horizontalPadding,
                              vertical: 4,
                            ),
                            child: Text(
                              'Choose Category',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final dynamicCats = ref.watch(venueCategoriesProvider).value ?? const [];
                              final options = _resolveSectionCategories(_selectedSection!, dynamicCats);
                              return SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsive.horizontalPadding,
                                  ),
                                  itemCount: options.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final cat = options[index];
                                    final isSelected = _selectedCategorySlug == cat.id;
                                    return AnimatedCategoryChip(
                                      selected: isSelected,
                                      label: cat.label,
                                      emoji: cat.emoji,
                                      onTap: () {
                                        setState(() {
                                          _selectedCategorySlug = cat.id;
                                        });
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 2. Search & Voice Booking & Quick Book Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            // Search Bar
                            InkWell(
                              onTap: () {
                                context.push(
                                  AppRoutes.search,
                                  extra: {
                                    'category': _selectedCategorySlug == 'all'
                                        ? _selectedSection!.id
                                        : _selectedCategorySlug,
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Search ${_selectedSection!.title} in $_currentLocation...',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.tune_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Voice Booking Banner
                            _VoiceBookingBanner(
                              onTap: () => _showVoiceBookingDialog(context),
                            ),
                            const SizedBox(height: 10),

                            // 1-Tap Quick Book Card
                            _QuickBookCard(
                              sectionTitle: _selectedSection!.title,
                              onQuickBookTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Finding fastest verified ${_selectedSection!.title}...'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Amenity Filter Chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Filter by Amenities',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_selectedAmenities.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAmenities.clear();
                                      });
                                    },
                                    child: const Text('Clear Filters'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _homeAmenities.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final amenity = _homeAmenities[index];
                                  final isSelected = _selectedAmenities.contains(amenity.id);
                                  return AnimatedCategoryChip(
                                    selected: isSelected,
                                    label: amenity.label,
                                    emoji: amenity.emoji,
                                    height: 34,
                                    selectedColor: theme.colorScheme.primaryContainer,
                                    selectedTextColor: theme.colorScheme.onPrimaryContainer,
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedAmenities.remove(amenity.id);
                                        } else {
                                          _selectedAmenities.add(amenity.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Available Spaces',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // 4. Venues List / Grid in Responsive Layout
                    popularVenuesAsync.when(
                      data: (venues) {
                        if (venues.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No spaces found',
                                message: 'Try changing category or location filters.',
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: responsive.resultsColumns,
                              mainAxisSpacing: responsive.gridSpacing,
                              crossAxisSpacing: responsive.gridSpacing,
                              childAspectRatio: responsive.resultsAspectRatio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final venue = venues[index % venues.length];
                                return _SectionVenueCard(
                                  venue: venue,
                                  onTap: () => context.push(
                                    AppRoutes.venueDetails.replaceAll(':id', venue.id),
                                  ),
                                  onBookTap: () => context.push(
                                    AppRoutes.bookingFlow.replaceAll(':id', venue.id),
                                  ),
                                  onCallTap: () => _handleCall(context, venue),
                                  onWhatsAppTap: () => _handleWhatsApp(context, venue),
                                );
                              },
                              childCount: venues.length,
                            ),
                          ),
                        );
                      },
                      loading: () => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(responsive.horizontalPadding),
                          child: const Row(
                            children: [
                              Expanded(child: SkeletonBox(height: 220, radius: 16)),
                              SizedBox(width: 12),
                              Expanded(child: SkeletonBox(height: 220, radius: 16)),
                            ],
                          ),
                        ),
                      ),
                      error: (err, _) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorView(
                            message: err.toString(),
                            onRetry: () => ref.invalidate(popularVenuesProvider),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 48),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLocationPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final cities = [
          'Hyderabad (Madhapur / Hitec City)',
          'Hyderabad (Gachibowli)',
          'Hyderabad (Kukatpally)',
          'Hyderabad (Secunderabad)',
          'Bengaluru (Koramangala)',
          'Bengaluru (Whitefield)',
          'Mumbai (Andheri)',
          'Delhi NCR (Cyber Hub)',
        ];
        final radii = ['Within 5 km', 'Within 10 km', 'Within 25 km', 'Entire City'];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Location & Search Area',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Search Radius:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: radii.map((r) {
                    final isSelected = _searchRadius == r;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(r),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _searchRadius = r);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Popular Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...cities.map((city) {
                  final isSelected = _currentLocation.contains(city.split(' ')[0]);
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(city),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.brand) : null,
                    onTap: () {
                      setState(() => _currentLocation = city);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceBookingDialog(BuildContext context) {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (voiceResult) {
        final newQuery = voiceResult.toVenueSearchQuery();
        ref.read(searchQueryProvider.notifier).state = newQuery;
        context.push(AppRoutes.search);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎙️ '),
                Expanded(
                  child: Text(
                    voiceResult.spokenFeedback.isNotEmpty
                        ? voiceResult.spokenFeedback
                        : 'Voice search filter applied!',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onFallbackToText: () {
        context.push(AppRoutes.search);
      },
    );
  }

  void _handleCall(BuildContext context, Venue venue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${venue.name} contact desk...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleWhatsApp(BuildContext context, Venue venue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening WhatsApp chat with ${venue.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Header Bar with Logo and Profile Actions
class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.user,
    required this.responsive,
    required this.onLoginTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final dynamic user;
  final ResponsiveInfo responsive;
  final VoidCallback onLoginTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brand, Color(0xFF757DE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.domain_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'BookMySpace',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppTheme.brand,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (user == null)
                FilledButton.tonalIcon(
                  onPressed: onLoginTap,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(80, 40),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              else
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      user?.email?.isNotEmpty == true ? user.email[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => context.push(AppRoutes.map),
                tooltip: 'Live Map Discovery',
                icon: const Icon(Icons.map_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => context.push(AppRoutes.qrScanner),
                tooltip: 'QR Check-In',
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onNotificationsTap,
                icon: const Icon(Icons.notifications_none_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modern 3D Tactile Category Hero Card with Web Hover Perspective, iOS/Android Haptic Scaling,
/// Active Green Live Status Indicator, 1-Click Sub-Section Filters & High-Precision 3D Shadows.
class _ThreeDimensionalCategoryHeroCard extends StatefulWidget {
  const _ThreeDimensionalCategoryHeroCard({
    required this.section,
    required this.cityName,
    required this.dynamicCats,
    required this.onTapExplore,
    required this.onSubSectionTap,
    required this.onAddSubSectionTap,
  });

  final MainHomeSection section;
  final String cityName;
  final List<VenueCategory> dynamicCats;
  final VoidCallback onTapExplore;
  final ValueChanged<String> onSubSectionTap;
  final VoidCallback onAddSubSectionTap;

  @override
  State<_ThreeDimensionalCategoryHeroCard> createState() =>
      _ThreeDimensionalCategoryHeroCardState();
}

class _ThreeDimensionalCategoryHeroCardState
    extends State<_ThreeDimensionalCategoryHeroCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  List<SubSectionItem> _resolveSubSections() {
    final list = <SubSectionItem>[...widget.section.subSections];
    for (final cat in widget.dynamicCats) {
      if (!cat.isActive) continue;
      final exists = list.any((s) => s.slug.toLowerCase() == cat.slug.toLowerCase());
      if (!exists) {
        final parent = cat.parentSection?.toLowerCase() ?? 'general';
        final matches = (parent == 'general' && widget.section == MainHomeSection.functionHalls) ||
            (parent == 'venues' && widget.section == MainHomeSection.functionHalls) ||
            (parent == 'hotels' && widget.section == MainHomeSection.lodgeRooms) ||
            (parent == 'pgs' && widget.section == MainHomeSection.pgHostels) ||
            (parent == 'classes' && widget.section == MainHomeSection.institutesClasses) ||
            (parent == 'sports' && widget.section == MainHomeSection.sportsTurfs);
        if (matches) {
          list.add(SubSectionItem(
            label: cat.name,
            emoji: cat.icon?.isNotEmpty == true ? cat.icon! : '✨',
            count: 1,
            slug: cat.slug,
            isHighlight: true,
          ));
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final subSections = _resolveSubSections();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTapExplore();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(_isHovered ? -0.065 : (_isPressed ? 0.02 : 0.0))
            ..rotateY(_isHovered ? 0.038 : 0.0)
            ..translate(
              0.0,
              _isPressed
                  ? 3.0
                  : (_isHovered ? -10.0 : 0.0),
              0.0,
            )
            ..scale(_isPressed ? 0.982 : (_isHovered ? 1.02 : 1.0)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF6366F1).withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
              width: _isHovered ? 2.0 : 1.5,
            ),
            boxShadow: [
              // Dynamic, elevated drop-shadows that deepen during interaction
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(
                  alpha: _isPressed
                      ? 0.06
                      : (_isHovered ? 0.24 : 0.09),
                ),
                blurRadius: _isHovered ? 36 : (_isPressed ? 8 : 18),
                offset: Offset(0, _isHovered ? 18 : (_isPressed ? 3 : 8)),
                spreadRadius: _isHovered ? 2.5 : 0,
              ),
              // Radiant indigo ambient rim reflection
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(
                  alpha: _isHovered ? 0.25 : 0.05,
                ),
                blurRadius: _isHovered ? 28 : 16,
                offset: Offset(0, _isHovered ? 8 : 3),
              ),
              // Tactile 3D bottom bevel edge
              BoxShadow(
                color: const Color(0xFF000000).withValues(
                  alpha: _isHovered ? 0.08 : 0.04,
                ),
                blurRadius: 2,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: Stack(
              children: [
                // Subtle architectural background watermark image
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.045,
                    child: Image.network(
                      section.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Pronounced Light-Source Effect: Border-based highlight on top edges
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          const Color(0xFFE0E7FF),
                          Colors.white.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Card Foreground Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Icon Container with Green Live Dot + Badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Container + Live Status Dot
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFC7D2FE),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  section.iconData,
                                  color: const Color(0xFF4F46E5),
                                  size: 24,
                                ),
                              ),
                              // Live active dot (bottom-right of icon box)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Top-right Badges
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFC7D2FE).withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Text(
                                  section.popularBadge,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4338CA),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${section.defaultCount} Spaces in ${widget.cityName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        section.displayTitle,
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 5),

                      // Subtitle
                      SizedBox(
                        height: 34,
                        child: Text(
                          section.displaySubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Highlight tag pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          section.highlightBadge,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // SUB-SECTIONS INCLUDED row
                      Row(
                        children: [
                          const Icon(
                            Icons.layers_rounded,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'SUB-SECTIONS INCLUDED:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Text(
                              '1-CLICK FILTER',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Sub-sections Chip Wrap
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ...subSections.map((sub) {
                            return InkWell(
                              onTap: () => widget.onSubSectionTap(sub.slug),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: sub.isHighlight
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: sub.isHighlight
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      sub.emoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sub.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: sub.isHighlight
                                            ? const Color(0xFF92400E)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sub.isHighlight
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${sub.count}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: sub.isHighlight
                                              ? const Color(0xFF78350F)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // + + Sub-Section chip
                          InkWell(
                            onTap: widget.onAddSubSectionTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    '+ Sub-Section',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom Row: Starts From Price + Explore Spaces Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STARTS FROM',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                section.startsFromPrice,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Explore Spaces Pill Button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                if (_isHovered)
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Explore Spaces',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.translate(
                                  offset: Offset(_isHovered ? 2.5 : 0.0, 0),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Location Footer Card at the bottom of the first screen
class _LocationFooterCard extends StatelessWidget {
  const _LocationFooterCard({
    required this.currentLocation,
    required this.searchRadius,
    required this.onTap,
  });

  final String currentLocation;
  final String searchRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Text('📍', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current City: $currentLocation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Tap to change search area ($searchRadius)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_location_alt_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Location Selector Bar inside Section Drill-Down
class _LocationSelectorBar extends StatelessWidget {
  const _LocationSelectorBar({
    required this.location,
    required this.radius,
    required this.onTap,
  });

  final String location;
  final String radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$location • $radius',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice Booking Banner
class _VoiceBookingBanner extends StatelessWidget {
  const _VoiceBookingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF283593), Color(0xFF3F51B5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brand.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎙️ Bol-ke-Book (Voice Search)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Tap to speak and book in Telugu, Hindi or English',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Quick 1-Tap Booking Card
class _QuickBookCard extends StatelessWidget {
  const _QuickBookCard({
    required this.sectionTitle,
    required this.onQuickBookTap,
  });

  final String sectionTitle;
  final VoidCallback onQuickBookTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('⚡', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1-Tap Fast Booking',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Instant confirmation for top-rated $sectionTitle',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onQuickBookTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(70, 36),
            ),
            child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Venue / Space Result Card with Direct Book, Call, and WhatsApp Buttons
class _SectionVenueCard extends StatelessWidget {
  const _SectionVenueCard({
    required this.venue,
    required this.onTap,
    required this.onBookTap,
    required this.onCallTap,
    required this.onWhatsAppTap,
  });

  final Venue venue;
  final VoidCallback onTap;
  final VoidCallback onBookTap;
  final VoidCallback onCallTap;
  final VoidCallback onWhatsAppTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassmorphicCard(
      borderRadius: 18,
      onTap: onTap,
      accentGradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFFFF7043)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Venue Cover Image & Badges
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
                  if (venue.avgRating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RatingBadge(
                          rating: venue.avgRating,
                          count: venue.ratingCount,
                        ),
                      ),
                    ),
                  if (venue.distanceKm != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              formatDistance(venue.distanceKm),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Venue Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.addressLine1.isNotEmpty ? venue.addressLine1 : venue.city}, ${venue.city}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Pricing & Capacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${venue.pricingBaseAmount.toInt()}/day',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      if (venue.capacity > 0)
                        Text(
                          '👥 ${venue.capacity} Guests',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons: Book Now, Call, WhatsApp
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: onBookTap,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Book Now',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        onPressed: onCallTap,
                        style: IconButton.outlinedFrom(
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: onWhatsAppTap,
                        style: IconButton.filledTonalFrom(
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Text('💬', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
