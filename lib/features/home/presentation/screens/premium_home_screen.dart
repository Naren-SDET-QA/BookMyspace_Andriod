import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../../core/widgets/language_picker_sheet.dart';
import '../../../ai_booking/presentation/widgets/ai_booking_sheet.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../cms/presentation/cms_providers.dart';
import '../../../cms/presentation/widgets/live_brand.dart';
import '../../../courses/domain/course.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../notifications/presentation/notification_providers.dart';
import '../../../offers/domain/coupon.dart';
import '../../../offers/presentation/coupon_providers.dart';
import '../../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../domain/home_appearance.dart';
import '../discovery_booking_prefs.dart';
import '../discovery_location.dart';
import '../home_appearance_providers.dart';
import '../home_category_catalog.dart';
import '../recently_viewed.dart';
import '../widgets/home_feed_sections.dart' show HomeGuestsPickerSheet;
import '../widgets/home_ai_booking_card.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/premium_promo_carousel.dart';

/// "Premium" Home layout (admin Home settings -> Home layout -> Premium).
///
/// A hero with a tabbed search panel, category tiles, a promo banner, popular
/// venues, offers and the customer's recently viewed venues. Every block is
/// backed by live data and hides itself when that data is empty, so nothing
/// on this screen is a placeholder that leads nowhere.
class PremiumHomeScreen extends ConsumerStatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  ConsumerState<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

enum _SearchTab { spaces, institutes, classes, stays }

class _PremiumHomeScreenState extends ConsumerState<PremiumHomeScreen> {
  final _where = TextEditingController();
  _SearchTab _tab = _SearchTab.spaces;

  @override
  void dispose() {
    _where.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openSearch({String? categorySlug, String? query}) {
    final location = ref.read(discoveryLocationProvider);
    context.go(
      SearchRouteParams(
        categorySlug: categorySlug,
        query: query ?? '',
        city: location.city,
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: location.hasCoordinates ? location.radiusKm : null,
        pincode: location.pincode,
      ).searchLocation,
    );
  }

  void _openSection(MainHomeSection section) {
    if (section == MainHomeSection.institutesClasses) {
      context.push(AppRoutes.education);
      return;
    }
    if (section == MainHomeSection.lodgeRooms ||
        section == MainHomeSection.pgHostels) {
      _openStayList(section);
      return;
    }
    final cats =
        ref.read(venueCategoriesProvider).valueOrNull ??
        const <VenueCategory>[];
    _openSearch(categorySlug: section.matchMaster(cats)?.slug ?? section.id);
  }

  /// Hotels and PG use the stay-results page (destination, dates, filters,
  /// property cards). Halls and sports stay on venue search.
  void _openStayList(MainHomeSection section, {String? query}) {
    final location = ref.read(discoveryLocationProvider);
    final typed = query?.trim() ?? '';
    final area = typed.isNotEmpty
        ? typed
        : location.hasCity
        ? location.city!.trim()
        : (location.pincode?.trim() ?? '');
    final path = section == MainHomeSection.pgHostels
        ? AppRoutes.pgList
        : AppRoutes.staysList;
    context.push(
      area.isEmpty ? path : '$path?q=${Uri.encodeQueryComponent(area)}',
    );
  }

  void _openPopular(String query) {
    switch (query.trim().toLowerCase()) {
      case 'hostels':
        _openStayList(MainHomeSection.pgHostels);
      case 'resorts':
        _openStayList(MainHomeSection.lodgeRooms);
      default:
        _openSearch(query: query);
    }
  }

  void _submitSearch() {
    final text = _where.text.trim();
    switch (_tab) {
      case _SearchTab.spaces:
        _openSearch(query: text);
      case _SearchTab.institutes:
        context.push(
          text.isEmpty
              ? AppRoutes.education
              : '${AppRoutes.education}?q=${Uri.encodeQueryComponent(text)}',
        );
      case _SearchTab.classes:
        context.go(AppRoutes.coursesList);
      case _SearchTab.stays:
        context.push(
          text.isEmpty
              ? AppRoutes.staysList
              : '${AppRoutes.staysList}?q=${Uri.encodeQueryComponent(text)}',
        );
    }
  }

  Future<void> _pickDate() async {
    final current = ref.read(discoveryBookingPrefsProvider).day;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    ref.read(discoveryBookingPrefsProvider.notifier).setDate(picked);
  }

  Future<void> _pickGuests() async {
    final current = ref.read(discoveryBookingPrefsProvider).guests;
    final picked = await HomeGuestsPickerSheet.show(context, selected: current);
    if (picked == null || !mounted) return;
    ref.read(discoveryBookingPrefsProvider.notifier).setGuests(picked);
  }

  void _pickLocation() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LocationPickerSheet(),
    );
  }

  void _voiceSearch() {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (result) {
        if (result.categorySlug == 'institutes_classes') {
          final q = result.cleanedSearchQuery.trim();
          context.go(
            q.isEmpty
                ? AppRoutes.education
                : '${AppRoutes.education}?q=${Uri.encodeQueryComponent(q)}',
          );
          return;
        }
        context.go(SearchRouteParams.locationFor(result.toVenueSearchQuery()));
      },
      onFallbackToText: () => context.go(AppRoutes.search),
    );
  }

  // ---------------------------------------------------------------------------
  // Promo carousel
  // ---------------------------------------------------------------------------

  /// Slides for the "Deals & Happenings" carousel, all from live data:
  /// coupons, a class running today, a sports venue and a function hall.
  /// Any kind without data is simply left out.
  List<PromoSlide> _promoSlides({
    required List<Coupon> coupons,
    required List<Venue> venues,
    required List<Course> courses,
  }) {
    final slides = <PromoSlide>[];
    PromoSlide couponSlide(Coupon c, List<Color> colors) => PromoSlide(
      id: 'coupon-${c.id}',
      badge: 'BOOK MORE, SAVE MORE',
      badgeIcon: Icons.local_offer_rounded,
      title: 'Use code ${c.code}',
      subtitle: c.description,
      highlight: _offLabel(c),
      highlightCaption: 'limited offer',
      colors: colors,
      onTap: () => _openSearch(),
    );

    if (coupons.isNotEmpty) {
      slides.add(couponSlide(coupons.first, _slideColors[0]));
    }

    final today = DateUtils.dateOnly(DateTime.now());
    for (final course in courses) {
      final batch = course.batches.where((b) {
        if (!b.isActive) return false;
        final start = DateUtils.dateOnly(b.startsOn);
        final end = b.endsOn == null ? null : DateUtils.dateOnly(b.endsOn!);
        return start == today ||
            (start.isBefore(today) && end != null && !end.isBefore(today));
      }).firstOrNull;
      if (batch == null) continue;
      final where = [
        course.instituteName,
        course.instituteCity,
      ].where((s) => s.trim().isNotEmpty).join(', ');
      slides.add(
        PromoSlide(
          id: 'class-${course.id}',
          badge: DateUtils.dateOnly(batch.startsOn) == today
              ? 'CLASS STARTS TODAY'
              : "TODAY'S CLASS",
          badgeIcon: Icons.school_rounded,
          title: course.title,
          subtitle: course.instructorName.isEmpty
              ? ''
              : 'by ${course.instructorName}',
          detail: [
            if (batch.timing.trim().isNotEmpty) batch.timing.trim(),
            if (where.isNotEmpty) where,
          ].join(' · '),
          detailIcon: Icons.schedule_rounded,
          imageUrl: course.coverImage,
          colors: _slideColors[1],
          onTap: () => context.push(
            AppRoutes.courseDetails.replaceAll(':id', course.id),
          ),
        ),
      );
      break;
    }

    PromoSlide? venueSlide(
      bool Function(String slug) match,
      String badge,
      IconData icon,
      List<Color> colors,
    ) {
      final venue = venues
          .where((v) => match((v.category?.slug ?? '').toLowerCase()))
          .fold<Venue?>(null, (best, v) {
            if (best == null) return v;
            return v.avgRating > best.avgRating ? v : best;
          });
      if (venue == null) return null;
      final price = venue.pricingBaseAmount > 0
          ? venue.pricingBaseAmount
          : venue.price;
      return PromoSlide(
        id: 'venue-${venue.id}',
        badge: badge,
        badgeIcon: icon,
        title: venue.name,
        detail: venue.city,
        highlight: price > 0 ? _inr.format(price) : '',
        highlightCaption: price > 0 ? _priceSuffix(venue) : '',
        imageUrl: venue.coverOrSampleImageUrl,
        colors: colors,
        onTap: () =>
            context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id)),
      );
    }

    final sports = venueSlide(
      (s) => s.contains('sport') || s.contains('turf') || s.contains('court'),
      'SPORTS',
      Icons.sports_soccer_rounded,
      _slideColors[2],
    );
    if (sports != null) slides.add(sports);
    final hall = venueSlide(
      (s) =>
          s.contains('function') ||
          s.contains('hall') ||
          s.contains('banquet') ||
          s.contains('marriage') ||
          s.contains('convention'),
      'CELEBRATE',
      Icons.celebration_rounded,
      _slideColors[3],
    );
    if (hall != null) slides.add(hall);

    for (final c in coupons.skip(1).take(2)) {
      slides.add(couponSlide(c, _slideColors[4 + slides.length % 2]));
    }
    return slides;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = ref.watch(discoveryLocationProvider);
    final offersEnabled = ref.watch(moduleEnabledProvider('offers'));
    final coupons = offersEnabled
        ? ref.watch(activeCouponsProvider).valueOrNull ?? const <Coupon>[]
        : const <Coupon>[];
    final nearby = ref.watch(nearbyVenuesProvider).valueOrNull ?? const [];
    final popular = ref.watch(popularVenuesProvider);
    final venues = nearby.isNotEmpty ? nearby : popular.valueOrNull ?? const [];
    final recent =
        ref.watch(recentlyViewedProvider).valueOrNull ??
        const <RecentlyViewedVenue>[];
    final cmsBanners =
        ref.watch(activeCmsBannersProvider).valueOrNull ?? const [];
    var heroImage = MainHomeSection.functionHalls.fallbackImageUrl;
    for (final banner in cmsBanners) {
      final url = banner.imageUrl;
      if (banner.isActive && url != null && url.isNotEmpty) {
        heroImage = url;
        break;
      }
    }
    final courses =
        ref.watch(publishedCoursesProvider).valueOrNull ?? const <Course>[];
    final promoSlides = _promoSlides(
      coupons: coupons,
      venues: [...venues, ...popular.valueOrNull ?? const <Venue>[]],
      courses: courses,
    );
    final showAiBooking = ref
        .watch(homeVisibleBlocksProvider)
        .any((block) => block.kind == HomeBlockKind.aiBooking);
    final place =
        location.label.trim().isEmpty ||
            location.label.toLowerCase().contains('select')
        ? null
        : location.label;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularVenuesProvider);
          ref.invalidate(nearbyVenuesProvider);
          ref.invalidate(activeCouponsProvider);
          ref.invalidate(venueCategoriesProvider);
          ref.invalidate(activeCmsBannersProvider);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pad = width >= 1100
                ? 48.0
                : width >= 700
                ? 28.0
                : 16.0;
            return CustomScrollView(
              key: const Key('premium-home'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(
                    imageUrl: heroImage,
                    horizontalPadding: pad,
                    wide: width >= 900,
                    locationLabel: place ?? 'Select location',
                    onLocationTap: _pickLocation,
                    onSearchTap: () => _openSearch(),
                    onVoiceTap: _voiceSearch,
                    coupon: coupons.isEmpty ? null : coupons.first,
                    onOffersTap: () => _openSearch(),
                    onOccasion: (q) => _openSearch(query: q),
                    panel: _SearchPanel(
                      tab: _tab,
                      onTab: (t) => setState(() => _tab = t),
                      whereController: _where,
                      onSubmit: _submitSearch,
                      onDateTap: _pickDate,
                      onGuestsTap: _pickGuests,
                      onPopular: _openPopular,
                    ),
                  ),
                ),
                // Same admin switch as the Glass Home: the AI booking block
                // shows when Admin -> Home layout keeps it visible.
                if (showAiBooking)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                      child: const RepaintBoundary(child: HomeAiBookingCard()),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
                    child: _SectionHeader(
                      title: 'Explore Categories',
                      subtitle: place == null
                          ? 'Discover amazing spaces near you'
                          : 'Discover amazing spaces in $place',
                      onViewAll: () => _openSearch(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryRow(
                    horizontalPadding: pad,
                    onAll: () => _openSearch(),
                    onSection: _openSection,
                  ),
                ),
                if (promoSlides.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
                      child: PremiumPromoCarousel(slides: promoSlides),
                    ),
                  ),
                if (venues.isNotEmpty || popular.isLoading) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 28, pad, 8),
                      child: _SectionHeader(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Popular Near You',
                        subtitle: 'Handpicked spaces loved by people',
                        onViewAll: () => _openSearch(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 276,
                      child: venues.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              scrollDirection: Axis.horizontal,
                              itemCount: venues.length.clamp(0, 12),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (_, i) => _VenueCard(
                                venue: venues[i],
                                trending: i == 0,
                              ),
                            ),
                    ),
                  ),
                ],
                if (coupons.length > 1) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 28, pad, 8),
                      child: _SectionHeader(
                        icon: Icons.local_offer_rounded,
                        title: 'Top Offers For You',
                        subtitle: 'Save more on your next booking',
                        onViewAll: () => _openSearch(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 156,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        scrollDirection: Axis.horizontal,
                        itemCount: coupons.length.clamp(0, 8),
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => _OfferCard(
                          coupon: coupons[i],
                          index: i,
                          onTap: () => _openSearch(),
                        ),
                      ),
                    ),
                  ),
                ],
                if (recent.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 28, pad, 8),
                      child: _SectionHeader(
                        icon: Icons.history_rounded,
                        title: 'Your Recently Viewed',
                        subtitle: 'Pick up where you left off',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 176,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _RecentCard(item: recent[i]),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Palette
// -----------------------------------------------------------------------------

const _violet = Color(0xFF6D28D9);
const _indigo = Color(0xFF4F46E5);
const _pink = Color(0xFFEC4899);
const _teal = Color(0xFF14B8A6);

const _brandGradient = LinearGradient(colors: [_indigo, _violet, _pink]);

/// Per-slide gradients for the promo carousel, one colour story per kind.
const _slideColors = <List<Color>>[
  [Color(0xFF4F46E5), Color(0xFFEC4899)], // coupon
  [Color(0xFFF59E0B), Color(0xFFEF4444)], // class
  [Color(0xFF10B981), Color(0xFF0EA5E9)], // sports
  [Color(0xFF7C3AED), Color(0xFFDB2777)], // function hall
  [Color(0xFF0EA5E9), Color(0xFF6366F1)], // extra coupon
  [Color(0xFFF97316), Color(0xFFD946EF)], // extra coupon
];

// -----------------------------------------------------------------------------
// Hero
// -----------------------------------------------------------------------------

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.imageUrl,
    required this.horizontalPadding,
    required this.wide,
    required this.locationLabel,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onVoiceTap,
    required this.coupon,
    required this.onOffersTap,
    required this.onOccasion,
    required this.panel,
  });

  final String imageUrl;
  final double horizontalPadding;
  final bool wide;
  final String locationLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onVoiceTap;
  final Coupon? coupon;
  final VoidCallback onOffersTap;
  final ValueChanged<String> onOccasion;
  final Widget panel;

  static const _occasions = <(IconData, String)>[
    (Icons.favorite_rounded, 'Weddings'),
    (Icons.celebration_rounded, 'Parties'),
    (Icons.business_center_rounded, 'Business'),
    (Icons.sports_soccer_rounded, 'Sports'),
    (Icons.school_rounded, 'Classes'),
    (Icons.hotel_rounded, 'Stay'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final title = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Perfect Spaces\nfor Every '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFFF9A8D4), Color(0xFFC4B5FD)],
              ).createShader(r),
              child: Text(
                'Moment',
                style: TextStyle(
                  fontSize: wide ? 48 : 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      style: TextStyle(
        color: Colors.white,
        fontSize: wide ? 48 : 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    );

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TURN MOMENTS INTO MEMORIES',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        title,
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label) in _occasions)
              _OccasionChip(
                icon: icon,
                label: label,
                onTap: () => onOccasion(label),
              ),
          ],
        ),
      ],
    );

    final offer = coupon == null
        ? null
        : _HeroOfferCard(coupon: coupon!, onTap: onOffersTap);

    return Stack(
      children: [
        Positioned.fill(child: AppNetworkImage(url: imageUrl)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.55, 0.8, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                  surface.withValues(alpha: 0.85),
                  surface,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBar(
                  wide: wide,
                  locationLabel: locationLabel,
                  onLocationTap: onLocationTap,
                  onSearchTap: onSearchTap,
                  onVoiceTap: onVoiceTap,
                ),
                SizedBox(height: wide ? 40 : 24),
                if (wide && offer != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: intro),
                      const SizedBox(width: 24),
                      SizedBox(width: 260, child: offer),
                    ],
                  )
                else ...[
                  intro,
                  if (offer != null) ...[const SizedBox(height: 16), offer],
                ],
                SizedBox(height: wide ? 36 : 24),
                panel,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBar extends ConsumerWidget {
  const _HeaderBar({
    required this.wide,
    required this.locationLabel,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onVoiceTap,
  });

  final bool wide;
  final String locationLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final unread = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LiveBrandMark(size: 32),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: BookMySpaceWordmark(fontSize: 18, textColor: Colors.white),
          ),
        ),
      ],
    );

    final location = Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('premium-location'),
        customBorder: const StadiumBorder(),
        onTap: onLocationTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: _violet),
              const SizedBox(width: 4),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Color(0xFF0F172A),
              ),
            ],
          ),
        ),
      ),
    );

    final search = Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('premium-header-search'),
        customBorder: const StadiumBorder(),
        onTap: onSearchTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Search for function halls, hotels, resorts, sports, classes...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Voice search',
                onPressed: onVoiceTap,
                icon: const Icon(Icons.mic_rounded, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );

    final actions = <Widget>[
      const _LanguageButton(),
      _HeaderIcon(
        key: const Key('premium-ai'),
        icon: Icons.auto_awesome_rounded,
        tooltip: 'AI booking assistant',
        onTap: () => AiBookingSheet.show(context),
      ),
      _HeaderIcon(
        key: const Key('premium-notifications'),
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notifications',
        badge: unread,
        onTap: () => context.go(AppRoutes.notifications),
      ),
      _HeaderIcon(
        key: const Key('premium-saved'),
        icon: Icons.favorite_border_rounded,
        tooltip: 'Saved spaces',
        onTap: () => context.go(AppRoutes.saved),
      ),
      const SizedBox(width: 4),
      if (user == null)
        FilledButton(
          key: const Key('premium-sign-in'),
          onPressed: () => context.push(AppRoutes.login),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _violet,
            minimumSize: const Size(0, 38),
            shape: const StadiumBorder(),
          ),
          child: const Text('Sign In'),
        )
      else
        InkWell(
          key: const Key('premium-profile'),
          customBorder: const CircleBorder(),
          onTap: () => context.go(AppRoutes.profile),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: _teal,
            child: Text(
              (user.fullName.isNotEmpty ? user.fullName : user.email)
                      .trim()
                      .isEmpty
                  ? 'U'
                  : (user.fullName.isNotEmpty ? user.fullName : user.email)
                        .trim()[0]
                        .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
    ];

    if (wide) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            brand,
            const SizedBox(width: 16),
            location,
            const SizedBox(width: 16),
            Expanded(child: SizedBox(height: 44, child: search)),
            const SizedBox(width: 12),
            ...actions,
          ],
        ),
      );
    }
    // Phones: brand + account on top, location + quick actions below, so
    // nothing gets squeezed (the brand needs ~40px for its mark alone).
    final account = actions.last;
    final quick = actions.sublist(0, actions.length - 2); // no spacer/account
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: brand),
              ),
              account,
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: location),
            ),
            ...quick,
          ],
        ),
      ],
    );
  }
}

/// Language switcher: every locale the app ships, shown in its own script.
class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Tooltip(
      message: 'Language',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          key: const Key('premium-language'),
          customBorder: const StadiumBorder(),
          onTap: () => _pick(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                // Phones: icon only, so the header never overflows.
                if (MediaQuery.sizeOf(context).width >= 600) ...[
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.languageLabel(locale),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    showLanguagePickerSheet(context, ref, keyPrefix: 'premium-language');
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text(badge > 9 ? '9+' : '$badge'),
        backgroundColor: _pink,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _OccasionChip extends StatelessWidget {
  const _OccasionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        key: Key('premium-occasion-$label'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroOfferCard extends StatelessWidget {
  const _HeroOfferCard({required this.coupon, required this.onTap});

  final Coupon coupon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE9FE), Color(0xFFFCE7F3)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Special Offer',
              style: TextStyle(
                color: _violet,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Get ${_offLabel(coupon)}',
              style: const TextStyle(
                color: Color(0xFF1E1B4B),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (coupon.description.isNotEmpty)
              Text(
                coupon.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4C1D95),
                  fontSize: 12.5,
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('premium-hero-offer'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                shape: const StadiumBorder(),
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View Offers'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Search panel
// -----------------------------------------------------------------------------

class _SearchPanel extends ConsumerWidget {
  const _SearchPanel({
    required this.tab,
    required this.onTab,
    required this.whereController,
    required this.onSubmit,
    required this.onDateTap,
    required this.onGuestsTap,
    required this.onPopular,
  });

  final _SearchTab tab;
  final ValueChanged<_SearchTab> onTab;
  final TextEditingController whereController;
  final VoidCallback onSubmit;
  final VoidCallback onDateTap;
  final VoidCallback onGuestsTap;
  final ValueChanged<String> onPopular;

  static const _tabs = <(_SearchTab, IconData, String)>[
    (_SearchTab.spaces, Icons.home_work_rounded, 'Spaces'),
    (_SearchTab.institutes, Icons.account_balance_rounded, 'Institutes'),
    (_SearchTab.classes, Icons.co_present_rounded, 'Classes'),
    (_SearchTab.stays, Icons.hotel_rounded, 'Stays'),
  ];

  static const _popular = [
    'Marriage Halls',
    'Party Halls',
    'Meeting Rooms',
    'Sports Venues',
    'Coaching Centers',
    'Resorts',
    'Hostels',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(discoveryBookingPrefsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final today = DateTime.now();
    final day = prefs.day;
    final dateLabel =
        day.year == today.year &&
            day.month == today.month &&
            day.day == today.day
        ? 'Today'
        : DateFormat('d MMM').format(day);

    final where = TextField(
      key: const Key('premium-where'),
      controller: whereController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: switch (tab) {
          _SearchTab.institutes => 'Which institute or subject?',
          _SearchTab.classes => 'Which class are you looking for?',
          _ => 'Where do you want to book?',
        },
        prefixIcon: const Icon(Icons.location_on_outlined),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    final date = _PanelField(
      key: const Key('premium-date'),
      icon: Icons.calendar_month_rounded,
      label: dateLabel,
      onTap: onDateTap,
    );
    final guests = _PanelField(
      key: const Key('premium-guests'),
      icon: Icons.person_outline_rounded,
      label: prefs.guests == 1 ? '1 Guest' : '${prefs.guests} Guests',
      onTap: onGuestsTap,
    );
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('premium-search'),
          borderRadius: BorderRadius.circular(14),
          onTap: onSubmit,
          child: const SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              // Phones: four equal tabs that always fit on one line.
              if (c.maxWidth < 520) {
                return Row(
                  children: [
                    for (final (value, icon, label) in _tabs)
                      Expanded(
                        child: _CompactTab(
                          key: Key('premium-tab-${value.name}'),
                          icon: icon,
                          label: label,
                          selected: tab == value,
                          onTap: () => onTab(value),
                        ),
                      ),
                  ],
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, icon, label) in _tabs)
                    ChoiceChip(
                      key: Key('premium-tab-${value.name}'),
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      selected: tab == value,
                      showCheckmark: false,
                      onSelected: (_) => onTab(value),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 760) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: where),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: date),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: guests),
                    const SizedBox(width: 10),
                    SizedBox(width: 150, child: button),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  where,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: date),
                      const SizedBox(width: 10),
                      Expanded(child: guests),
                    ],
                  ),
                  const SizedBox(height: 10),
                  button,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // One scrollable line: on phones a wrapping list took five rows.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Popular searches:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final q in _popular)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      key: Key('premium-popular-$q'),
                      label: Text(q),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onPopular(q),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTab extends StatelessWidget {
  const _CompactTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected ? _violet : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? _violet.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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

class _PanelField extends StatelessWidget {
  const _PanelField({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.icon,
    this.onViewAll,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: _teal),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('View all'),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.horizontalPadding,
    required this.onAll,
    required this.onSection,
  });

  final double horizontalPadding;
  final VoidCallback onAll;
  final ValueChanged<MainHomeSection> onSection;

  static (IconData, Color, String) _style(MainHomeSection s) => switch (s) {
    MainHomeSection.functionHalls => (
      Icons.celebration_rounded,
      const Color(0xFFEC4899),
      'Function Halls',
    ),
    MainHomeSection.sportsTurfs => (
      Icons.sports_tennis_rounded,
      const Color(0xFF10B981),
      'Sports',
    ),
    MainHomeSection.pgHostels => (
      Icons.bed_rounded,
      const Color(0xFFF59E0B),
      'PG & Hostels',
    ),
    MainHomeSection.institutesClasses => (
      Icons.school_rounded,
      const Color(0xFF3B82F6),
      'Education & Classes',
    ),
    MainHomeSection.lodgeRooms => (
      Icons.apartment_rounded,
      const Color(0xFFEF4444),
      'Lodges & Stays',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _CategoryTile(
        keyName: 'all',
        icon: Icons.grid_view_rounded,
        color: _violet,
        label: 'All Categories',
        onTap: onAll,
      ),
      for (final section in MainHomeSection.discoveryOrder)
        () {
          final (icon, color, label) = _style(section);
          return _CategoryTile(
            keyName: section.id,
            icon: icon,
            color: color,
            label: label,
            onTap: () => onSection(section),
          );
        }(),
    ];
    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.keyName,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 92,
      child: InkWell(
        key: Key('premium-category-$keyName'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: isDark ? 0.35 : 0.18),
                    color.withValues(alpha: isDark ? 0.15 : 0.06),
                  ],
                ),
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "₹500 OFF" / "10% OFF" from a coupon's own label.
String _offLabel(Coupon coupon) =>
    '${coupon.valueLabel.replaceFirst(RegExp(r'\s*off\s*$', caseSensitive: false), '')} OFF';

/// Price suffix shown after a venue's base price, from its category.
String _priceSuffix(Venue venue) {
  final slug = (venue.category?.slug ?? '').toLowerCase();
  if (slug.contains('sport') ||
      slug.contains('turf') ||
      slug.contains('meeting') ||
      slug.contains('cowork')) {
    return '/hour';
  }
  if (slug.contains('lodge') ||
      slug.contains('hotel') ||
      slug.contains('stay') ||
      slug.contains('room')) {
    return '/night';
  }
  if (slug.contains('pg') || slug.contains('hostel')) return '/month';
  return 'onwards';
}

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class _VenueCard extends ConsumerWidget {
  const _VenueCard({required this.venue, this.trending = false});

  final Venue venue;
  final bool trending;

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    if (ref.read(currentUserProvider) == null) {
      context.push(AppRoutes.login);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(favoriteControllerProvider).toggle(venue.id);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not update saved spaces.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFav = ref.watch(isFavoriteProvider(venue.id)).valueOrNull ?? false;
    final price = venue.pricingBaseAmount > 0
        ? venue.pricingBaseAmount
        : venue.price;
    final details = AppRoutes.venueDetails.replaceAll(':id', venue.id);

    return SizedBox(
      width: 220,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          key: Key('premium-venue-${venue.id}'),
          onTap: () => context.push(details),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    venue.coverOrSampleImageUrl.isEmpty
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_outlined),
                          )
                        : AppNetworkImage(url: venue.coverOrSampleImageUrl),
                    if (trending)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: _brandGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Trending',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (venue.ratingCount > 0)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Color(0xFFFBBF24),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${venue.avgRating.toStringAsFixed(1)} '
                                '(${venue.ratingCount})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: Key('premium-fav-${venue.id}'),
                          visualDensity: VisualDensity.compact,
                          tooltip: isFav ? 'Remove from saved' : 'Save',
                          onPressed: () => _toggleFavorite(context, ref),
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: isFav ? _pink : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        venue.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (price > 0)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _inr.format(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _violet,
                                ),
                              ),
                              TextSpan(
                                text: ' ${_priceSuffix(venue)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: Key('premium-book-${venue.id}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => context.push(
                            AppRoutes.bookingFlow.replaceAll(':id', venue.id),
                            extra: venue,
                          ),
                          child: const Text('Book Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.coupon,
    required this.index,
    required this.onTap,
  });

  final Coupon coupon;
  final int index;
  final VoidCallback onTap;

  static const _gradients = [
    [Color(0xFFFCE7F3), Color(0xFFF9A8D4)],
    [Color(0xFFDBEAFE), Color(0xFF93C5FD)],
    [Color(0xFFEDE9FE), Color(0xFFC4B5FD)],
    [Color(0xFFFFEDD5), Color(0xFFFDBA74)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    return SizedBox(
      width: 260,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('premium-offer-${coupon.id}'),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
                  style: const TextStyle(
                    color: Color(0xFF4C1D95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _offLabel(coupon),
                  style: const TextStyle(
                    color: Color(0xFF1E1B4B),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: Text(
                    coupon.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'Book Now',
                      style: TextStyle(
                        color: _violet,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: _violet),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.item});

  final RecentlyViewedVenue item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('premium-recent-${item.id}'),
          onTap: () =>
              context.push(AppRoutes.venueDetails.replaceAll(':id', item.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 104,
                child: item.imageUrl.isEmpty
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined),
                      )
                    : AppNetworkImage(url: item.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.ratingCount > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFBBF24),
                          ),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      item.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
