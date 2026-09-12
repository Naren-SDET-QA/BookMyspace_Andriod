import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../../events/presentation/event_providers.dart';
import '../../../location/presentation/gps_session.dart';
import '../../../cms/presentation/cms_providers.dart';
import '../../../offers/presentation/coupon_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../discovery_location.dart';
import '../home_category_catalog.dart';
import '../widgets/category_glass_matrix.dart';
import '../widgets/home_feed_sections.dart';
import '../widgets/home_offer_banner.dart';
import '../widgets/location_picker_sheet.dart';

/// Customer Home: 3D glass category discovery plus popular venues.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MainHomeSection _selectedSection = MainHomeSection.functionHalls;
  late final PageController _masterPageController;

  @override
  void initState() {
    super.initState();
    _masterPageController = PageController(viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _masterPageController.dispose();
    super.dispose();
  }

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

  void _openMaster(MainHomeSection section, List<VenueCategory> cats) {
    final matched = section.matchMaster(cats);
    _openSearch(categorySlug: matched?.slug ?? section.id);
  }

  void _openSubSection(
    MainHomeSection section,
    HomeSubSection sub,
    List<VenueCategory> cats,
  ) {
    final matched = sub.match(cats);
    if (matched != null) {
      _openSearch(categorySlug: matched.slug);
      return;
    }
    _openSearch(query: sub.label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final popularVenuesAsync = ref.watch(popularVenuesProvider);
    final location = ref.watch(discoveryLocationProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final couponsAsync = ref.watch(activeCouponsProvider);
    final cmsBanners = ref.watch(activeCmsBannersProvider).valueOrNull ?? const [];
    final myBookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            final dynamicCats =
                ref.watch(venueCategoriesProvider).valueOrNull ??
                    const <VenueCategory>[];
            final liveVenues =
                popularVenuesAsync.valueOrNull ?? const <Venue>[];
            final trending = dynamicCats
                .where((c) => c.isActive && c.slug != 'all')
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(popularVenuesProvider);
                ref.invalidate(nearbyVenuesProvider);
                ref.invalidate(venueCategoriesProvider);
                ref.invalidate(upcomingEventsProvider);
                ref.invalidate(publishedCoursesProvider);
                ref.invalidate(activeCouponsProvider);
                ref.invalidate(listedVenueCitiesProvider);
                ref.invalidate(myBookingsProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopHeaderBar(
                      user: user,
                      responsive: responsive,
                      cityLabel: location.label,
                      radiusKm: location.radiusKm,
                      locationSource: location.source,
                      onLocationTap: _showLocationPickerModal,
                      onLoginTap: () => context.push(AppRoutes.login),
                      onProfileTap: () => context.go(AppRoutes.profile),
                      onNotificationsTap: () =>
                          context.go(AppRoutes.notifications),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.horizontalPadding,
                        4,
                        responsive.horizontalPadding,
                        12,
                      ),
                      child: HomeSearchBar(
                        onTap: _openSearch,
                        onVoiceTap: () => _showVoiceBookingDialog(context),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.horizontalPadding,
                        0,
                        responsive.horizontalPadding,
                        16,
                      ),
                      child: RepaintBoundary(
                        child: HomeOfferBanner(
                          coupons: couponsAsync.valueOrNull ?? const [],
                          cmsBanners: cmsBanners,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.horizontalPadding,
                        vertical: 8,
                      ),
                      child: CategoryDiscoveryPanel(
                        sections: MainHomeSection.discoveryOrder,
                        selected: _selectedSection,
                        pageController: _masterPageController,
                        categories: dynamicCats,
                        venues: liveVenues,
                        onMasterChanged: (section) {
                          setState(() => _selectedSection = section);
                        },
                        onMasterExplore: (section) =>
                            _openMaster(section, dynamicCats),
                        onSubSectionTap: (section, sub) =>
                            _openSubSection(section, sub, dynamicCats),
                      ),
                    ),
                  ),
                  if ((popularVenuesAsync.valueOrNull ?? const <Venue>[])
                      .where((venue) => venue.ratingCount > 0)
                      .isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: HomeSpotlightRow(
                          venues: (popularVenuesAsync.valueOrNull ??
                                  const <Venue>[])
                              .where((venue) => venue.ratingCount > 0)
                              .toList()
                            ..sort(
                                (a, b) => b.avgRating.compareTo(a.avgRating)),
                        ),
                      ),
                    ),
                  if ((couponsAsync.valueOrNull ?? const []).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: HomeCouponRow(
                          coupons: couponsAsync.valueOrNull ?? const [],
                        ),
                      ),
                    ),
                  if ((eventsAsync.valueOrNull ?? const []).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: HomeHorizontalEvents(
                          events: eventsAsync.valueOrNull ?? const [],
                        ),
                      ),
                    ),
                  if ((coursesAsync.valueOrNull ?? const []).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: HomeHorizontalCourses(
                          courses: coursesAsync.valueOrNull ?? const [],
                        ),
                      ),
                    ),
                  if (trending.isNotEmpty)
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
                              'Listed categories',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 42,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: trending.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cat = trending[index];
                                  return AnimatedCategoryChip(
                                    selected: false,
                                    label: cat.name,
                                    emoji: cat.icon?.isNotEmpty == true
                                        ? cat.icon!
                                        : '🏷️',
                                    height: 40,
                                    onTap: () => _openSearch(
                                      categorySlug: cat.slug,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.horizontalPadding,
                        16,
                        responsive.horizontalPadding,
                        8,
                      ),
                      child: Text(
                        'Available Spaces',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  popularVenuesAsync.when(
                    data: (venues) {
                      if (venues.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No spaces found',
                              message:
                                  'Try changing category or location filters.',
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: responsive.resultsColumns,
                            mainAxisSpacing: responsive.gridSpacing,
                            crossAxisSpacing: responsive.gridSpacing,
                            childAspectRatio: responsive.resultsAspectRatio,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final venue = venues[index];
                              return _SectionVenueCard(
                                venue: venue,
                                onTap: () => context.push(
                                  AppRoutes.venueDetails
                                      .replaceAll(':id', venue.id),
                                ),
                                onBookTap: () => context.push(
                                  AppRoutes.bookingFlow
                                      .replaceAll(':id', venue.id),
                                ),
                                onCallTap: () => _handleCall(context, venue),
                                onWhatsAppTap: () =>
                                    _handleWhatsApp(context, venue),
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
                            Expanded(
                              child: HomeShimmerBox(height: 220, radius: 20),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: HomeShimmerBox(height: 220, radius: 20),
                            ),
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
                  if ((myBookingsAsync.valueOrNull ?? const []).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: HomeRecentBookings(
                          bookings: myBookingsAsync.valueOrNull ?? const [],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.horizontalPadding,
                        vertical: 24,
                      ),
                      child: _LocationFooterCard(
                        currentLocation: location.label,
                        searchRadius: 'Within ${location.radiusKm} km',
                        onTap: _showLocationPickerModal,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
      builder: (context) => const LocationPickerSheet(),
    );
  }

  void _showVoiceBookingDialog(BuildContext context) {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (voiceResult) {
        context.go(
          SearchRouteParams.locationFor(voiceResult.toVenueSearchQuery()),
        );
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
        context.go(AppRoutes.search);
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

/// Header Bar with Logo, location, notifications and profile.
class _TopHeaderBar extends ConsumerWidget {
  const _TopHeaderBar({
    required this.user,
    required this.responsive,
    required this.cityLabel,
    required this.radiusKm,
    required this.locationSource,
    required this.onLocationTap,
    required this.onLoginTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final dynamic user;
  final ResponsiveInfo responsive;
  final String cityLabel;
  final int radiusKm;
  final DiscoveryLocationSource locationSource;
  final VoidCallback onLocationTap;
  final VoidCallback onLoginTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gpsPhase = ref.watch(gpsSessionProvider.select((s) => s.phase));

    final identity = user == null
        ? FilledButton.tonal(
            onPressed: onLoginTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 40),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          )
        : InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user?.email?.isNotEmpty == true
                    ? user.email[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        10,
        responsive.horizontalPadding,
        8,
      ),
      child: Row(
        children: [
          const BookMySpaceMark(size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookMySpaceWordmark(
                  fontSize: 18,
                  textColor: theme.colorScheme.onSurface,
                ),
                HomeLocationHeader(
                  cityLabel: cityLabel,
                  radiusKm: radiusKm,
                  source: locationSource,
                  gpsPhase: gpsPhase,
                  onTap: onLocationTap,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          identity,
        ],
      ),
    );
  }
}

/// Compact World-Class 3D Glass Category Card with Dynamic Category Colors,
/// 3D Perspective Tilt, Ambient Glow, Specular Highlights & 1-Tap Quick Filters.
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
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
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
class _SectionVenueCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));

    return GlassmorphicCard(
      borderRadius: 18,
      onTap: onTap,
      accentGradient: AppTheme.brandGradient,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
                Positioned(
                  top: 8,
                  left: 8,
                  child: favorite.when(
                    data: (isFav) => FavoriteButton(
                      isFavorite: isFav,
                      onPressed: () async {
                        if (ref.read(currentUserProvider) == null) {
                          context.push(AppRoutes.login);
                          return;
                        }
                        await ref
                            .read(favoriteControllerProvider)
                            .toggle(venue.id);
                      },
                    ),
                    loading: () => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                    error: (_, __) => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                  ),
                ),
                if (venue.distanceKm != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded,
                              size: 12, color: Colors.white),
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
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      onPressed: onCallTap,
                      style: IconButton.styleFrom(
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
                      style: IconButton.styleFrom(
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
