import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';

/// A course-listing filter chip. `null` means "All"; [free] means the
/// fee-free filter (real data via [Course.isFree]) rather than a delivery
/// mode.
class _CourseFilter {
  const _CourseFilter({this.mode, this.free = false});

  final CourseMode? mode;
  final bool free;

  static const all = _CourseFilter();

  bool matches(Course course) {
    if (free) return course.isFree;
    if (mode != null) return course.mode == mode;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is _CourseFilter && other.mode == mode && other.free == free;

  @override
  int get hashCode => Object.hash(mode, free);
}

/// All published courses, newest first.
///
/// Layout matches the reference design's spacing and section structure: a
/// search field over the list, a row of filter chips, then a section header
/// with a live count before the card list. Search and filters run entirely
/// client-side over the already-fetched [Course] data (title text match,
/// delivery mode, and the real [Course.isFree] flag) -- no rating,
/// distance or discount data exists to filter or sort by, so those controls
/// from the reference are intentionally omitted.
class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _CourseFilter _filter = _CourseFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Course> _applyFilters(List<Course> items) {
    final query = _query.trim().toLowerCase();
    return items.where((course) {
      if (!_filter.matches(course)) return false;
      if (query.isEmpty) return true;
      return course.title.toLowerCase().contains(query) ||
          course.instituteName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final courses = ref.watch(publishedCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.courses),
        actions: [
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
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CourseSearchField(
                        controller: _searchController,
                        hintText: l10n.courseSearchHint,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 12),
                      _CourseFilterChips(
                        selected: _filter,
                        onSelected: (f) => setState(() => _filter = f),
                        l10n: l10n,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.courses} (${filtered.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
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
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SearchEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) =>
                        CourseCard(course: filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseSearchField extends StatelessWidget {
  const _CourseSearchField({
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _CourseFilterChips extends StatelessWidget {
  const _CourseFilterChips({
    required this.selected,
    required this.onSelected,
    required this.l10n,
  });

  final _CourseFilter selected;
  final ValueChanged<_CourseFilter> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final options = <(String, _CourseFilter)>[
      (l10n.filterAllCourses, _CourseFilter.all),
      (l10n.modeOnline, const _CourseFilter(mode: CourseMode.online)),
      (l10n.modeOffline, const _CourseFilter(mode: CourseMode.offline)),
      (l10n.modeHybrid, const _CourseFilter(mode: CourseMode.hybrid)),
      (l10n.freeEvent, const _CourseFilter(free: true)),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, filter) = options[i];
          final isSelected = filter == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            selectedColor: AppTheme.violet,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.violet
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
