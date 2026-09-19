import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/interactive_tilt_card.dart';
import '../../../venues/domain/venue.dart';
import '../home_category_catalog.dart';

/// Responsive category discovery panel with master carousel + sub-section grid.
///
/// Handles all breakpoints from 320px mobile to 1440px desktop:
/// - Mobile (< 600px): 2-column grid for sub-sections, compact master cards
/// - Tablet (600-840px): 2-3 column grid, wider master cards
/// - Desktop (840-1200px): 3-4 column grid
/// - Extra-wide (1200px+): 4 column grid
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
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;
    final isMedium = width >= 600 && width < 840;
    // Responsive master carousel card sizing
    final masterCardHeight = isCompact ? 110.0 : (isMedium ? 126.0 : 140.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section heading
        Text(
          'Explore Verified Spaces',
          key: const Key('discovery-hero'),
          style: (isCompact
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineMedium)
              ?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Text(
          'Five master categories. Instant sub-section discovery. Live availability.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: isCompact ? 14 : 18),

        // Master category carousel
        SizedBox(
          height: masterCardHeight,
          child: PageView.builder(
            controller: pageController,
            itemCount: sections.length,
            onPageChanged: (index) => onMasterChanged(sections[index]),
            padEnds: isCompact,
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
                  compact: isCompact,
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
        SizedBox(height: isCompact ? 8 : 12),

        // Selected section title + subtitle
        Text(
          selected.displayTitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (isCompact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge)
              ?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 32),
          child: Text(
            selected.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 14 : 16),

        // Sub-section grid
        _ResponsiveSubSectionGrid(
          section: selected,
          categories: categories,
          countFor: _countFor,
          onMasterTap: () => onMasterExplore(selected),
          onSubSectionTap: (sub) => onSubSectionTap(selected, sub),
        ),
      ],
    );
  }
}

/// Master category card in the horizontal carousel.
class _MasterGlassCard extends StatelessWidget {
  const _MasterGlassCard({
    super.key,
    required this.section,
    required this.selected,
    required this.tiltY,
    required this.onTap,
    this.compact = false,
  });

  final MainHomeSection section;
  final bool selected;
  final double tiltY;
  final VoidCallback onTap;
  final bool compact;

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
          child: InteractiveTiltCard(
            onTap: onTap,
            semanticLabel: section.displayTitle,
            child: DecoratedBox(
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
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;

    final items = section.subSections;
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
class _GlassTile extends StatefulWidget {
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
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final glass = isDark
        ? Colors.white.withValues(alpha: widget.selected ? 0.14 : 0.08)
        : Colors.white.withValues(alpha: widget.selected ? 0.88 : 0.7);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..translateByDouble(
              0.0,
              _pressed ? 2.0 : (_hovered ? -3.0 : 0.0),
              0.0,
              1.0,
            )
            ..scaleByDouble(
              _pressed
                  ? 0.96
                  : (_hovered ? 1.04 : (widget.selected ? 1.04 : 1.0)),
              _pressed
                  ? 0.96
                  : (_hovered ? 1.04 : (widget.selected ? 1.04 : 1.0)),
              1.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected
                  ? widget.accent.withValues(alpha: 0.75)
                  : (_hovered
                      ? widget.accent.withValues(alpha: 0.45)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.9))),
              width: widget.selected || _hovered ? 1.6 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.16 : 0.55),
                widget.accent.withValues(alpha: widget.selected ? 0.28 : 0.08),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(
                    alpha: _hovered ? 0.22 : (widget.selected ? 0.32 : 0.1)),
                blurRadius: _hovered ? 16 : (widget.selected ? 18 : 10),
                offset: Offset(0, _hovered ? 6 : (widget.selected ? 8 : 4)),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                blurRadius: 12,
                offset: const Offset(2, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                // Constrained text to prevent overflow with long names
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 34),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: theme.colorScheme.onSurface,
                      fontSize: widget.selected ? 12 : 11,
                    ),
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${widget.count} listed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ] else if (!widget.listed) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Browse',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
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
}
