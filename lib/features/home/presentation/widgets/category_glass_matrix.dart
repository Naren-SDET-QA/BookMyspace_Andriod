import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/domain/venue.dart';
import '../home_category_catalog.dart';

/// Horizontal master-category carousel + 3D glass sub-section matrix.
class CategoryDiscoveryPanel extends StatelessWidget {
  const CategoryDiscoveryPanel({
    super.key,
    required this.sections,
    required this.selected,
    required this.pageController,
    required this.categories,
    required this.venues,
    required this.onMasterChanged,
    required this.onMasterExplore,
    required this.onSubSectionTap,
  });

  final List<MainHomeSection> sections;
  final MainHomeSection selected;
  final PageController pageController;
  final List<VenueCategory> categories;
  final List<Venue> venues;
  final ValueChanged<MainHomeSection> onMasterChanged;
  final ValueChanged<MainHomeSection> onMasterExplore;
  final void Function(MainHomeSection section, HomeSubSection sub)
      onSubSectionTap;

  int? _countFor(VenueCategory? matched) {
    if (matched == null) return null;
    final n = venues.where((v) => v.category?.slug == matched.slug).length;
    return n > 0 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Explore Verified Spaces',
          key: const Key('discovery-hero'),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Five master categories. Instant sub-section discovery. Live availability.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: pageController,
            itemCount: sections.length,
            onPageChanged: (index) => onMasterChanged(sections[index]),
            itemBuilder: (context, index) {
              final section = sections[index];
              final isSelected = section == selected;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: _MasterGlassCard(
                  key: Key('master-${section.id}'),
                  section: section,
                  selected: isSelected,
                  tiltY: isSelected
                      ? 0
                      : (index < sections.indexOf(selected) ? 0.14 : -0.14),
                  onTap: () {
                    if (isSelected) {
                      onMasterExplore(section);
                    } else {
                      onMasterChanged(section);
                      pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selected.displayTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selected.subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        if (selected == MainHomeSection.functionHalls)
          _FunctionHallsMatrix(
            section: selected,
            categories: categories,
            countFor: _countFor,
            onMasterTap: () => onMasterExplore(selected),
            onSubSectionTap: (sub) => onSubSectionTap(selected, sub),
          )
        else
          _GenericSubSectionStrip(
            section: selected,
            categories: categories,
            countFor: _countFor,
            onSubSectionTap: (sub) => onSubSectionTap(selected, sub),
          ),
      ],
    );
  }
}

class _MasterGlassCard extends StatelessWidget {
  const _MasterGlassCard({
    super.key,
    required this.section,
    required this.selected,
    required this.tiltY,
    required this.onTap,
  });

  final MainHomeSection section;
  final bool selected;
  final double tiltY;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0.72,
        duration: const Duration(milliseconds: 280),
        child: Transform(
          alignment: Alignment.center,
          transformHitTests: false,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateY(tiltY)
            ..rotateX(selected ? -0.04 : 0.02),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? section.accentColor.withValues(alpha: 0.7)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0)),
                    width: selected ? 1.8 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: section.accentColor.withValues(
                        alpha: selected ? 0.28 : 0.1,
                      ),
                      blurRadius: selected ? 22 : 10,
                      offset: Offset(0, selected ? 10 : 4),
                    ),
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: section.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              section.accentColor.withValues(alpha: 0.55),
                              (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  section.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                    color: isDark
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

class _FunctionHallsMatrix extends StatelessWidget {
  const _FunctionHallsMatrix({
    required this.section,
    required this.categories,
    required this.countFor,
    required this.onMasterTap,
    required this.onSubSectionTap,
  });

  final MainHomeSection section;
  final List<VenueCategory> categories;
  final int? Function(VenueCategory?) countFor;
  final VoidCallback onMasterTap;
  final ValueChanged<HomeSubSection> onSubSectionTap;

  @override
  Widget build(BuildContext context) {
    final cells = section.matrixCells;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = 8.0;
        final cellW = (width - gap * 2) / 3;
        final cellH = cellW.clamp(104.0, 124.0);
        return KeyedSubtree(
          key: const Key('function-halls-matrix'),
          child: Column(
            children: [
              for (var row = 0; row < 3; row++) ...[
                if (row > 0) const SizedBox(height: gap),
                SizedBox(
                  height: cellH,
                  child: Row(
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: cellW,
                          height: cellH,
                          child: row == 1 && col == 1
                              ? _GlassTile(
                                  emoji: section.emoji,
                                  label: 'Function Halls',
                                  accent: section.accentColor,
                                  selected: true,
                                  rotateX: 0,
                                  rotateY: 0,
                                  onTap: onMasterTap,
                                )
                              : _subTile(
                                  cells[row * 3 + col]!,
                                  row,
                                  col,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _subTile(HomeSubSection sub, int row, int col) {
    final matched = sub.match(categories);
    final rotateY = col == 0 ? 0.11 : (col == 2 ? -0.11 : 0.0);
    final rotateX = row == 0 ? -0.08 : (row == 2 ? 0.08 : 0.0);
    return _GlassTile(
      key: Key('sub-${sub.slug}'),
      emoji: sub.emoji,
      label: sub.label,
      accent: section.accentColor,
      selected: false,
      rotateX: rotateX,
      rotateY: rotateY,
      count: countFor(matched),
      listed: matched != null,
      onTap: () => onSubSectionTap(sub),
    );
  }
}

class _GenericSubSectionStrip extends StatelessWidget {
  const _GenericSubSectionStrip({
    required this.section,
    required this.categories,
    required this.countFor,
    required this.onSubSectionTap,
  });

  final MainHomeSection section;
  final List<VenueCategory> categories;
  final int? Function(VenueCategory?) countFor;
  final ValueChanged<HomeSubSection> onSubSectionTap;

  @override
  Widget build(BuildContext context) {
    final items = section.subSections;
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final sub = items[index];
          final matched = sub.match(categories);
          final mid = (items.length - 1) / 2;
          final rotateY = (index - mid) * -0.07;
          return SizedBox(
            width: 148,
            child: _GlassTile(
              key: Key('sub-${sub.slug}'),
              emoji: sub.emoji,
              label: sub.label,
              accent: section.accentColor,
              selected: false,
              rotateX: -0.04,
              rotateY: rotateY,
              count: countFor(matched),
              listed: matched != null,
              onTap: () => onSubSectionTap(sub),
            ),
          );
        },
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.accent,
    required this.selected,
    required this.rotateX,
    required this.rotateY,
    required this.onTap,
    this.count,
    this.listed = true,
  });

  final String emoji;
  final String label;
  final Color accent;
  final bool selected;
  final double rotateX;
  final double rotateY;
  final VoidCallback onTap;
  final int? count;
  final bool listed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glass = isDark
        ? Colors.white.withValues(alpha: selected ? 0.14 : 0.08)
        : Colors.white.withValues(alpha: selected ? 0.88 : 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Transform(
          alignment: Alignment.center,
          transformHitTests: false,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(rotateX)
            ..rotateY(rotateY)
            ..scaleByDouble(
              selected ? 1.04 : 1.0,
              selected ? 1.04 : 1.0,
              1.0,
              1.0,
            ),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.75)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.9)),
                width: selected ? 1.6 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.16 : 0.55),
                  accent.withValues(alpha: selected ? 0.28 : 0.08),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: selected ? 0.32 : 0.1),
                  blurRadius: selected ? 18 : 10,
                  offset: Offset(0, selected ? 8 : 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(2, 6),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: theme.colorScheme.onSurface,
                      fontSize: selected ? 12 : 11,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$count listed',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if (!listed) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Browse',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
