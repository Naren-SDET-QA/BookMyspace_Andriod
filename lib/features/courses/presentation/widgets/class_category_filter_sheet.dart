import 'package:flutter/material.dart';

import '../../domain/class_category_filter.dart';
import '../../domain/course.dart';
import '../../domain/education_category.dart';

/// Opens the multi-category checkbox filter and resolves with the applied
/// filter, or `null` when dismissed.
Future<ClassCategoryFilter?> showClassCategoryFilterSheet(
  BuildContext context, {
  required ClassCategoryFilter initial,
  required List<Course> courses,
}) {
  return showModalBottomSheet<ClassCategoryFilter>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ClassCategoryFilterSheet(
      initial: initial,
      counts: ClassCategoryFilter.batchCounts(courses),
    ),
  );
}

IconData _categoryIcon(EducationCategory category) => switch (category) {
  EducationCategory.all => Icons.apps_rounded,
  EducationCategory.coaching => Icons.cast_for_education_rounded,
  EducationCategory.sportsFitness => Icons.sports_basketball_rounded,
  EducationCategory.academics => Icons.school_rounded,
  EducationCategory.techCoding => Icons.code_rounded,
  EducationCategory.dance => Icons.music_note_rounded,
  EducationCategory.musicArts => Icons.brush_rounded,
};

String _categoryHint(EducationCategory category) => switch (category) {
  EducationCategory.all => '',
  EducationCategory.coaching => 'Tuition, JEE, NEET, exam prep',
  EducationCategory.sportsFitness => 'Badminton, cricket, football, yoga',
  EducationCategory.academics => 'Maths, science, school subjects',
  EducationCategory.techCoding => 'Python, Java, Flutter, bootcamps',
  EducationCategory.dance => 'Classical, contemporary, hip hop',
  EducationCategory.musicArts => 'Vocal, guitar, piano, painting',
};

class ClassCategoryFilterSheet extends StatefulWidget {
  const ClassCategoryFilterSheet({
    super.key,
    required this.initial,
    required this.counts,
  });

  final ClassCategoryFilter initial;
  final Map<EducationCategory, int> counts;

  @override
  State<ClassCategoryFilterSheet> createState() =>
      _ClassCategoryFilterSheetState();
}

class _ClassCategoryFilterSheetState extends State<ClassCategoryFilterSheet> {
  late ClassCategoryFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = ClassCategoryFilter.selectable;
    final sectionStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter classes',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Select multiple categories to refine batches',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text(
                '${_draft.categories.length} of ${options.length} selected',
                key: const Key('class-filter-selected-count'),
                style: theme.textTheme.bodySmall,
              ),
              Wrap(
                children: [
                  TextButton(
                    key: const Key('class-filter-select-all'),
                    onPressed: () =>
                        setState(() => _draft = _draft.selectAll()),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    key: const Key('class-filter-clear-all'),
                    onPressed: () => setState(() => _draft = _draft.clearAll()),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          Text('CATEGORIES', style: sectionStyle),
          const SizedBox(height: 4),
          for (final category in options)
            CheckboxListTile(
              key: Key('class-filter-category-${category.slug}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _draft.categories.contains(category),
              onChanged: (_) =>
                  setState(() => _draft = _draft.toggle(category)),
              secondary: Icon(_categoryIcon(category)),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _CountBadge(count: widget.counts[category] ?? 0),
                ],
              ),
              subtitle: Text(
                _categoryHint(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Divider(),
          Text('DELIVERY MODE', style: sectionStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final mode in CourseMode.values)
                FilterChip(
                  key: Key('class-filter-mode-${mode.name}'),
                  avatar: Icon(switch (mode) {
                    CourseMode.offline => Icons.location_on_outlined,
                    CourseMode.online => Icons.laptop_rounded,
                    CourseMode.hybrid => Icons.devices_rounded,
                  }, size: 16),
                  label: Text(mode.name.toUpperCase()),
                  selected: _draft.mode == mode,
                  onSelected: (_) => setState(() {
                    _draft = _draft.mode == mode
                        ? _draft.copyWith(clearMode: true)
                        : _draft.copyWith(mode: mode);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('class-filter-include-full'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Include full & upcoming (waitlist)'),
            subtitle: const Text(
              'Show batches that are full or not yet open, so you can join '
              'the waitlist',
            ),
            value: _draft.includeFullAndUpcoming,
            onChanged: (v) => setState(
              () => _draft = _draft.copyWith(includeFullAndUpcoming: v),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('class-filter-apply'),
            onPressed: () => Navigator.of(context).pop(_draft),
            child: const Text('Apply filters'),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        count == 1 ? '1 batch' : '$count batches',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
