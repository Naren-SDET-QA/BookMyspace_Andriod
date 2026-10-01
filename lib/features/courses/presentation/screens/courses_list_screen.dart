import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/presentation/discovery_location.dart';
import '../../domain/class_category_filter.dart';
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import '../course_providers.dart';
import '../widgets/batch_class_card.dart';
import '../widgets/class_category_filter_sheet.dart';
import '../widgets/course_card.dart';

/// All published courses with category selector, delivery mode filter,
/// quick toggles for "Ongoing Today" and "Waitlist Available", and
/// search matching class title, subject, institute name, instructor,
/// or location.
class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  EducationCategory _category = EducationCategory.all;
  CourseMode? _mode;
  bool _ongoingToday = false;
  bool _waitlistOnly = false;
  bool _showBatches = false;

  /// Multi-category selection from the filter sheet. When non-empty it takes
  /// precedence over the single [_category] chip.
  Set<EducationCategory> _multiCategories = const {};
  bool _includeFullAndUpcoming = true;

  Set<EducationCategory> get _effectiveCategories {
    if (_multiCategories.isNotEmpty) return _multiCategories;
    if (_category != EducationCategory.all) return {_category};
    return const {};
  }

  ClassCategoryFilter get _filter => ClassCategoryFilter(
    categories: _effectiveCategories,
    mode: _mode,
    includeFullAndUpcoming: _includeFullAndUpcoming,
  );

  int get _sheetFilterCount {
    var n = _effectiveCategories.length;
    if (_mode != null) n++;
    if (!_includeFullAndUpcoming) n++;
    return n;
  }

  Future<void> _openFilterSheet(List<Course> items) async {
    final result = await showClassCategoryFilterSheet(
      context,
      initial: _filter,
      courses: items,
    );
    if (result == null || !mounted) return;
    setState(() {
      _mode = result.mode;
      _includeFullAndUpcoming = result.includeFullAndUpcoming;
      if (result.categories.length == 1) {
        _category = result.categories.first;
        _multiCategories = const {};
      } else {
        _category = EducationCategory.all;
        _multiCategories = result.categories;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Course> _applyFilters(List<Course> items) {
    final query = _query.trim().toLowerCase();
    final filter = _filter;
    return items.where((course) {
      if (!filter.matchesCourse(course)) return false;
      if (query.isEmpty) return true;
      return course.title.toLowerCase().contains(query) ||
          course.instituteName.toLowerCase().contains(query) ||
          course.instructorName.toLowerCase().contains(query) ||
          course.description.toLowerCase().contains(query);
    }).toList();
  }

  List<({Course course, CourseBatch batch})> _matchingBatches(
    List<Course> courses,
    DiscoveryLocation location,
  ) {
    return ClassFeedQuery(
      text: _query,
      filter: _filter,
      ongoingToday: _ongoingToday,
      fullOrWaitlistOnly: _waitlistOnly,
      city: location.hasCity ? location.city : null,
    ).apply(courses);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final courses = ref.watch(publishedCoursesProvider);
    final location = ref.watch(discoveryLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.courses),
        actions: [
          IconButton(
            key: const Key('courses-filter-button'),
            tooltip: 'Filter classes',
            onPressed: () =>
                _openFilterSheet(courses.valueOrNull ?? const <Course>[]),
            icon: Badge(
              isLabelVisible: _sheetFilterCount > 0,
              label: Text('$_sheetFilterCount'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          IconButton(
            tooltip: l10n.institutes,
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => context.push(AppRoutes.education),
          ),
          IconButton(
            tooltip: l10n.myCourses,
            icon: const Icon(Icons.backpack_outlined),
            onPressed: () => context.push(AppRoutes.myCourses),
          ),
        ],
      ),
      body: courses.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: 4,
          itemBuilder: (context, i) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: SkeletonBox(height: 220, radius: 18),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(publishedCoursesProvider),
        ),
        data: (items) {
          final filtered = _applyFilters(items);
          final batchCards = _matchingBatches(items, location);
          return ResponsiveLayoutBuilder(
            builder: (context, responsive) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  12,
                  responsive.horizontalPadding,
                  4,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchField(
                        controller: _searchController,
                        hintText: 'Search classes, institutes, instructors...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 12),
                      _CategoryChips(
                        selected: _category,
                        multi: _multiCategories,
                        onSelected: (c) => setState(() {
                          _category = c;
                          _multiCategories = const {};
                        }),
                      ),
                      const SizedBox(height: 10),
                      _ModeFilterRow(
                        selectedMode: _mode,
                        ongoingToday: _ongoingToday,
                        waitlistOnly: _waitlistOnly,
                        onModeSelected: (m) => setState(() {
                          _mode = _mode == m ? null : m;
                        }),
                        onOngoingToggle: () =>
                            setState(() => _ongoingToday = !_ongoingToday),
                        onWaitlistToggle: () =>
                            setState(() => _waitlistOnly = !_waitlistOnly),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            _showBatches
                                ? 'Batches (${batchCards.length})'
                                : '${l10n.courses} (${filtered.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          _ViewToggle(
                            showBatches: _showBatches,
                            onToggle: (v) => setState(() => _showBatches = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.school_rounded,
                    title: l10n.noCourses,
                    message: l10n.noCoursesMessage,
                  ),
                )
              else if (_showBatches)
                if (batchCards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'No batches match',
                      message: 'Try a different category, mode or search term.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.horizontalPadding,
                      8,
                      responsive.horizontalPadding,
                      16,
                    ),
                    sliver: SliverList.separated(
                      itemCount: batchCards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => BatchClassCard(
                        course: batchCards[i].course,
                        batch: batchCards[i].batch,
                      ),
                    ),
                  )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SearchEmptyState(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.horizontalPadding,
                    4,
                    responsive.horizontalPadding,
                    16,
                  ),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) =>
                        CourseCard(course: filtered[i]),
                  ),
                ),
            ],
          ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.onSelected,
    this.multi = const {},
  });

  final EducationCategory selected;
  final Set<EducationCategory> multi;
  final ValueChanged<EducationCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in EducationCategory.values)
          ChoiceChip(
            label: Text(category.label),
            selected: multi.isNotEmpty
                ? multi.contains(category)
                : category == selected,
            onSelected: (_) => onSelected(category),
            showCheckmark: false,
            selectedColor: AppTheme.violet,
            labelStyle: TextStyle(
              color: (multi.isNotEmpty
                      ? multi.contains(category)
                      : category == selected)
                  ? Colors.white
                  : null,
              fontWeight: (multi.isNotEmpty
                      ? multi.contains(category)
                      : category == selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: (multi.isNotEmpty
                        ? multi.contains(category)
                        : category == selected)
                    ? AppTheme.violet
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeFilterRow extends StatelessWidget {
  const _ModeFilterRow({
    required this.selectedMode,
    required this.ongoingToday,
    required this.waitlistOnly,
    required this.onModeSelected,
    required this.onOngoingToggle,
    required this.onWaitlistToggle,
  });

  final CourseMode? selectedMode;
  final bool ongoingToday;
  final bool waitlistOnly;
  final ValueChanged<CourseMode> onModeSelected;
  final VoidCallback onOngoingToggle;
  final VoidCallback onWaitlistToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All modes'),
              selected: selectedMode == null,
              onSelected: (_) {
                if (selectedMode != null) onModeSelected(selectedMode!);
              },
            ),
          ),
          for (final mode in CourseMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('courses-mode-${mode.name}'),
                label: Text(mode.discoveryLabel),
                selected: selectedMode == mode,
                onSelected: (_) => onModeSelected(mode),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: const Key('courses-ongoing-today'),
              label: const Text('Ongoing today'),
              selected: ongoingToday,
              onSelected: (_) => onOngoingToggle(),
            ),
          ),
          FilterChip(
            key: const Key('courses-full-waitlist'),
            label: const Text('Full / waitlist'),
            selected: waitlistOnly,
            onSelected: (_) => onWaitlistToggle(),
          ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.showBatches, required this.onToggle});

  final bool showBatches;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(
            icon: Icons.view_list_rounded,
            label: 'Courses',
            selected: !showBatches,
            onTap: () => onToggle(false),
            theme: theme,
          ),
          _toggleBtn(
            icon: Icons.calendar_view_day_rounded,
            label: 'Batches',
            selected: showBatches,
            onTap: () => onToggle(true),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.violet : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Try a different search term or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
