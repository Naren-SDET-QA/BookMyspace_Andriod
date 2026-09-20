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
import '../../../home/presentation/widgets/home_feed_sections.dart'
    show HomeLocationBanner;
import '../../../home/presentation/widgets/location_picker_sheet.dart';
import '../../../location/presentation/gps_session.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart'
    show formatDistance;
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';

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
  const EducationHubScreen({super.key});

  @override
  ConsumerState<EducationHubScreen> createState() => _EducationHubScreenState();
}

class _EducationHubScreenState extends ConsumerState<EducationHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  InstituteType? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Institute> _filterInstitutes(List<Institute> items) {
    final query = _query.trim().toLowerCase();
    return items.where((institute) {
      final matchesType = _typeFilter == null || institute.type == _typeFilter;
      final matchesQuery = query.isEmpty ||
          institute.name.toLowerCase().contains(query) ||
          institute.city.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();
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
    final withDistance = items
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

  static double? _distanceKm(
    Institute institute,
    DiscoveryLocation location,
  ) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final institutesAsync = ref.watch(institutesProvider);
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final location = ref.watch(discoveryLocationProvider);
    final gpsPhase = ref.watch(gpsSessionProvider.select((s) => s.phase));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.education),
        actions: [
          IconButton(
            tooltip: l10n.myCourses,
            icon: const Icon(Icons.backpack_rounded),
            onPressed: () => context.push(AppRoutes.myCourses),
          ),
        ],
      ),
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
                    final sortedInstitutes =
                        _sortByDistance(allInstitutes, location);
                    final filtered = _filterInstitutes(sortedInstitutes);
                    final featured = sortedInstitutes
                        .where((i) => i.isVerified)
                        .take(6)
                        .toList();
                    final popularCourses =
                        coursesAsync.valueOrNull?.take(8).toList() ??
                            const <Course>[];

                    return CustomScrollView(
                      slivers: [
                        // TEMP DEBUG (remove after confirming new UI is mounted):
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            color: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: const Text(
                              'NEW_EDUCATION_UI_ACTIVE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            8,
                            responsive.horizontalPadding,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: HomeLocationBanner(
                              cityLabel: location.label,
                              radiusKm: location.radiusKm,
                              source: location.source,
                              gpsPhase: gpsPhase,
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (context) =>
                                    const LocationPickerSheet(),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            12,
                            responsive.horizontalPadding,
                            4,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SearchAndBrowse(
                              controller: _searchController,
                              hint: l10n.courseSearchHint,
                              browseAllLabel: l10n.courses,
                              onChanged: (v) => setState(() => _query = v),
                              onBrowseAll: () =>
                                  context.go(AppRoutes.coursesList),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            12,
                            responsive.horizontalPadding,
                            4,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _TypeChipRow(
                              selected: _typeFilter,
                              l10n: l10n,
                              onSelected: (t) =>
                                  setState(() => _typeFilter = t),
                            ),
                          ),
                        ),
                        if (featured.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              responsive.horizontalPadding,
                              16,
                              responsive.horizontalPadding,
                              8,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: l10n.featuredInstitutes,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 168,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(
                                  horizontal: responsive.horizontalPadding,
                                ),
                                itemCount: featured.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) => SizedBox(
                                  width: 260,
                                  child: _FeaturedInstituteCard(
                                    key: Key(
                                        'featured-institute-${featured[i].id}'),
                                    institute: featured[i],
                                    distanceKm:
                                        _distanceKm(featured[i], location),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (popularCourses.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              responsive.horizontalPadding,
                              20,
                              responsive.horizontalPadding,
                              8,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: l10n.popularCourses,
                                actionLabel: l10n.seeAll,
                                onAction: () =>
                                    context.go(AppRoutes.coursesList),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 268,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(
                                  horizontal: responsive.horizontalPadding,
                                ),
                                itemCount: popularCourses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) => SizedBox(
                                  width: 220,
                                  child: CourseCard(course: popularCourses[i]),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            responsive.horizontalPadding,
                            20,
                            responsive.horizontalPadding,
                            4,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _SectionHeader(title: l10n.institutes),
                          ),
                        ),
                        if (filtered.isEmpty)
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
                                    itemBuilder: (_, i) => InstituteCard(
                                      key: Key(
                                          'all-institutes-${filtered[i].id}'),
                                      institute: filtered[i],
                                      distanceKm:
                                          _distanceKm(filtered[i], location),
                                    ),
                                  )
                                : SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: responsive.resultsColumns,
                                      mainAxisSpacing: responsive.gridSpacing,
                                      crossAxisSpacing: responsive.gridSpacing,
                                      childAspectRatio: 3.1,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => InstituteCard(
                                        key: Key(
                                            'all-institutes-${filtered[i].id}'),
                                        institute: filtered[i],
                                        distanceKm:
                                            _distanceKm(filtered[i], location),
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
    );
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

class _SearchAndBrowse extends StatelessWidget {
  const _SearchAndBrowse({
    required this.controller,
    required this.hint,
    required this.browseAllLabel,
    required this.onChanged,
    required this.onBrowseAll,
  });

  final TextEditingController controller;
  final String hint;
  final String browseAllLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onBrowseAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassmorphicCard(
          borderRadius: 16,
          accentGradient: AppTheme.violetGradient,
          onTap: onBrowseAll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppTheme.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  browseAllLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeChipRow extends StatelessWidget {
  const _TypeChipRow({
    required this.selected,
    required this.l10n,
    required this.onSelected,
  });

  final InstituteType? selected;
  final AppLocalizations l10n;
  final ValueChanged<InstituteType?> onSelected;

  String _label(InstituteType? type) => switch (type) {
        null => l10n.typeAllInstitutes,
        InstituteType.privateInstitute => l10n.typePrivate,
        InstituteType.stateGovernment => l10n.typeStateGovernment,
        InstituteType.centralGovernment => l10n.typeCentralGovernment,
        InstituteType.university => l10n.typeUniversity,
        InstituteType.ngo => l10n.typeNgo,
        InstituteType.other => l10n.typeOther,
      };

  @override
  Widget build(BuildContext context) {
    final options = <InstituteType?>[
      null,
      InstituteType.privateInstitute,
      InstituteType.stateGovernment,
      InstituteType.centralGovernment,
      InstituteType.university,
      InstituteType.ngo,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final option = options[i];
          return AnimatedCategoryChip(
            selected: selected == option,
            label: _label(option),
            onTap: () => onSelected(option),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _FeaturedInstituteCard extends StatelessWidget {
  const _FeaturedInstituteCard(
      {super.key, required this.institute, this.distanceKm});

  final Institute institute;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      borderRadius: 18,
      accentGradient: AppTheme.violetGradient,
      onTap: () => context.push(
        AppRoutes.instituteDetails.replaceAll(':id', institute.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: AppNetworkImage(
                url: institute.logoImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 16, color: AppTheme.violet),
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
        AppRoutes.instituteDetails.replaceAll(':id', institute.id),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child:
                  AppNetworkImage(url: institute.logoImage, fit: BoxFit.cover),
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
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (institute.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 16, color: AppTheme.violet),
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
