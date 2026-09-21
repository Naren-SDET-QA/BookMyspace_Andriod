import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/interactive_tilt_card.dart';
import '../../../venues/domain/venue.dart';
import '../home_category_catalog.dart';
import '../../../cms/domain/cms_banner.dart';
import '../../../ai_booking/presentation/widgets/ai_booking_sheet.dart';

/// Responsive category discovery panel with master carousel + sub-section grid.
///
/// Handles all breakpoints from 320px mobile to 1440px desktop:
/// - Mobile (< 600px): 2-column grid for sub-sections, compact master cards
/// - Tablet (600-840px): 2-3 column grid, wider master cards
/// - Desktop (840-1200px): 3-4 column grid
/// - Extra-wide (1200px+): 4 column grid
enum _ViewMode {
  matrix3d('UI 1: 3D Matrix'),
  grid('UI 2: Standard Grid'),
  list('UI 3: Compact List');

  const _ViewMode(this.label);
  final String label;
}

class CategoryDiscoveryPanel extends StatefulWidget {
  const CategoryDiscoveryPanel({
    super.key,
    required this.sections,
    required this.selected,
    required this.categories,
    this.dynamicSubsections = const [],
    required this.venues,
    required this.onMasterChanged,
    required this.onMasterExplore,
    required this.onSubSectionTap,
    required this.onExploreAll,
    this.isLoadingLiveData = false,
    this.categoryImageBySlot = const {},
  });

  final List<MainHomeSection> sections;
  final MainHomeSection selected;
  final List<VenueCategory> categories;

  /// Admin-managed `venue_subsections` rows. When any of them belong to a
  /// section (via its category's parent mapping), they replace the static
  /// fallback sub-sections for that section so owner-created subsections
  /// surface on customer discovery without a Flutter change.
  final List<VenueSubsection> dynamicSubsections;
  final List<Venue> venues;
  final ValueChanged<MainHomeSection> onMasterChanged;
  final ValueChanged<MainHomeSection> onMasterExplore;
  final void Function(MainHomeSection section, HomeSubSection sub)
      onSubSectionTap;
  final VoidCallback onExploreAll;

  /// True while the categories/venues this panel renders from are still
  /// being fetched by the caller's providers. Drives the skeleton state
  /// instead of ever showing fabricated placeholder categories.
  final bool isLoadingLiveData;

  /// Active `cms_banners` rows keyed by `slot`, from
  /// [activeCmsBannersBySlotProvider]. When a section's [MainHomeSection.imageSlot]
  /// has an entry here with a non-empty `imageUrl`, that CMS-configured
  /// image is used instead of the stock-photo [MainHomeSection.fallbackImageUrl].
  final Map<String, CmsBanner> categoryImageBySlot;

  @override
  State<CategoryDiscoveryPanel> createState() => _CategoryDiscoveryPanelState();
}

class _CategoryDiscoveryPanelState extends State<CategoryDiscoveryPanel> {
  // Persists for the lifetime of this widget instance (i.e. across the
  // rebuilds that happen when the user picks a different category or the
  // surrounding Home screen refreshes) -- not reset on every rebuild.
  _ViewMode _mode = _ViewMode.matrix3d;

  List<HomeSubSection> _subsectionsFor(MainHomeSection section) {
    // Function Halls discovery is frozen to the shipped cells
    // (Marriage Halls, Banquet Halls, etc.). Live CMS/master categories
    // and admin-managed venue_subsections must not replace that matrix.
    if (section == MainHomeSection.functionHalls) {
      return section.subSections;
    }
    final categoriesById = <String, VenueCategory>{
      for (final category in widget.categories) category.id: category,
    };
    final managed = widget.dynamicSubsections.where((subsection) {
      final category = categoriesById[subsection.categoryId];
      return category != null && _categoryBelongsToSection(category, section);
    }).map(
      (subsection) => HomeSubSection(
        label: subsection.name,
        emoji: subsection.icon?.isNotEmpty == true
            ? subsection.icon!
            : categoriesById[subsection.categoryId]?.icon ?? section.emoji,
        slug: subsection.slug,
      ),
    );
    final items = <HomeSubSection>[...managed];
    for (final category in widget.categories) {
      if (!category.isActive || !_categoryBelongsToSection(category, section)) {
        continue;
      }
      if (items.any(
          (item) => item.slug.toLowerCase() == category.slug.toLowerCase())) {
        continue;
      }
      items.add(
        HomeSubSection(
          label: category.name,
          emoji: category.icon?.isNotEmpty == true ? category.icon! : '🏷️',
          slug: category.slug,
        ),
      );
    }
    if (items.isEmpty) return section.subSections;
    return items;
  }

  bool _categoryBelongsToSection(
    VenueCategory category,
    MainHomeSection section,
  ) {
    final parent = category.parentSection?.toLowerCase();
    if (parent != null && section.parentSectionAliases.contains(parent)) {
      return true;
    }
    final slug = category.slug.toLowerCase();
    if (section.searchAliases.contains(slug)) return true;
    return switch (section) {
      MainHomeSection.functionHalls => slug.contains('hall'),
      MainHomeSection.lodgeRooms =>
        slug.contains('hotel') || slug.contains('lodge'),
      MainHomeSection.pgHostels =>
        slug.contains('pg') || slug.contains('hostel'),
      MainHomeSection.institutesClasses =>
        slug.contains('class') || slug.contains('coaching'),
      MainHomeSection.sportsTurfs =>
        slug.contains('sport') || slug.contains('turf'),
    };
  }

  int? _countFor(VenueCategory? matched) {
    if (matched == null) return null;
    final n =
        widget.venues.where((v) => v.category?.slug == matched.slug).length;
    return n > 0 ? n : null;
  }

  /// CMS image first, stock-photo fallback second -- never a random
  /// unrelated image, and the fallback is always the SAME photo per
  /// section (stable), never randomized per rebuild.
  String _imageFor(MainHomeSection section) {
    final banner = widget.categoryImageBySlot[section.imageSlot];
    final cmsUrl = banner?.imageUrl;
    if (banner != null &&
        banner.isActive &&
        cmsUrl != null &&
        cmsUrl.isNotEmpty) {
      // Cache-bust on every republish: append the banner's own updated_at
      // (or id, if that's ever missing) as a query param so the browser /
      // CachedNetworkImage cache key changes the moment an admin publishes
      // a new image, instead of continuing to show stale cached bytes at
      // the same URL.
      final bust =
          banner.updatedAt?.millisecondsSinceEpoch.toString() ?? banner.id;
      final separator = cmsUrl.contains('?') ? '&' : '?';
      return '$cmsUrl${separator}v=$bust';
    }
    return section.fallbackImageUrl;
  }

  CmsCategoryStyle _styleFor(MainHomeSection section) {
    return CmsCategoryStyle.resolve(
        section, widget.categoryImageBySlot[section.imageSlot]);
  }

  int _liveCountFor(MainHomeSection section) {
    return widget.venues
        .where((v) =>
            section.searchAliases.contains(v.category?.slug) ||
            v.category?.parentSection == section.id)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final sections = widget.sections;
    final selected = widget.selected;

    void handleMasterTap(MainHomeSection section) {
      if (section == selected) {
        widget.onMasterExplore(section);
        return;
      }
      widget.onMasterChanged(section);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const Key('discovery-hero'),
          children: [
            Expanded(
              child: Text(
                'Inside this category',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _UiModeSelector(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          selected.displayTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // All master categories render here -- every enabled section gets
        // its own card, in whichever layout `_mode` currently picks. This
        // replaces the single-selected-card regression: `sections` (passed
        // in by HomeScreen, already CMS/module-flag filtered) drives every
        // mode below, none of them ever show just one item.
        if (widget.isLoadingLiveData)
          _SkeletonCards(
              mode: _mode, count: sections.length, compact: isCompact)
        else if (sections.isEmpty)
          const _EmptyCategoriesState()
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_mode),
              child: switch (_mode) {
                _ViewMode.matrix3d => _MatrixCardRow(
                    sections: sections,
                    selected: selected,
                    compact: isCompact,
                    onTap: handleMasterTap,
                    imageFor: _imageFor,
                    styleFor: _styleFor,
                    liveCountFor: _liveCountFor,
                  ),
                _ViewMode.grid => _MatrixCardGrid(
                    sections: sections,
                    selected: selected,
                    liveCountFor: _liveCountFor,
                    onTap: handleMasterTap,
                    styleFor: _styleFor,
                  ),
                _ViewMode.list => _MatrixListColumn(
                    sections: sections,
                    selected: selected,
                    liveCountFor: _liveCountFor,
                    onTap: handleMasterTap,
                    styleFor: _styleFor,
                  ),
              },
            ),
          ),
        SizedBox(height: isCompact ? 12 : 16),

        // Detail card for the currently-selected/highlighted section --
        // carries the "Verified Venues" / "Live Spaces" badges, full
        // description and Explore action the reference shows on the
        // expanded card, without hiding every other category to get there.
        _MasterHeroCard(
          key: ValueKey('master-hero-${selected.id}'),
          section: selected,
          style: _styleFor(selected),
          compact: isCompact,
          liveCount: _liveCountFor(selected),
          onExplore: () => widget.onMasterExplore(selected),
        ),
        SizedBox(height: isCompact ? 14 : 16),

        // Sub-section grid. Function Halls always uses shipped cells;
        // other sections use admin-managed subsections, then live
        // categories, then shipped fallbacks -- see _subsectionsFor.
        _ResponsiveSubSectionGrid(
          section: selected,
          items: _subsectionsFor(selected),
          categories: widget.categories,
          countFor: _countFor,
          onMasterTap: () => widget.onMasterExplore(selected),
          onSubSectionTap: (sub) => widget.onSubSectionTap(selected, sub),
        ),
      ],
    );
  }
}

/// Static "UI 1: 3D Matrix" tag. Describes the real, currently-active
/// discovery layout (the tilted glass carousel below). Not a dropdown menu
/// with alternate non-functional options -- there is only one layout today.
/// Functional layout-mode selector: 3D Matrix / Standard Grid / Compact
/// List. Built on [PopupMenuButton] so it gets keyboard navigation (Tab to
/// focus, Enter/Space to open, arrow keys + Enter to pick) and screen-reader
/// semantics for free from Material, rather than a fake dropdown that only
/// looks interactive.
class _UiModeSelector extends StatelessWidget {
  const _UiModeSelector({required this.mode, required this.onChanged});

  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Discovery layout: ${mode.label}',
      child: PopupMenuButton<_ViewMode>(
        key: const Key('discovery-layout-menu'),
        tooltip: 'Change discovery layout',
        initialValue: mode,
        onSelected: onChanged,
        offset: const Offset(0, 32),
        itemBuilder: (context) => [
          for (final m in _ViewMode.values)
            PopupMenuItem<_ViewMode>(
              value: m,
              child: Row(
                children: [
                  if (m == mode)
                    Icon(Icons.check_rounded,
                        size: 16, color: theme.colorScheme.tertiary)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Icon(
          Icons.tune_rounded,
          size: 22,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Mode 1 (3D Matrix): horizontal scroll of every section as a tilted glass
/// card -- restores the original carousel-style rendering (all sections,
/// not just the selected one), just without page-snap/PageController.
class _MatrixCardRow extends StatelessWidget {
  const _MatrixCardRow({
    required this.sections,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.imageFor,
    required this.styleFor,
    required this.liveCountFor,
  });

  final List<MainHomeSection> sections;
  final MainHomeSection selected;
  final bool compact;
  final ValueChanged<MainHomeSection> onTap;
  final String Function(MainHomeSection) imageFor;
  final CmsCategoryStyle Function(MainHomeSection) styleFor;
  final int Function(MainHomeSection) liveCountFor;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 112.0 : 140.0;
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < sections.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: SizedBox(
                  width: compact ? 148 : 190,
                  child: _MasterGlassCard(
                    key: Key('master-${sections[index].id}'),
                    section: sections[index],
                    imageUrl: imageFor(sections[index]),
                    style: styleFor(sections[index]),
                    selected: sections[index] == selected,
                    tiltY: sections[index] == selected
                        ? 0
                        : (index < sections.indexOf(selected) ? 0.14 : -0.14),
                    compact: compact,
                    liveCount: liveCountFor(sections[index]),
                    onTap: () => onTap(sections[index]),
                    onAiHelp: () => AiBookingSheet.show(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mode 2 (Standard Grid): every section as a flat glass card in a
/// responsive grid -- 2 columns mobile/tablet, 3-5 columns desktop.
class _MatrixCardGrid extends StatelessWidget {
  const _MatrixCardGrid({
    required this.sections,
    required this.selected,
    required this.liveCountFor,
    required this.onTap,
    required this.styleFor,
  });

  final List<MainHomeSection> sections;
  final MainHomeSection selected;
  final int Function(MainHomeSection) liveCountFor;
  final ValueChanged<MainHomeSection> onTap;
  final CmsCategoryStyle Function(MainHomeSection) styleFor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 600
        ? 2
        : width < 900
            ? 2
            : width < 1200
                ? 3
                : width < 1440
                    ? 4
                    : 5;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final section = sections[index];
        return _MasterGridTile(
          section: section,
          style: styleFor(section),
          selected: section == selected,
          liveCount: liveCountFor(section),
          onTap: () => onTap(section),
        );
      },
    );
  }
}

class _MasterGridTile extends StatelessWidget {
  const _MasterGridTile({
    required this.section,
    required this.style,
    required this.selected,
    required this.liveCount,
    required this.onTap,
  });

  final MainHomeSection section;
  final CmsCategoryStyle style;
  final bool selected;
  final int liveCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = style.accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${section.displayTitle}, $liveCount live spaces',
        child: InteractiveTiltCard(
          onTap: onTap,
          semanticLabel: section.displayTitle,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: (selected ? accent : theme.colorScheme.outline)
                  .withValues(alpha: selected ? 0.16 : 0.06),
              border: Border.all(
                color: accent.withValues(alpha: selected ? 0.65 : 0.25),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (style.icon != null)
                  Icon(style.icon, size: 22, color: accent)
                else
                  Text(section.emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                Text(
                  section.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$liveCount live',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mode 3 (Compact List): every section as a single-line row.
class _MatrixListColumn extends StatelessWidget {
  const _MatrixListColumn({
    required this.sections,
    required this.selected,
    required this.liveCountFor,
    required this.onTap,
    required this.styleFor,
  });

  final List<MainHomeSection> sections;
  final MainHomeSection selected;
  final int Function(MainHomeSection) liveCountFor;
  final ValueChanged<MainHomeSection> onTap;
  final CmsCategoryStyle Function(MainHomeSection) styleFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final section in sections)
          Builder(builder: (context) {
            final style = styleFor(section);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: (section == selected
                          ? style.accentColor
                          : theme.colorScheme.outline)
                      .withValues(alpha: section == selected ? 0.14 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(section),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          if (style.icon != null)
                            Icon(style.icon, size: 18, color: style.accentColor)
                          else
                            Text(section.emoji,
                                style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              section.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${liveCountFor(section)} live',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: style.badgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Skeleton placeholders shown only while the caller's providers are still
/// loading real category/venue data -- never fabricated categories.
class _SkeletonCards extends StatelessWidget {
  const _SkeletonCards({
    required this.mode,
    required this.count,
    required this.compact,
  });

  final _ViewMode mode;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
    );
    if (mode == _ViewMode.list) {
      return Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(height: 44, child: placeholder),
            ),
        ],
      );
    }
    return SizedBox(
      height: compact ? 112 : 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: SizedBox(
            width: compact ? 148 : 190,
            child: placeholder,
          ),
        ),
      ),
    );
  }
}

/// Shown only when the caller genuinely has zero sections to offer (e.g.
/// every master category disabled by CMS) -- never silently blank.
class _EmptyCategoriesState extends StatelessWidget {
  const _EmptyCategoriesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.category_outlined,
              size: 28, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No categories are available right now.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "Verified Venues" + "N Live Spaces" badge row shown above the selected
/// master category title. Both values come from real data: "Verified
/// Venues" reflects that every listed venue goes through the existing
/// owner-approval flow (no separate verification count is stored per
/// section), and the live count is the real number of matching venues
/// passed in by the caller.
class _LiveCountBadgeRow extends StatelessWidget {
  const _LiveCountBadgeRow({
    required this.liveCount,
    required this.compact,
    required this.accentColor,
  });

  final int liveCount;
  final bool compact;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        _MiniBadge(
          icon: Icons.verified_rounded,
          label: 'Verified Venues',
          color: accentColor,
          compact: compact,
        ),
        _MiniBadge(
          icon: Icons.circle,
          iconSize: 8,
          label: '$liveCount Live Space${liveCount == 1 ? '' : 's'}',
          color: theme.colorScheme.tertiary,
          compact: compact,
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
    this.iconSize,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize ?? (compact ? 12 : 13), color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single static glass card for the selected master section, replacing the
/// swipeable carousel. Selection is driven entirely by [_MasterChipRow]
/// above; this card just renders whichever [section] is currently selected,
/// with real live-venue badges, description and an Explore action -- same
/// content the old carousel card + title/subtitle block used to show,
/// just laid out as one persistent card per the reference.
class _MasterHeroCard extends StatelessWidget {
  const _MasterHeroCard({
    super.key,
    required this.section,
    required this.style,
    required this.compact,
    required this.liveCount,
    required this.onExplore,
  });

  final MainHomeSection section;
  final CmsCategoryStyle style;
  final bool compact;
  final int liveCount;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = style.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InteractiveTiltCard(
        onTap: onExplore,
        semanticLabel: '${section.displayTitle}, explore',
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                style.gradientStart.withValues(alpha: isDark ? 0.28 : 0.16),
                style.gradientEnd.withValues(alpha: isDark ? 0.32 : 0.22),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LiveCountBadgeRow(
                liveCount: liveCount,
                compact: compact,
                accentColor: style.badgeColor,
              ),
              SizedBox(height: compact ? 14 : 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 44 : 52,
                    height: compact ? 44 : 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: style.icon != null
                        ? Icon(style.icon,
                            size: compact ? 22 : 26, color: accent)
                        : Text(section.emoji,
                            style: TextStyle(fontSize: compact ? 20 : 24)),
                  ),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (compact
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          section.subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onExplore,
                  style: TextButton.styleFrom(foregroundColor: accent),
                  icon: const Text('Explore'),
                  label: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Master category card in the horizontal carousel.
class _MasterGlassCard extends StatelessWidget {
  const _MasterGlassCard({
    super.key,
    required this.section,
    required this.imageUrl,
    required this.style,
    required this.selected,
    required this.tiltY,
    required this.onTap,
    this.compact = false,
    this.liveCount = 0,
    this.onAiHelp,
  });

  final MainHomeSection section;
  final String imageUrl;
  final CmsCategoryStyle style;
  final bool selected;
  final double tiltY;
  final VoidCallback onTap;
  final bool compact;
  final int liveCount;
  final VoidCallback? onAiHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Snap instantly (zero-duration) instead of animating the
    // selected/unselected scale+fade transition when the platform's
    // reduced-motion setting is on -- same MediaQuery check InteractiveTiltCard
    // uses for its own hover/press transform below.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: selected ? 1.0 : 0.9,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0.72,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
        child: Transform(
          alignment: Alignment.center,
          transformHitTests: false,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateY(tiltY)
            ..rotateX(selected ? -0.04 : 0.02),
          child: InteractiveTiltCard(
            onTap: onTap,
            semanticLabel: section.displayTitle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? style.accentColor.withValues(alpha: 0.7)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0)),
                  width: selected ? 1.8 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: style.accentColor.withValues(
                      alpha: selected ? 0.28 : 0.1,
                    ),
                    blurRadius: selected ? 22 : 10,
                    offset: Offset(0, selected ? 10 : 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
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
                      url: imageUrl,
                      fit: BoxFit.cover,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            style.gradientStart.withValues(alpha: 0.55),
                            style.gradientEnd.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (style.icon != null)
                            Icon(style.icon,
                                size: compact ? 20 : 22, color: Colors.white)
                          else
                            Text(section.emoji,
                                style: TextStyle(fontSize: compact ? 18 : 20)),
                          SizedBox(height: compact ? 6 : 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                section.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: (compact
                                        ? theme.textTheme.labelLarge
                                        : theme.textTheme.titleSmall)
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Live count badge — top-right corner
                    if (liveCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$liveCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // AI Help chip — bottom-right, only on selected card
                    if (selected && onAiHelp != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onAiHelp,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: style.accentColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      style.accentColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'AI Help',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive sub-section grid that adapts columns to available width.
///
/// Mobile (< 600px): 2 columns
/// Tablet (600-840px): 3 columns
/// Desktop (840-1200px): 4 columns
/// Extra-wide (1200px+): 5 columns
class _ResponsiveSubSectionGrid extends StatelessWidget {
  const _ResponsiveSubSectionGrid({
    required this.section,
    required this.items,
    required this.categories,
    required this.countFor,
    required this.onMasterTap,
    required this.onSubSectionTap,
  });

  final MainHomeSection section;
  final List<HomeSubSection> items;
  final List<VenueCategory> categories;
  final int? Function(VenueCategory?) countFor;
  final VoidCallback onMasterTap;
  final ValueChanged<HomeSubSection> onSubSectionTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;

    final isFunctionHalls = section == MainHomeSection.functionHalls;

    // Compute responsive grid parameters
    final int columns;
    final double spacing;
    if (isCompact) {
      columns = 2;
      spacing = 8;
    } else if (width < 840) {
      columns = 3;
      spacing = 10;
    } else if (width < 1200) {
      columns = 4;
      spacing = 12;
    } else {
      columns = 5;
      spacing = 14;
    }

    // For function halls with many sub-sections, use the full grid.
    // For sections with few sub-sections, use a horizontal strip on mobile.
    if (isFunctionHalls || items.length > 5) {
      return _buildGrid(
        context,
        items: items,
        columns: columns,
        spacing: spacing,
        isCompact: isCompact,
      );
    }

    // Few items: horizontal scroll strip on mobile, grid on tablet+
    if (isCompact) {
      return _buildHorizontalStrip(
        context,
        items: items,
        spacing: spacing,
      );
    }

    return _buildGrid(
      context,
      items: items,
      columns: columns > items.length ? items.length : columns,
      spacing: spacing,
      isCompact: isCompact,
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required List<HomeSubSection> items,
    required int columns,
    required double spacing,
    required bool isCompact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cellWidth = (availableWidth - spacing * (columns - 1)) / columns;
        // Maintain roughly 1:1 to 1:1.15 aspect ratio for the cards
        final cellHeight = cellWidth * (isCompact ? 1.1 : 1.08);

        // Preserve the key used by existing tests
        final gridKey = section == MainHomeSection.functionHalls
            ? const Key('function-halls-matrix')
            : Key('sub-grid-${section.id}');
        return KeyedSubtree(
          key: gridKey,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _buildSubTile(items[i], i, items.length),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalStrip(
    BuildContext context, {
    required List<HomeSubSection> items,
    required double spacing,
  }) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 130,
            child: _buildSubTile(items[index], index, items.length),
          );
        },
      ),
    );
  }

  Widget _buildSubTile(HomeSubSection sub, int index, int total) {
    final matched = sub.match(categories);
    return _GlassTile(
      key: Key('sub-${sub.slug}'),
      emoji: sub.emoji,
      label: sub.label,
      accent: section.accentColor,
      selected: false,
      count: countFor(matched),
      listed: matched != null,
      onTap: () => onSubSectionTap(sub),
    );
  }
}

/// Individual glassmorphic sub-section tile.
///
/// Interaction (tilt, hover, press, keyboard activation, reduced-motion,
/// focus ring) is fully delegated to [InteractiveTiltCard] -- the same
/// shared wrapper the five master category cards use in every mode -- so a
/// sub-category tile behaves identically to a master tile. Only the visual
/// decoration below (glass fill, gradient, border, shadow) is specific to
/// this tile, and its resting-state values are unchanged from before.
class _GlassTile extends StatelessWidget {
  const _GlassTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.count,
    this.listed = true,
  });

  final String emoji;
  final String label;
  final Color accent;
  final bool selected;
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

    return Semantics(
      button: true,
      selected: selected,
      label: count != null ? '$label, $count listed' : label,
      child: InteractiveTiltCard(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              // Constrained text to prevent overflow with long names
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 34),
                child: Text(
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
              ),
              if (count != null) ...[
                const SizedBox(height: 4),
                _MiniBadge(
                  icon: Icons.circle,
                  iconSize: 6,
                  label: '$count listed',
                  color: accent,
                  compact: true,
                ),
              ] else if (!listed) ...[
                const SizedBox(height: 4),
                _MiniBadge(
                  icon: Icons.explore_outlined,
                  iconSize: 10,
                  label: 'Browse',
                  color: theme.colorScheme.onSurfaceVariant,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
