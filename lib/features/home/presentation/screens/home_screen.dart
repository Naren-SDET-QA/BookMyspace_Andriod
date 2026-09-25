import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
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
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../../events/presentation/event_providers.dart';
import '../../../cms/domain/cms_banner.dart';
import '../../../cms/presentation/cms_providers.dart';
import '../../../courses/presentation/screens/education_hub_screen.dart';
import '../../../events/domain/event.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../../offers/domain/coupon.dart';
import '../../../offers/presentation/coupon_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../discovery_booking_prefs.dart';
import '../discovery_location.dart';
import '../home_appearance_providers.dart';
import '../home_category_catalog.dart';
import '../../domain/home_appearance.dart';
import '../widgets/category_glass_matrix.dart';
import '../widgets/home_ai_booking_card.dart';
import '../widgets/home_feed_sections.dart';
import '../widgets/home_offer_banner.dart';
import '../widgets/home_video_pill.dart';
import '../widgets/location_picker_sheet.dart';
import '../../../courses/domain/course.dart';

/// Customer Home: 3D glass category discovery plus popular venues.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeResultTab { spaces, institutes, classes }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MainHomeSection _selectedSection = MainHomeSection.functionHalls;

  /// Empty means "All Categories". Slugs are live CMS category slugs or
  /// [MainHomeSection.id] values.
  final Set<String> _selectedSlugs = <String>{};
  _HomeResultTab _resultTab = _HomeResultTab.spaces;

  // Phase 9XM-2 (Home load optimization): popularVenues, venueCategories,
  // venueSubsectionsCatalog, activeCoupons, and activeCmsBanners all gate
  // above-the-fold content (the category discovery panel and the offer
  // banner near the top of the page) and remain eagerly watched below,
  // unchanged from before. upcomingEvents, publishedCourses, and
  // myBookings only power sections further down the scroll (the events
  // row, courses row, and recent-bookings row) and are never required for
  // the first visible frame, so their first network trigger is deferred
  // by one frame -- after the initial frame has already painted -- via
  // this flag. This does not change what data loads or how it's cached
  // (all three remain the same non-autoDispose FutureProviders, so this
  // only delays *when* the first fetch starts, not duplicate-fetches or
  // drops any data), and it introduces no artificial timer-based delay.
  bool _deferredContentUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _deferredContentUnlocked = true);
      }
    });
  }

  /// Phase 9XM-2: returns [AsyncValue.loading] until the first frame has
  /// painted, then watches [watch] normally on every subsequent build.
  /// Riverpod supports conditional `ref.watch` calls (dependencies are
  /// re-tracked each build), so this does not break provider semantics,
  /// caching, or the `ref.invalidate` calls already used by pull-to-refresh
  /// below.
  AsyncValue<T> _deferUntilAfterFirstFrame<T>(
    AsyncValue<T> Function() watch,
  ) {
    return _deferredContentUnlocked ? watch() : AsyncValue<T>.loading();
  }

  @override
  void dispose() {
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
    // Education lands on the institutes/courses hub rather than a venue search.
    if (section == MainHomeSection.institutesClasses) {
      context.push(AppRoutes.education);
      return;
    }
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
    final bookingPrefs = ref.watch(discoveryBookingPrefsProvider);
    final eventsEnabled = ref.watch(moduleEnabledProvider('events'));
    final offersEnabled = ref.watch(moduleEnabledProvider('offers'));
    final eventsAsync =
        _deferUntilAfterFirstFrame(() => ref.watch(upcomingEventsProvider));
    final coursesAsync =
        _deferUntilAfterFirstFrame(() => ref.watch(publishedCoursesProvider));
    final couponsAsync = ref.watch(activeCouponsProvider);
    final cmsBanners =
        ref.watch(activeCmsBannersProvider).valueOrNull ?? const [];
    final categoryImageBySlot = ref.watch(activeCmsBannersBySlotProvider);
    // Phase 9XM-3: Home only ever shows a short recent-bookings preview,
    // so it reads the bounded recentBookingsProvider instead of the
    // unbounded myBookingsProvider (that provider's full history is now
    // reserved for callers that genuinely need it -- QR check-in pass
    // eligibility and the profile screen). Still deferred past first
    // frame per the 9XM-2 rationale (below-the-fold content).
    final myBookingsAsync =
        _deferUntilAfterFirstFrame(() => ref.watch(recentBookingsProvider));
    final visibleBlocks = ref.watch(homeVisibleBlocksProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            final dynamicCats =
                ref.watch(venueCategoriesProvider).valueOrNull ??
                    const <VenueCategory>[];
            final dynamicSubsections =
                ref.watch(venueSubsectionsCatalogProvider).valueOrNull ??
                    const <VenueSubsection>[];
            final liveVenues =
                popularVenuesAsync.valueOrNull ?? const <Venue>[];
            // Empty until the reader picks a location: nearbyVenuesProvider
            // deliberately never invents a city centroid.
            final radarVenues =
                ref.watch(nearbyVenuesProvider).valueOrNull ?? const <Venue>[];
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
                ref.invalidate(recentBookingsProvider);
              },
              child: CustomScrollView(
                cacheExtent: 2400,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopHeaderBar(
                      user: user,
                      responsive: responsive,
                      locationLabel: location.label,
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
                        0,
                      ),
                      child: _HomeHeroBanner(
                        banners: cmsBanners,
                        compact: responsive.isCompact,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.horizontalPadding,
                        responsive.isCompact ? 12 : 0,
                        responsive.horizontalPadding,
                        12,
                      ),
                      child: Transform.translate(
                        offset: Offset(0, responsive.isCompact ? 0 : -28),
                        child: HomeSearchBar(
                          onTap: () => _openSearch(),
                          onVoiceTap: () => _showVoiceBookingDialog(context),
                          onLocationTap: _showLocationPickerModal,
                          locationLabel: location.label,
                          onDateTap: _pickHeroDate,
                          dateLabel: _heroDateLabel(bookingPrefs.day),
                          onGuestsTap: _pickHeroGuests,
                          guestsLabel: bookingPrefs.guests == 1
                              ? '1 Guest'
                              : '${bookingPrefs.guests} Guests',
                        ),
                      ),
                    ),
                  ),
                  if (offersEnabled &&
                      visibleBlocks.any(
                        (block) => block.kind == HomeBlockKind.offerBanner,
                      ))
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
                            style: visibleBlocks
                                    .where(
                                      (block) =>
                                          block.kind ==
                                          HomeBlockKind.offerBanner,
                                    )
                                    .first
                                    .style,
                            images: visibleBlocks
                                .where(
                                  (block) =>
                                      block.kind == HomeBlockKind.offerBanner,
                                )
                                .first
                                .images,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        responsive.horizontalPadding,
                        4,
                        responsive.horizontalPadding,
                        8,
                      ),
                      child: _ExploreCategoryCards(
                        sections: MainHomeSection.discoveryOrder,
                        selectedSlugs: _selectedSlugs,
                        onSelectAll: () => setState(_selectedSlugs.clear),
                        onSelectSection: (section) {
                          setState(() {
                            _selectedSection = section;
                            _selectedSlugs
                              ..clear()
                              ..add(section.id);
                          });
                        },
                        onViewAll: () => _openSearch(),
                      ),
                    ),
                  ),
                  if (visibleBlocks.any(
                    (block) => block.kind == HomeBlockKind.categoryMatrix,
                  ))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: CategoryDiscoveryPanel(
                          sections: MainHomeSection.discoveryOrder,
                          selected: _selectedSection,
                          categories: dynamicCats,
                          dynamicSubsections: dynamicSubsections,
                          venues: liveVenues,
                          categoryImageBySlot: categoryImageBySlot,
                          isLoadingLiveData:
                              ref.watch(venueCategoriesProvider).isLoading,
                          onMasterChanged: (section) {
                            setState(() {
                              _selectedSection = section;
                              _selectedSlugs
                                ..clear()
                                ..add(section.id);
                            });
                          },
                          onMasterExplore: (section) =>
                              _openMaster(section, dynamicCats),
                          onSubSectionTap: (section, sub) =>
                              _openSubSection(section, sub, dynamicCats),
                          onExploreAll: () => _openSearch(),
                        ),
                      ),
                    ),
                  ..._composedSlivers(
                    l10n: AppLocalizations.of(context),
                    responsive: responsive,
                    blocks: visibleBlocks,
                    dynamicCats: dynamicCats,
                    liveVenues: liveVenues,
                    radarVenues: radarVenues,
                    ratedVenues:
                        (popularVenuesAsync.valueOrNull ?? const <Venue>[])
                            .where((venue) => venue.ratingCount > 0)
                            .toList()
                          ..sort((a, b) => b.avgRating.compareTo(a.avgRating)),
                    trending: trending,
                    coupons: offersEnabled
                        ? couponsAsync.valueOrNull ?? const []
                        : const [],
                    cmsBanners: cmsBanners,
                    bookings: myBookingsAsync.valueOrNull ?? const [],
                    theme: theme,
                    dynamicSubsections: dynamicSubsections,
                  ),
                  ..._selectionSlivers(
                    responsive: responsive,
                    venuesAsync: popularVenuesAsync,
                    venues: liveVenues,
                    institutes:
                        ref.watch(institutesProvider).valueOrNull ?? const [],
                    courses: coursesAsync.valueOrNull ?? const [],
                  ),
                  ..._activitySlivers(
                    l10n: AppLocalizations.of(context),
                    responsive: responsive,
                    theme: theme,
                    blocks: visibleBlocks,
                    offersEnabled: offersEnabled,
                    eventsEnabled: eventsEnabled,
                    coupons: couponsAsync.valueOrNull ?? const [],
                    bookings: myBookingsAsync.valueOrNull ?? const [],
                    events: eventsAsync.valueOrNull ?? const [],
                    saved:
                        ref.watch(savedVenuesProvider).valueOrNull ?? const [],
                    favoritesEnabled:
                        ref.watch(moduleEnabledProvider('favorites')),
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

  String _heroDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _pickHeroDate() async {
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

  Future<void> _pickHeroGuests() async {
    final current = ref.read(discoveryBookingPrefsProvider).guests;
    final picked = await HomeGuestsPickerSheet.show(
      context,
      selected: current,
    );
    if (picked == null || !mounted) return;
    ref.read(discoveryBookingPrefsProvider.notifier).setGuests(picked);
  }

  bool _educationSelected() {
    if (_selectedSlugs.isEmpty) return true;
    return _selectedSlugs.contains(MainHomeSection.institutesClasses.id) ||
        _selectedSlugs.contains('institutes_classes') ||
        _selectedSlugs.any(
          (slug) =>
              slug.contains('educat') ||
              slug.contains('institut') ||
              slug.contains('class') ||
              slug.contains('coach'),
        );
  }

  bool _spacesSelected() {
    if (_selectedSlugs.isEmpty) return true;
    return _selectedSlugs.any(
      (slug) =>
          slug != MainHomeSection.institutesClasses.id &&
          !slug.contains('educat') &&
          !slug.contains('institut') &&
          !slug.contains('class') &&
          !slug.contains('coach'),
    );
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    if (_selectedSlugs.isEmpty) return venues;
    return venues.where((venue) {
      final category = venue.category;
      if (category == null) return false;
      if (_selectedSlugs.contains(category.slug)) return true;
      if (category.parentSection != null &&
          _selectedSlugs.contains(category.parentSection)) {
        return true;
      }
      for (final section in MainHomeSection.values) {
        if (!_selectedSlugs.contains(section.id)) continue;
        if (section.searchAliases.contains(category.slug)) return true;
        if (category.parentSection == section.id) return true;
      }
      return false;
    }).toList();
  }

  List<Widget> _selectionSlivers({
    required ResponsiveInfo responsive,
    required AsyncValue<List<Venue>> venuesAsync,
    required List<Venue> venues,
    required List<Institute> institutes,
    required List<Course> courses,
  }) {
    final hPad = responsive.horizontalPadding;
    final showEducation = _educationSelected();
    final showSpaces = _spacesSelected();
    final filtered = _filterVenues(venues);
    final tabs = <_HomeResultTab>[
      if (showSpaces) _HomeResultTab.spaces,
      if (showEducation) ...[_HomeResultTab.institutes, _HomeResultTab.classes],
    ];
    if (tabs.isEmpty) return const [];
    var tab = _resultTab;
    if (!tabs.contains(tab)) tab = tabs.first;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your selection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openSearch(
                      categorySlug: _selectedSlugs.length == 1
                          ? _selectedSlugs.first
                          : null,
                    ),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (tabs.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final item in tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedCategoryChip(
                            selected: tab == item,
                            label: switch (item) {
                              _HomeResultTab.spaces => 'Function Halls',
                              _HomeResultTab.institutes => 'Institutes',
                              _HomeResultTab.classes => 'Classes',
                            },
                            height: 38,
                            onTap: () => setState(() => _resultTab = item),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (tab == _HomeResultTab.spaces)
        ..._venueResultSlivers(responsive, venuesAsync, filtered)
      else if (tab == _HomeResultTab.institutes)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
            child: institutes.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final institute in institutes.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InstituteCard(institute: institute),
                        ),
                    ],
                  ),
          ),
        )
      else if (courses.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
            child: HomeHorizontalCourses(courses: courses),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox.shrink()),
    ];
  }

  List<Widget> _venueResultSlivers(
    ResponsiveInfo responsive,
    AsyncValue<List<Venue>> venuesAsync,
    List<Venue> venues,
  ) {
    return [
      venuesAsync.when(
        data: (_) {
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
                  final venue = venues[index];
                  return _SectionVenueCard(
                    venue: venue,
                    onTap: () => context.push(
                      AppRoutes.venueDetails.replaceAll(':id', venue.id),
                    ),
                    onBookTap: () => context.push(
                      AppRoutes.bookingFlow.replaceAll(':id', venue.id),
                      extra: venue,
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
                Expanded(child: HomeShimmerBox(height: 220, radius: 20)),
                SizedBox(width: 12),
                Expanded(child: HomeShimmerBox(height: 220, radius: 20)),
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
    ];
  }

  List<Widget> _activitySlivers({
    required AppLocalizations l10n,
    required ResponsiveInfo responsive,
    required ThemeData theme,
    required List<HomeBlockConfig> blocks,
    required bool offersEnabled,
    required bool eventsEnabled,
    required List<Coupon> coupons,
    required List<Booking> bookings,
    required List<Event> events,
    required List<Venue> saved,
    required bool favoritesEnabled,
  }) {
    final hPad = responsive.horizontalPadding;
    final sponsoredOn =
        blocks.any((block) => block.kind == HomeBlockKind.offerBanner);
    final bookingsOn =
        blocks.any((block) => block.kind == HomeBlockKind.recentBookings);
    final children = <Widget>[];
    if (offersEnabled && coupons.isNotEmpty && !sponsoredOn) {
      children.add(HomeCouponRow(coupons: coupons));
    }
    if (bookingsOn && bookings.isNotEmpty) {
      children.add(HomeRecentBookings(bookings: bookings));
    }
    if (favoritesEnabled && saved.isNotEmpty) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.savedVenues,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: saved.length.clamp(0, 8),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 240,
                    child: VenueCard(venue: saved[index]),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    if (eventsEnabled && events.isNotEmpty) {
      children.add(HomeHorizontalEvents(events: events));
    }
    if (children.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                children[i],
              ],
            ],
          ),
        ),
      ),
    ];
  }

  /// The heading to show for [block] in the reader's language.
  ///
  /// An admin translation wins, then the admin's base title, then the shipped
  /// localized default. That order lets a single-language admin setup still
  /// read correctly in all five languages.
  String _localizedTitle(HomeBlockConfig block, AppLocalizations l10n) {
    final value = block.titleFor(l10n.locale.languageCode);
    if (value.isNotEmpty) return value;
    return switch (block.kind) {
      HomeBlockKind.spotlight => l10n.homeSpotlightTitle,
      HomeBlockKind.categoryChips => l10n.homeCategoriesTitle,
      HomeBlockKind.liveRadar => l10n.homeLiveRadarTitle,
      _ => '',
    };
  }

  /// The sub-heading to show for [block] in the reader's language.
  String _localizedSubtitle(HomeBlockConfig block, AppLocalizations l10n) =>
      block.subtitleFor(l10n.locale.languageCode);

  /// Renders the admin-composed Home blocks in configured order.
  ///
  /// A block whose data is unavailable is skipped rather than rendered empty,
  /// so disabling a module or having no data never leaves a gap on Home.
  List<Widget> _composedSlivers({
    required AppLocalizations l10n,
    required ResponsiveInfo responsive,
    required List<HomeBlockConfig> blocks,
    required List<VenueCategory> dynamicCats,
    required List<Venue> liveVenues,
    required List<Venue> radarVenues,
    required List<Venue> ratedVenues,
    required List<VenueCategory> trending,
    required List<Coupon> coupons,
    required List<CmsBanner> cmsBanners,
    required List<Booking> bookings,
    required ThemeData theme,
    required List<VenueSubsection> dynamicSubsections,
  }) {
    final hPad = responsive.horizontalPadding;
    final slivers = <Widget>[];

    for (final block in blocks) {
      // A block that actually rendered also gets its video affordance, placed
      // just above it. Capturing the count first means a block that skipped
      // itself for lack of data never leaves a dangling "Watch" chip behind.
      final renderedBefore = slivers.length;
      switch (block.kind) {
        case HomeBlockKind.offerBanner:
          // Rendered once above Explore so coupons are not duplicated.
          break;
        case HomeBlockKind.aiBooking:
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 14),
                child: RepaintBoundary(
                  child: HomeAiBookingCard(
                    title: _localizedTitle(block, l10n),
                    subtitle: _localizedSubtitle(block, l10n),
                    style: block.style,
                  ),
                ),
              ),
            ),
          );
        case HomeBlockKind.categoryMatrix:
          // Rendered once in the Explore section above the composed feed.
          break;
        case HomeBlockKind.spotlight:
          if (ratedVenues.isEmpty) break;
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                child: HomeSpotlightRow(
                  venues: ratedVenues,
                  title: _localizedTitle(block, l10n),
                  subtitle: _localizedSubtitle(block, l10n),
                  style: block.style,
                  images: block.images,
                ),
              ),
            ),
          );
        case HomeBlockKind.categoryChips:
          // Unified into the Explore categories chip row above.
          break;
        case HomeBlockKind.recentBookings:
          // Unified into the Your activity section below.
          break;
        case HomeBlockKind.liveRadar:
          // Nothing honest to show without a location, so the block is skipped
          // rather than padded with venues the reader is nowhere near.
          if (radarVenues.isEmpty) break;
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                child: HomeLiveRadar(
                  venues: radarVenues,
                  title: _localizedTitle(block, l10n),
                  subtitle: _localizedSubtitle(block, l10n),
                ),
              ),
            ),
          );
      }
      if (slivers.length > renderedBefore && block.videos.isNotEmpty) {
        slivers.insert(
          renderedBefore,
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
              child: HomeVideoPill(videos: block.videos),
            ),
          ),
        );
      }
    }
    return slivers;
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
        if (voiceResult.categorySlug == 'institutes_classes') {
          final query = voiceResult.cleanedSearchQuery.trim();
          context.go(
            query.isEmpty
                ? AppRoutes.education
                : '${AppRoutes.education}?q=${Uri.encodeQueryComponent(query)}',
          );
          return;
        }
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

  Future<void> _handleCall(BuildContext context, Venue venue) async {
    final phone = venue.contactPhone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The owner phone number is shared after your booking is confirmed.',
          ),
        ),
      );
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void _handleWhatsApp(BuildContext context, Venue venue) {
    context.push(AppRoutes.support);
  }
}

class _ExploreCategoryCards extends StatelessWidget {
  const _ExploreCategoryCards({
    required this.sections,
    required this.selectedSlugs,
    required this.onSelectAll,
    required this.onSelectSection,
    required this.onViewAll,
  });

  final List<MainHomeSection> sections;
  final Set<String> selectedSlugs;
  final VoidCallback onSelectAll;
  final ValueChanged<MainHomeSection> onSelectSection;
  final VoidCallback onViewAll;

  static String _shortLabel(MainHomeSection section) {
    return switch (section) {
      MainHomeSection.functionHalls => 'Function Halls',
      MainHomeSection.sportsTurfs => 'Sports',
      MainHomeSection.pgHostels => 'PG & Hostels',
      MainHomeSection.institutesClasses => 'Education',
      MainHomeSection.lodgeRooms => 'Lodges & Stays',
    };
  }

  static IconData _icon(MainHomeSection section) {
    return switch (section) {
      MainHomeSection.functionHalls => Icons.account_balance_rounded,
      MainHomeSection.sportsTurfs => Icons.directions_run_rounded,
      MainHomeSection.pgHostels => Icons.bed_rounded,
      MainHomeSection.institutesClasses => Icons.school_rounded,
      MainHomeSection.lodgeRooms => Icons.home_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = selectedSlugs.isEmpty;
    final items = <_ExploreItem>[
      _ExploreItem(
        keyName: 'all',
        label: 'All Categories',
        icon: Icons.apps_rounded,
        selected: allSelected,
        onTap: onSelectAll,
      ),
      for (final section in sections)
        _ExploreItem(
          keyName: section.id,
          label: _shortLabel(section),
          icon: _icon(section),
          selected: selectedSlugs.contains(section.id),
          onTap: () => onSelectSection(section),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Explore categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) =>
                _ExploreChip(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ExploreItem {
  const _ExploreItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

/// Horizontal pill chip for the "Explore categories" row.
///
/// Selected state: teal fill, white text/icon, leading check mark.
/// Unselected state: outlined pill, category icon, dark label.
class _ExploreChip extends StatelessWidget {
  const _ExploreChip({required this.item});

  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    final selected = item.selected;
    const selectedFill = Color(0xFF0D9488);
    const unselectedIcon = Color(0xFF0D9488);
    const unselectedText = Color(0xFF0F172A);
    const borderColor = Color(0xFFE2E8F0);

    return Material(
      color: selected ? selectedFill : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: Key('explore-${item.keyName}'),
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? selectedFill : borderColor,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                else
                  Icon(item.icon, size: 16, color: unselectedIcon),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? Colors.white : unselectedText,
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

class _HomeHeroBanner extends StatelessWidget {
  const _HomeHeroBanner({
    required this.banners,
    required this.compact,
  });

  final List<CmsBanner> banners;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    var imageUrl = MainHomeSection.functionHalls.fallbackImageUrl;
    for (final banner in banners) {
      final url = banner.imageUrl;
      if (banner.isActive && url != null && url.isNotEmpty) {
        imageUrl = url;
        break;
      }
    }
    final height = compact ? 168.0 : 220.0;
    return ClipRRect(
      key: const Key('home-hero'),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(url: imageUrl, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xCC0F172A),
                    Color(0x660F172A),
                    Color(0x220F172A),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, compact ? 20 : 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spaces for Every Moment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 22 : 32,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Function halls, education, stays and more.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header Bar with Logo, location, notifications and profile.
class _TopHeaderBar extends ConsumerWidget {
  const _TopHeaderBar({
    required this.user,
    required this.responsive,
    required this.onLoginTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onLocationTap,
    required this.locationLabel,
  });

  final dynamic user;
  final ResponsiveInfo responsive;
  final VoidCallback onLoginTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onLocationTap;
  final String locationLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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

    final narrow = responsive.isCompact;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.horizontalPadding,
        8,
        responsive.horizontalPadding,
        6,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const BookMySpaceMark(size: 32),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: BookMySpaceWordmark(
                fontSize: 17,
                textColor: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: _HeaderLocationChip(
                label: locationLabel,
                onTap: onLocationTap,
              ),
            ),
            const SizedBox(width: 4),
            _LanguagePill(compact: narrow),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotificationsTap,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            identity,
          ],
        ),
      ),
    );
  }
}

/// Language pill in the Home header. Real locales, real switching -- backed
/// by the app's existing [localeProvider]/[LocaleNotifier], not a cosmetic
/// stub. Tapping opens a picker over the languages [AppLocalizations]
/// actually ships translations for.
class _HeaderLocationChip extends StatelessWidget {
  const _HeaderLocationChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = label.trim().isEmpty ? 'Select location' : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePill extends ConsumerWidget {
  const _LanguagePill({this.compact = false});

  final bool compact;

  static const Map<String, String> _names = {
    'en': 'English',
    'te': 'Telugu',
    'hi': 'Hindi',
    'kn': 'Kannada',
    'ta': 'Tamil',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final label = _names[locale.languageCode] ?? locale.languageCode;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showLanguagePicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 15),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final current = ref.read(localeProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose language',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              for (final locale in AppLocalizations.supportedLocales)
                RadioGroup<String>(
                  groupValue: current.languageCode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(localeProvider.notifier).setLocale(locale);
                      Navigator.pop(sheetContext);
                    }
                  },
                  child: RadioListTile<String>(
                    value: locale.languageCode,
                    title: Text(
                        _names[locale.languageCode] ?? locale.languageCode),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
      accentGradient: AppTheme.violetGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  venue.city.isNotEmpty
                      ? venue.city
                      : venue.addressLine1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '₹${venue.pricingBaseAmount.toInt()}/day',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    if (venue.avgRating > 0)
                      RatingBadge(
                        rating: venue.avgRating,
                        count: venue.ratingCount,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onBookTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Book now',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onCallTap,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: const Text('Call'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onWhatsAppTap,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 16),
                        label: const Text('Chat'),
                      ),
                    ),
                    Expanded(
                      child: favorite.when(
                        data: (isFav) => TextButton.icon(
                          onPressed: () async {
                            if (ref.read(currentUserProvider) == null) {
                              context.push(AppRoutes.login);
                              return;
                            }
                            await ref
                                .read(favoriteControllerProvider)
                                .toggle(venue.id);
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: isFav ? Colors.redAccent : null,
                          ),
                          label: Text(isFav ? 'Saved' : 'Save'),
                        ),
                        loading: () => TextButton.icon(
                          onPressed: null,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.favorite_border_rounded,
                              size: 16),
                          label: const Text('Save'),
                        ),
                        error: (_, __) => TextButton.icon(
                          onPressed: null,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.favorite_border_rounded,
                              size: 16),
                          label: const Text('Save'),
                        ),
                      ),
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
