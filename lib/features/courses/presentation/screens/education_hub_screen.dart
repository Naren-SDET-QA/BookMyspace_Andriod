import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_category_chip.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../../home/presentation/home_category_catalog.dart';
import '../../../home/presentation/widgets/location_picker_sheet.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../../../venues/presentation/widgets/venue_badges.dart'
    show formatDistance, formatInr;
import '../../domain/class_category_filter.dart';
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import '../course_providers.dart';
import '../widgets/batch_class_card.dart';
import '../widgets/class_category_filter_sheet.dart';

enum _ListingScope { institutes, classes }

enum _HubSort { distance, name, priceLow, priceHigh }

/// Education landing: search, browse institutes by type, see featured
/// institutes and popular courses, and jump to all courses or My Courses.
///
/// Gated by the `courses` feature flag so disabling the module hides the
/// whole education surface with no dead navigation. Responsive across
/// phone (single column), tablet (2-column grid) and desktop/web
/// (multi-column grid, centered max-width content) via
/// [ResponsiveLayoutBuilder], matching the pattern already used on the
/// venues home screen.
class EducationHubScreen extends ConsumerStatefulWidget {
  const EducationHubScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<EducationHubScreen> createState() => _EducationHubScreenState();
}

class _EducationHubScreenState extends ConsumerState<EducationHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  InstituteType? _typeFilter;
  EducationCategory _category = EducationCategory.all;
  CourseMode? _mode;
  bool _ongoingToday = false;
  bool _waitlistOnly = false;
  _ListingScope _scope = _ListingScope.institutes;
  DateTime _slotDate = DateTime.now();
  int _attendees = 2;
  double? _maxFee;
  bool _parkingOnly = false;
  _HubSort _sort = _HubSort.distance;

  /// Multi-category selection for the classes list (category checkbox
  /// sheet). When non-empty it replaces the single [_category] for classes.
  Set<EducationCategory> _classCategories = const {};
  bool _includeFullAndUpcoming = true;

  ClassCategoryFilter get _classFilter => ClassCategoryFilter(
    categories: _classCategories.isNotEmpty
        ? _classCategories
        : (_category == EducationCategory.all ? const {} : {_category}),
    mode: _mode,
    includeFullAndUpcoming: _includeFullAndUpcoming,
  );

  Future<void> _openClassCategoryFilter(List<Course> courses) async {
    final result = await showClassCategoryFilterSheet(
      context,
      initial: _classFilter,
      courses: courses,
    );
    if (result == null || !mounted) return;
    setState(() {
      _scope = _ListingScope.classes;
      _mode = result.mode;
      _includeFullAndUpcoming = result.includeFullAndUpcoming;
      if (result.categories.length == 1) {
        _category = result.categories.first;
        _classCategories = const {};
      } else {
        _category = EducationCategory.all;
        _classCategories = result.categories;
      }
    });
  }

  static const _priceChipCap = 50000.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _query = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Institute> _filterInstitutes(
    List<Institute> items,
    List<Course> courses,
    DiscoveryLocation location,
  ) {
    final query = _query.trim().toLowerCase();
    return items.where((institute) {
      final matchesType = _typeFilter == null || institute.type == _typeFilter;
      final matchesQuery =
          query.isEmpty ||
          institute.name.toLowerCase().contains(query) ||
          institute.city.toLowerCase().contains(query) ||
          institute.address.toLowerCase().contains(query);
      if (!matchesType || !matchesQuery) return false;
      if (location.hasCity) {
        final city = location.city!.trim().toLowerCase();
        final instituteCity = institute.city.toLowerCase();
        if (instituteCity.isNotEmpty && !instituteCity.contains(city)) {
          return false;
        }
      }
      if (location.hasCoordinates) {
        final km = _distanceKm(institute, location);
        if (km != null && km > location.radiusKm) return false;
      }
      if (_mode != null && !_instituteMatchesMode(institute, courses)) {
        return false;
      }
      if (_parkingOnly && !_hasParking(institute)) return false;
      if (!_instituteMatchesCategory(institute, courses)) return false;
      if (_maxFee != null) {
        final fee = _lowestFee(institute, courses);
        if (fee == null || fee > _maxFee!) return false;
      }
      return true;
    }).toList();
  }

  bool _instituteMatchesCategory(Institute institute, List<Course> courses) {
    if (_category == EducationCategory.all) return true;
    final own = courses.where((c) => c.instituteId == institute.id);
    if (own.isEmpty) {
      return _category.matches(
        title: institute.name,
        subject: institute.description,
        categorySlug: institute.categoryId,
        instructor: '',
      );
    }
    return own.any(
      (course) =>
          course.batches.any(
            (batch) => _category.matches(
              title: course.title,
              subject: batch.subject,
              categorySlug: batch.categorySlug.isNotEmpty
                  ? batch.categorySlug
                  : course.categoryId,
              instructor: course.instructorName,
            ),
          ) ||
          _category.matches(
            title: course.title,
            subject: '',
            categorySlug: course.categoryId,
            instructor: course.instructorName,
          ),
    );
  }

  bool _instituteMatchesMode(Institute institute, List<Course> courses) {
    if (_mode == null) return true;
    if (institute.mode == _mode) return true;
    final own = courses.where((course) => course.instituteId == institute.id);
    if (own.isEmpty) return false;
    return own.any(
      (course) =>
          course.mode == _mode ||
          course.batches.any((batch) => (batch.mode ?? course.mode) == _mode),
    );
  }

  List<({Course course, CourseBatch batch})> _matchingClasses(
    List<Course> courses,
    List<Institute> institutes,
    DiscoveryLocation location,
  ) {
    final rows = ClassFeedQuery(
      text: _query,
      filter: _classFilter,
      ongoingToday: _ongoingToday,
      fullOrWaitlistOnly: _waitlistOnly,
      maxFee: _maxFee,
      city: location.hasCity ? location.city : null,
    ).apply(courses);
    if (!location.hasCoordinates) return rows;
    return rows.where((row) {
      Institute? institute;
      for (final item in institutes) {
        if (item.id == row.course.instituteId) {
          institute = item;
          break;
        }
      }
      if (institute == null) return true;
      final km = _distanceKm(institute, location);
      if (km == null) return true;
      return km <= location.radiusKm;
    }).toList();
  }

  static bool _hasParking(Institute institute) =>
      institute.amenities.any((item) => item.toLowerCase().contains('park'));

  static double? _lowestFee(Institute institute, List<Course> courses) {
    double? lowest;
    for (final course in courses.where((c) => c.instituteId == institute.id)) {
      void consider(double fee) {
        if (fee <= 0) return;
        if (lowest == null || fee < lowest!) lowest = fee;
      }

      consider(course.payableAmount);
      for (final batch in course.batches) {
        consider(batch.feeAmount > 0 ? batch.feeAmount : course.payableAmount);
      }
    }
    return lowest;
  }

  static int? _discountPercent(Institute institute, List<Course> courses) {
    int? best;
    for (final course in courses.where((c) => c.instituteId == institute.id)) {
      if (course.discountAmount <= 0 || course.feeAmount <= 0) continue;
      final pct = ((course.discountAmount / course.feeAmount) * 100).round();
      if (pct <= 0) continue;
      if (best == null || pct > best) best = pct;
    }
    return best;
  }

  /// Institutes with known coordinates, nearest-first, when the user's
  /// location has coordinates too; otherwise the original (name-ordered)
  /// list is returned unchanged. Distance is real geometry (haversine via
  /// [Geolocator.distanceBetween]), never invented.
  static List<Institute> _sortByDistance(
    List<Institute> items,
    DiscoveryLocation location,
  ) {
    if (!location.hasCoordinates) return items;
    final withDistance =
        items
            .map((i) => (institute: i, distanceKm: _distanceKm(i, location)))
            .toList()
          ..sort((a, b) {
            if (a.distanceKm == null && b.distanceKm == null) return 0;
            if (a.distanceKm == null) return 1;
            if (b.distanceKm == null) return -1;
            return a.distanceKm!.compareTo(b.distanceKm!);
          });
    return withDistance.map((e) => e.institute).toList();
  }

  static double? _distanceKm(Institute institute, DiscoveryLocation location) {
    if (!location.hasCoordinates ||
        institute.latitude == null ||
        institute.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      location.latitude!,
      location.longitude!,
      institute.latitude!,
      institute.longitude!,
    );
    return meters / 1000;
  }

  List<Institute> _applySort(
    List<Institute> items,
    List<Course> courses,
    DiscoveryLocation location,
  ) {
    final copy = [...items];
    switch (_sort) {
      case _HubSort.distance:
        return _sortByDistance(copy, location);
      case _HubSort.name:
        copy.sort((a, b) => a.name.compareTo(b.name));
        return copy;
      case _HubSort.priceLow:
      case _HubSort.priceHigh:
        copy.sort((a, b) {
          final aFee = _lowestFee(a, courses);
          final bFee = _lowestFee(b, courses);
          if (aFee == null && bFee == null) return a.name.compareTo(b.name);
          if (aFee == null) return 1;
          if (bFee == null) return -1;
          final cmp = aFee.compareTo(bFee);
          return _sort == _HubSort.priceLow ? cmp : -cmp;
        });
        return copy;
    }
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const LocationPickerSheet(),
    );
  }

  void _openVoiceSearch() {
    VoiceSearchBottomSheet.show(
      context,
      onFilterApplied: (voiceResult) {
        if (voiceResult.isClearCommand) {
          _searchController.clear();
          setState(() {
            _query = '';
            _maxFee = null;
            _category = EducationCategory.all;
          });
          return;
        }
        final next = voiceResult.cleanedSearchQuery.trim();
        if (next.isNotEmpty) {
          _searchController.text = next;
        }
        setState(() {
          _query = next.isNotEmpty ? next : _query;
          if (voiceResult.maxPrice != null) {
            _maxFee = voiceResult.maxPrice;
          }
          if (voiceResult.categorySlug != null &&
              voiceResult.categorySlug != 'institutes_classes') {
            _category = EducationCategory.fromSlug(voiceResult.categorySlug);
          }
        });
      },
      onFallbackToText: () {},
    );
  }

  Future<void> _pickSlotDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _slotDate = picked);
  }

  Future<void> _pickAttendees() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Attendees')),
              for (var n = 1; n <= 8; n++)
                ListTile(
                  title: Text(n == 1 ? '1 Attendee' : '$n Attendees'),
                  selected: n == _attendees,
                  onTap: () => Navigator.pop(context, n),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _attendees = picked);
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _EducationFilterSheet(
          typeFilter: _typeFilter,
          category: _category,
          mode: _mode,
          ongoingToday: _ongoingToday,
          waitlistOnly: _waitlistOnly,
          maxFee: _maxFee,
          parkingOnly: _parkingOnly,
          onApply: (next) {
            setState(() {
              _typeFilter = next.typeFilter;
              _category = next.category;
              _classCategories = const {};
              _mode = next.mode;
              _ongoingToday = next.ongoingToday;
              _waitlistOnly = next.waitlistOnly;
              _maxFee = next.maxFee;
              _parkingOnly = next.parkingOnly;
            });
          },
        );
      },
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final institutesAsync = ref.watch(institutesProvider);
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final location = ref.watch(discoveryLocationProvider);
    final section = MainHomeSection.institutesClasses;

    final dark = Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
      canvasColor: const Color(0xFF070B14),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C3AED),
        brightness: Brightness.dark,
        surface: const Color(0xFF070B14),
      ),
    );
    return Theme(
      data: dark,
      child: Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: !enabled
          ? EmptyState(
              icon: Icons.school_outlined,
              title: l10n.educationUnavailable,
              message: l10n.educationUnavailableMessage,
            )
          : SafeArea(
              child: ResponsiveLayoutBuilder(
                builder: (context, responsive) => institutesAsync.when(
                  loading: () =>
                      _LoadingHub(padding: responsive.horizontalPadding),
                  error: (e, _) => ErrorView(
                    message: e.toString(),
                    onRetry: () {
                      ref.invalidate(institutesProvider);
                      ref.invalidate(publishedCoursesProvider);
                    },
                  ),
                  data: (allInstitutes) {
                    final courses =
                        coursesAsync.valueOrNull ?? const <Course>[];
                    final filtered = _applySort(
                      _filterInstitutes(allInstitutes, courses, location),
                      courses,
                      location,
                    );
                    final classCards = _matchingClasses(
                      courses,
                      allInstitutes,
                      location,
                    );

                    return CustomScrollView(
                      cacheExtent: 2400,
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            8,
                            responsive.horizontalPadding,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionHero(
                              liveSelected: _ongoingToday,
                              onBack: _goBack,
                              onLiveBatches: () => setState(() {
                                _ongoingToday = !_ongoingToday;
                                if (_ongoingToday) {
                                  _scope = _ListingScope.classes;
                                }
                              }),
                              onHostAcademy: () => context.push(
                                AppRoutes.ownerInstituteDashboard,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            8,
                            responsive.horizontalPadding,
                            4,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _DiscoverySearchCard(
                              controller: _searchController,
                              hint: 'Search dance, music, sports, coaching...',
                              locationLabel:
                                  '${location.hierarchyLabel} · ${location.radiusKm} km',
                              slotLabel: _slotDateLabel(_slotDate),
                              attendeesLabel: _attendees == 1
                                  ? '1 Attendee'
                                  : '$_attendees Attendees',
                              onQueryChanged: (v) => setState(() => _query = v),
                              onLocationTap: _openLocationPicker,
                              onVoiceTap: _openVoiceSearch,
                              onSlotTap: _pickSlotDate,
                              onAttendeesTap: _pickAttendees,
                              onSearch: () => FocusScope.of(context).unfocus(),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _ScopeChipRow(
                            padding: EdgeInsets.fromLTRB(
                              responsive.horizontalPadding,
                              12,
                              responsive.horizontalPadding,
                              4,
                            ),
                            scope: _scope,
                            category: _category,
                            onAllInstitutes: () => setState(() {
                              _scope = _ListingScope.institutes;
                              _category = EducationCategory.all;
                              _classCategories = const {};
                            }),
                            onAllClasses: () => setState(() {
                              _scope = _ListingScope.classes;
                              _category = EducationCategory.all;
                              _classCategories = const {};
                            }),
                            onCourses: () => context.go(AppRoutes.coursesList),
                            onCategory: (value) => setState(() {
                              _category = value;
                              _classCategories = const {};
                            }),
                            mode: _mode,
                            ongoingToday: _ongoingToday,
                            waitlistOnly: _waitlistOnly,
                            onMode: (mode) => setState(() => _mode = mode),
                            onOngoing: () => setState(() {
                              _ongoingToday = !_ongoingToday;
                              if (_ongoingToday) {
                                _scope = _ListingScope.classes;
                              }
                            }),
                            onWaitlist: () => setState(() {
                              _waitlistOnly = !_waitlistOnly;
                              if (_waitlistOnly) {
                                _scope = _ListingScope.classes;
                              }
                            }),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _QuickFilterRow(
                            padding: EdgeInsets.fromLTRB(
                              responsive.horizontalPadding,
                              8,
                              responsive.horizontalPadding,
                              4,
                            ),
                            filterCount: _activeFilterCount,
                            maxFee: _maxFee,
                            parkingOnly: _parkingOnly,
                            onFilters: _openFilters,
                            onTogglePrice: () => setState(() {
                              _maxFee = _maxFee == null ? _priceChipCap : null;
                            }),
                            onToggleParking: () =>
                                setState(() => _parkingOnly = !_parkingOnly),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            12,
                            responsive.horizontalPadding,
                            8,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _ResultsHeader(
                              title: _scope == _ListingScope.classes
                                  ? 'Classes & batches (${classCards.length})'
                                  : '${section.displayTitle} (${filtered.length})',
                              sort: _sort,
                              onSort: (value) => setState(() => _sort = value),
                            ),
                          ),
                        ),
                        if (_scope == _ListingScope.classes)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.horizontalPadding,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  key: const Key('hub-class-category-filter'),
                                  onPressed: () =>
                                      _openClassCategoryFilter(courses),
                                  icon: const Icon(Icons.checklist_rounded),
                                  label: Text(
                                    _classCategories.length > 1
                                        ? 'Categories (${_classCategories.length})'
                                        : 'Categories',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_scope == _ListingScope.classes)
                          if (classCards.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: EmptyState(
                                  icon: Icons.menu_book_outlined,
                                  title: 'No classes match',
                                  message:
                                      'Try a different category, mode or search.',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                responsive.horizontalPadding,
                                0,
                                responsive.horizontalPadding,
                                24,
                              ),
                              sliver: SliverList.separated(
                                itemCount: classCards.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) => BatchClassCard(
                                  course: classCards[i].course,
                                  batch: classCards[i].batch,
                                ),
                              ),
                            )
                        else if (filtered.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.account_balance_outlined,
                              title: l10n.noInstitutes,
                              message: l10n.noInstitutesMessage,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              responsive.horizontalPadding,
                              4,
                              responsive.horizontalPadding,
                              24,
                            ),
                            sliver: responsive.isCompact
                                ? SliverList.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (_, i) => _heroCard(
                                      filtered[i],
                                      courses,
                                      location,
                                    ),
                                  )
                                : SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount:
                                              responsive.resultsColumns,
                                          mainAxisSpacing:
                                              responsive.gridSpacing,
                                          crossAxisSpacing:
                                              responsive.gridSpacing,
                                          childAspectRatio: 0.82,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => _heroCard(
                                        filtered[i],
                                        courses,
                                        location,
                                      ),
                                      childCount: filtered.length,
                                    ),
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }

  int get _activeFilterCount {
    var n = 0;
    if (_typeFilter != null) n++;
    if (_category != EducationCategory.all || _classCategories.isNotEmpty) n++;
    if (!_includeFullAndUpcoming) n++;
    if (_mode != null) n++;
    if (_ongoingToday) n++;
    if (_waitlistOnly) n++;
    if (_maxFee != null) n++;
    if (_parkingOnly) n++;
    return n;
  }

  Widget _heroCard(
    Institute institute,
    List<Course> courses,
    DiscoveryLocation location,
  ) {
    return InstituteListingCard(
      key: Key('all-institutes-${institute.id}'),
      featuredKey: institute.isVerified
          ? Key('featured-institute-${institute.id}')
          : null,
      institute: institute,
      distanceKm: _distanceKm(institute, location),
      lowestFee: _lowestFee(institute, courses),
      discountPercent: _discountPercent(institute, courses),
    );
  }

  static String _slotDateLabel(DateTime date) {
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
}

class _LoadingHub extends StatelessWidget {
  const _LoadingHub({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonBox(height: 96, radius: 16),
      ),
    );
  }
}

class _SectionHero extends StatelessWidget {
  const _SectionHero({
    required this.liveSelected,
    required this.onBack,
    required this.onLiveBatches,
    required this.onHostAcademy,
  });

  final bool liveSelected;
  final VoidCallback onBack;
  final VoidCallback onLiveBatches;
  final VoidCallback onHostAcademy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showHostLabel = constraints.maxWidth >= 360;
        return Row(
          children: [
            IconButton(
              tooltip: AppLocalizations.of(context).back,
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
            const Expanded(
              child: Text(
                'Institutes & Classes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LiveBatchesMark(selected: liveSelected, onTap: onLiveBatches),
            const SizedBox(width: 4),
            _HostAcademyButton(onTap: onHostAcademy, showLabel: showHostLabel),
          ],
        );
      },
    );
  }
}

class _LiveBatchesMark extends StatelessWidget {
  const _LiveBatchesMark({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF5B21B6) : const Color(0xFF2E2366),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                'BATCHES',
                style: TextStyle(
                  color: Color(0xFFDDD6FE),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostAcademyButton extends StatelessWidget {
  const _HostAcademyButton({required this.onTap, required this.showLabel});

  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF2A1848),
        side: const BorderSide(color: Color(0xFF6D28D9)),
        padding: EdgeInsets.symmetric(horizontal: showLabel ? 8 : 8, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_rounded, size: 14),
          if (showLabel) ...[
            const SizedBox(width: 4),
            const Text(
              'Host Academy',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverySearchCard extends StatelessWidget {
  const _DiscoverySearchCard({
    required this.controller,
    required this.hint,
    required this.locationLabel,
    required this.slotLabel,
    required this.attendeesLabel,
    required this.onQueryChanged,
    required this.onLocationTap,
    required this.onVoiceTap,
    required this.onSlotTap,
    required this.onAttendeesTap,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String hint;
  final String locationLabel;
  final String slotLabel;
  final String attendeesLabel;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLocationTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onSlotTap;
  final VoidCallback onAttendeesTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: controller,
                    onChanged: onQueryChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: const Icon(Icons.school_rounded, size: 20),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onLocationTap,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 46,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onVoiceTap,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 40,
                    height: 46,
                    child: Icon(Icons.mic_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniSelect(
                  icon: Icons.schedule_rounded,
                  label: 'Date / Slot',
                  value: slotLabel,
                  onTap: onSlotTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniSelect(
                  icon: Icons.person_rounded,
                  label: 'Attendees',
                  value: attendeesLabel,
                  onTap: onAttendeesTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text(
                'Search Available',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSelect extends StatelessWidget {
  const _MiniSelect({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
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

class _ScopeChipRow extends StatelessWidget {
  const _ScopeChipRow({
    required this.padding,
    required this.scope,
    required this.category,
    required this.onAllInstitutes,
    required this.onAllClasses,
    required this.onCourses,
    required this.onCategory,
    required this.mode,
    required this.ongoingToday,
    required this.waitlistOnly,
    required this.onMode,
    required this.onOngoing,
    required this.onWaitlist,
  });

  final EdgeInsets padding;
  final _ListingScope scope;
  final EducationCategory category;
  final VoidCallback onAllInstitutes;
  final VoidCallback onAllClasses;
  final VoidCallback onCourses;
  final ValueChanged<EducationCategory> onCategory;
  final CourseMode? mode;
  final bool ongoingToday;
  final bool waitlistOnly;
  final ValueChanged<CourseMode?> onMode;
  final VoidCallback onOngoing;
  final VoidCallback onWaitlist;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      AnimatedCategoryChip(
        selected:
            scope == _ListingScope.institutes &&
            category == EducationCategory.all,
        emoji: '✨',
        label: 'All Education & Institutes',
        onTap: onAllInstitutes,
      ),
      AnimatedCategoryChip(
        selected:
            scope == _ListingScope.classes &&
            category == EducationCategory.all,
        emoji: '✨',
        label: 'All Classes',
        onTap: onAllClasses,
      ),
      AnimatedCategoryChip(
        selected: false,
        emoji: '📚',
        label: AppLocalizations.of(context).courses,
        onTap: onCourses,
      ),
      for (final item in EducationCategory.values.where(
        (item) => item != EducationCategory.all,
      ))
        AnimatedCategoryChip(
          selected: category == item,
          label: item.label,
          onTap: () => onCategory(item),
        ),
      ChoiceChip(
        label: const Text('All modes'),
        selected: mode == null,
        onSelected: (_) => onMode(null),
      ),
      for (final item in CourseMode.values)
        ChoiceChip(
          key: Key('education-mode-${item.name}'),
          label: Text(item.discoveryLabel),
          selected: mode == item,
          onSelected: (_) => onMode(mode == item ? null : item),
        ),
      FilterChip(
        key: const Key('education-ongoing-today'),
        label: const Text('Ongoing today'),
        selected: ongoingToday,
        onSelected: (_) => onOngoing(),
      ),
      FilterChip(
        key: const Key('education-full-waitlist'),
        label: const Text('Full / waitlist'),
        selected: waitlistOnly,
        onSelected: (_) => onWaitlist(),
      ),
    ];

    // One row on every width. Extra rows push the results off the first
    // screen. Touch, mouse, and trackpad can drag the row sideways.
    return SizedBox(
      height: 52,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                chips[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow({
    required this.padding,
    required this.filterCount,
    required this.maxFee,
    required this.parkingOnly,
    required this.onFilters,
    required this.onTogglePrice,
    required this.onToggleParking,
  });

  final EdgeInsets padding;
  final int filterCount;
  final double? maxFee;
  final bool parkingOnly;
  final VoidCallback onFilters;
  final VoidCallback onTogglePrice;
  final VoidCallback onToggleParking;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Icon(Icons.tune_rounded, size: 16),
                label: Text(
                  filterCount > 0 ? 'Filters ($filterCount)' : 'Filters',
                ),
                selected: filterCount > 0,
                onSelected: (_) => onFilters(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Text('💰', style: TextStyle(fontSize: 12)),
                label: Text(
                  maxFee != null
                      ? '≤ ${formatInr(maxFee!)}'
                      : '≤ ${formatInr(50000)}',
                ),
                selected: maxFee != null,
                onSelected: (_) => onTogglePrice(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Icon(Icons.local_parking_rounded, size: 16),
                label: const Text('Parking'),
                selected: parkingOnly,
                onSelected: (_) => onToggleParking(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.title,
    required this.sort,
    required this.onSort,
  });

  final String title;
  final _HubSort sort;
  final ValueChanged<_HubSort> onSort;

  String get _sortLabel => switch (sort) {
    _HubSort.distance => 'Distance: Nearest',
    _HubSort.name => 'Name',
    _HubSort.priceLow => 'Price: Low to High',
    _HubSort.priceHigh => 'Price: High to Low',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        PopupMenuButton<_HubSort>(
          onSelected: onSort,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _HubSort.distance,
              child: Text('📍 Distance: Nearest'),
            ),
            PopupMenuItem(value: _HubSort.name, child: Text('Name')),
            PopupMenuItem(
              value: _HubSort.priceLow,
              child: Text('💰 Price: Low to High'),
            ),
            PopupMenuItem(
              value: _HubSort.priceHigh,
              child: Text('💎 Price: High to Low'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📍', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  _sortLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDraft {
  const _FilterDraft({
    required this.typeFilter,
    required this.category,
    required this.mode,
    required this.ongoingToday,
    required this.waitlistOnly,
    required this.maxFee,
    required this.parkingOnly,
  });

  final InstituteType? typeFilter;
  final EducationCategory category;
  final CourseMode? mode;
  final bool ongoingToday;
  final bool waitlistOnly;
  final double? maxFee;
  final bool parkingOnly;
}

class _EducationFilterSheet extends StatefulWidget {
  const _EducationFilterSheet({
    required this.typeFilter,
    required this.category,
    required this.mode,
    required this.ongoingToday,
    required this.waitlistOnly,
    required this.maxFee,
    required this.parkingOnly,
    required this.onApply,
  });

  final InstituteType? typeFilter;
  final EducationCategory category;
  final CourseMode? mode;
  final bool ongoingToday;
  final bool waitlistOnly;
  final double? maxFee;
  final bool parkingOnly;
  final ValueChanged<_FilterDraft> onApply;

  @override
  State<_EducationFilterSheet> createState() => _EducationFilterSheetState();
}

class _EducationFilterSheetState extends State<_EducationFilterSheet> {
  late InstituteType? _typeFilter = widget.typeFilter;
  late EducationCategory _category = widget.category;
  late CourseMode? _mode = widget.mode;
  late bool _ongoingToday = widget.ongoingToday;
  late bool _waitlistOnly = widget.waitlistOnly;
  late final TextEditingController _maxController;
  late bool _parkingOnly = widget.parkingOnly;

  @override
  void initState() {
    super.initState();
    _maxController = TextEditingController(
      text: widget.maxFee?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.filters,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.typeAllInstitutes),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                for (final type in InstituteType.values)
                  FilterChip(
                    label: Text(type.label),
                    selected: _typeFilter == type,
                    onSelected: (_) => setState(
                      () => _typeFilter = _typeFilter == type ? null : type,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final item in EducationCategory.values)
                  FilterChip(
                    label: Text(item.label),
                    selected: _category == item,
                    onSelected: (_) => setState(() => _category = item),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('OFFLINE'),
                  selected: _mode == CourseMode.offline,
                  onSelected: (_) => setState(() {
                    _mode = _mode == CourseMode.offline
                        ? null
                        : CourseMode.offline;
                  }),
                ),
                FilterChip(
                  label: const Text('ONLINE'),
                  selected: _mode == CourseMode.online,
                  onSelected: (_) => setState(() {
                    _mode = _mode == CourseMode.online
                        ? null
                        : CourseMode.online;
                  }),
                ),
                FilterChip(
                  label: const Text('HYBRID'),
                  selected: _mode == CourseMode.hybrid,
                  onSelected: (_) => setState(() {
                    _mode = _mode == CourseMode.hybrid
                        ? null
                        : CourseMode.hybrid;
                  }),
                ),
                FilterChip(
                  label: const Text('Ongoing Today'),
                  selected: _ongoingToday,
                  onSelected: (v) => setState(() => _ongoingToday = v),
                ),
                FilterChip(
                  label: const Text('Waitlist Available'),
                  selected: _waitlistOnly,
                  onSelected: (v) => setState(() => _waitlistOnly = v),
                ),
                FilterChip(
                  label: const Text('Parking'),
                  selected: _parkingOnly,
                  onSelected: (v) => setState(() => _parkingOnly = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.maxPrice,
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.onApply(
                  _FilterDraft(
                    typeFilter: _typeFilter,
                    category: _category,
                    mode: _mode,
                    ongoingToday: _ongoingToday,
                    waitlistOnly: _waitlistOnly,
                    maxFee: double.tryParse(_maxController.text),
                    parkingOnly: _parkingOnly,
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(l10n.apply),
            ),
          ],
        ),
      ),
    );
  }
}

class InstituteListingCard extends StatelessWidget {
  const InstituteListingCard({
    super.key,
    required this.institute,
    this.featuredKey,
    this.distanceKm,
    this.lowestFee,
    this.discountPercent,
  });

  final Institute institute;
  final Key? featuredKey;
  final double? distanceKm;
  final double? lowestFee;
  final int? discountPercent;

  String get _coverUrl => institute.images.isNotEmpty
      ? institute.images.first
      : institute.logoImage;

  int get _photoCount {
    final n = institute.images.length;
    if (n > 0) return n;
    return _coverUrl.isEmpty ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoCount = _photoCount;
    return KeyedSubtree(
      key: featuredKey,
      child: GlassmorphicCard(
        borderRadius: 18,
        accentGradient: AppTheme.violetGradient,
        onTap: () => context.push(
          AppRoutes.educationInstituteDetails.replaceAll(':id', institute.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 156,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: _coverUrl, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _OverlayChip(
                      icon: Icons.school_rounded,
                      label: institute.type.label,
                    ),
                  ),
                  if (discountPercent != null && discountPercent! > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🔥 $discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                  else if (photoCount > 1)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _OverlayChip(
                        icon: Icons.photo_camera_outlined,
                        label: '1/$photoCount',
                      ),
                    ),
                  if (photoCount > 1 &&
                      discountPercent != null &&
                      discountPercent! > 0)
                    Positioned(
                      top: 42,
                      right: 10,
                      child: _OverlayChip(
                        icon: Icons.photo_camera_outlined,
                        label: '1/$photoCount',
                      ),
                    ),
                  if (distanceKm != null)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _OverlayChip(
                        icon: Icons.near_me_outlined,
                        label: '${formatDistance(distanceKm)} away',
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          institute.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (institute.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppTheme.violet,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      institute.type.label,
                      if (institute.city.isNotEmpty) institute.city,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (lowestFee != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'From ${formatInr(lowestFee!)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.violet,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A compact institute row used in the education hub and institute lists.
class InstituteCard extends StatelessWidget {
  const InstituteCard({super.key, required this.institute, this.distanceKm});

  final Institute institute;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      borderRadius: 16,
      accentGradient: AppTheme.violetGradient,
      onTap: () => context.push(
        AppRoutes.educationInstituteDetails.replaceAll(':id', institute.id),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: AppNetworkImage(
                url: institute.logoImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        institute.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (institute.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppTheme.violet,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    institute.type.label,
                    if (institute.city.isNotEmpty) institute.city,
                    if (distanceKm != null) formatDistance(distanceKm),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
