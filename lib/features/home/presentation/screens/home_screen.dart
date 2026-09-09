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
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 195,
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

class _CategoryPalette {
  final Color primary;
  final Color secondary;
  final List<Color> gradient;
  final List<Color> surfaceGradient;
  final List<Color> borderGradient;
  final Color glowColor;
  final Color badgeBg;
  final Color badgeText;

  const _CategoryPalette({
    required this.primary,
    required this.secondary,
    required this.gradient,
    required this.surfaceGradient,
    required this.borderGradient,
    required this.glowColor,
    required this.badgeBg,
    required this.badgeText,
  });
}

_CategoryPalette _getCategoryPalette(MainHomeSection section) {
  switch (section) {
    case MainHomeSection.functionHalls:
      return const _CategoryPalette(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF9333EA),
        gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
        surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
        borderGradient: [Color(0xFF818CF8), Color(0xFFC084FC)],
        glowColor: Color(0xFF8B5CF6),
        badgeBg: Color(0xFFEEF2FF),
        badgeText: Color(0xFF4338CA),
      );
    case MainHomeSection.lodgeRooms:
      return const _CategoryPalette(
        primary: Color(0xFFF59E0B),
        secondary: Color(0xFFEF4444),
        gradient: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444)],
        surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFFFFBEB)],
        borderGradient: [Color(0xFFFBBF24), Color(0xFFFB7185)],
        glowColor: Color(0xFFF97316),
        badgeBg: Color(0xFFFEF3C7),
        badgeText: Color(0xFFB45309),
      );
    case MainHomeSection.pgHostels:
      return const _CategoryPalette(
        primary: Color(0xFF10B981),
        secondary: Color(0xFF06B6D4),
        gradient: [Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF06B6D4)],
        surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFECFDF5)],
        borderGradient: [Color(0xFF34D399), Color(0xFF22D3EE)],
        glowColor: Color(0xFF10B981),
        badgeBg: Color(0xFFD1FAE5),
        badgeText: Color(0xFF047857),
      );
    case MainHomeSection.institutesClasses:
      return const _CategoryPalette(
        primary: Color(0xFF0EA5E9),
        secondary: Color(0xFF3B82F6),
        gradient: [Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFF3B82F6)],
        surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
        borderGradient: [Color(0xFF38BDF8), Color(0xFF60A5FA)],
        glowColor: Color(0xFF0284C7),
        badgeBg: Color(0xFFE0F2FE),
        badgeText: Color(0xFF0369A1),
      );
    case MainHomeSection.sportsTurfs:
      return const _CategoryPalette(
        primary: Color(0xFF84CC16),
        secondary: Color(0xFF10B981),
        gradient: [Color(0xFF84CC16), Color(0xFF22C55E), Color(0xFF10B981)],
        surfaceGradient: [Color(0xFFFFFFFF), Color(0xFFF7FEE7)],
        borderGradient: [Color(0xFFA3E635), Color(0xFF34D399)],
        glowColor: Color(0xFF84CC16),
        badgeBg: Color(0xFFECFCCB),
        badgeText: Color(0xFF3F6212),
      );
  }
}

/// Compact World-Class 3D Glass Category Card with Dynamic Category Colors,
/// 3D Perspective Tilt, Ambient Glow, Specular Highlights & 1-Tap Quick Filters.
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
    final palette = _getCategoryPalette(section);
    final subSections = _resolveSubSections();
    final topSubSections = subSections.take(2).toList();

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(_isHovered ? -0.05 : (_isPressed ? 0.015 : 0.0))
            ..rotateY(_isHovered ? 0.03 : 0.0)
            ..translate(
              0.0,
              _isPressed
                  ? 2.0
                  : (_isHovered ? -5.0 : 0.0),
              0.0,
            )
            ..scale(_isPressed ? 0.965 : (_isHovered ? 1.025 : 1.0)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: palette.surfaceGradient,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? palette.primary
                  : palette.borderGradient.first.withValues(alpha: 0.45),
              width: _isHovered ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.glowColor.withValues(
                  alpha: _isHovered ? 0.28 : 0.08,
                ),
                blurRadius: _isHovered ? 18 : 6,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(
                  alpha: _isPressed ? 0.04 : 0.06,
                ),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                // Top Specular Highlight edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          palette.primary.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),

                // Radial ambient glow orb
                Positioned(
                  top: -20,
                  right: -20,
                  width: 80,
                  height: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.glowColor.withValues(alpha: _isHovered ? 0.22 : 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Card Foreground Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: 3D Icon Orb + Emerald Live Dot + Space Count Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 3D Glass Icon Orb
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: palette.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.glowColor.withValues(alpha: 0.35),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  section.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              // Live active dot
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Count Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.badgeBg.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: palette.primary.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${section.defaultCount} in ${widget.cityName}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: palette.badgeText,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Title & Starts From Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.displayTitle,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Starts ${section.startsFromPrice}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: palette.primary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),

                      // Quick Sub-Section Mini-Pills (Top 2 + Add)
                      Row(
                        children: [
                          ...topSubSections.map((sub) {
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onSubSectionTap(sub.slug),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sub.emoji,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          sub.label,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          // + button
                          GestureDetector(
                            onTap: widget.onAddSubSectionTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.badgeBg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: palette.primary.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '+',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Explore CTA Pill with Dynamic Gradient
                      GestureDetector(
                        onTap: widget.onTapExplore,
                        child: Container(
                          width: double.infinity,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: palette.gradient,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              if (_isHovered)
                                BoxShadow(
                                  color: palette.glowColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Explore',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
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
