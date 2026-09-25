import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/interactive_tilt_card.dart';
import '../../../admin/domain/admin_settings.dart';
import '../../../promotions/domain/promotion.dart';
import '../../../promotions/presentation/promotion_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/customer_section_catalog.dart';
import '../../domain/home_category_catalog.dart';

/// Presentation-only search entry point for the release Home screen.
///
/// Search is forwarded to the existing SearchScreen route. This widget does
/// not own search state, location state, or any backend contract.
class HomeV2SearchBlock extends StatefulWidget {
  const HomeV2SearchBlock({
    super.key,
    required this.locationLabel,
    required this.onSubmit,
    required this.onBrowse,
    this.onLocationTap,
    this.onVoiceTap,
  });

  final String locationLabel;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBrowse;
  final VoidCallback? onLocationTap;
  final VoidCallback? onVoiceTap;

  @override
  State<HomeV2SearchBlock> createState() => _HomeV2SearchBlockState();
}

class _HomeV2SearchBlockState extends State<HomeV2SearchBlock> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      enableEntrance: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Find a space that fits your plan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Open search',
                onPressed: widget.onBrowse,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Search spaces, events, classes, PGs...',
              prefixIcon: const Icon(Icons.travel_explore_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onVoiceTap != null)
                    IconButton(
                      tooltip: 'Search by voice',
                      onPressed: widget.onVoiceTap,
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: _submit,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (widget.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: widget.onLocationTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Showing options around ${widget.locationLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_location_alt_rounded,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Release-native discovery shortcuts backed by the existing home category
/// configuration and existing router destinations.
class HomeV2DiscoverySection extends StatelessWidget {
  const HomeV2DiscoverySection({
    super.key,
    required this.categories,
    required this.locationLabel,
    required this.onCategoryTap,
    required this.onSpacesTap,
    required this.onInstitutesTap,
    required this.onClassesTap,
    required this.onEventsTap,
    required this.onMapTap,
    this.heroSubtitle,
  });

  final List<HomeCategoryItem> categories;
  final String locationLabel;
  final ValueChanged<HomeCategoryItem> onCategoryTap;
  final VoidCallback onSpacesTap;
  final VoidCallback onInstitutesTap;
  final VoidCallback onClassesTap;
  final VoidCallback? onEventsTap;
  final VoidCallback? onMapTap;
  final String? heroSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = heroSubtitle?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Verified Spaces',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle == null || subtitle.isEmpty
              ? (locationLabel.isEmpty
                    ? 'Choose a category to start exploring.'
                    : 'Curated options near $locationLabel')
              : subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        HomeV2CategoryGrid(
          categories: categories,
          onCategoryTap: onCategoryTap,
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _HomeV2QuickCard(
                icon: Icons.apartment_rounded,
                title: 'Spaces',
                subtitle: 'Halls & stays',
                onTap: onSpacesTap,
              ),
              const SizedBox(width: 10),
              _HomeV2QuickCard(
                icon: Icons.school_rounded,
                title: 'Institutes',
                subtitle: 'Find a course',
                onTap: onInstitutesTap,
              ),
              const SizedBox(width: 10),
              _HomeV2QuickCard(
                icon: Icons.auto_stories_rounded,
                title: 'Classes',
                subtitle: 'Learn nearby',
                onTap: onClassesTap,
              ),
              if (onEventsTap != null) ...[
                const SizedBox(width: 10),
                _HomeV2QuickCard(
                  icon: Icons.event_outlined,
                  title: 'Events',
                  subtitle: 'See what\'s on',
                  onTap: onEventsTap!,
                ),
              ],
              if (onMapTap != null) ...[
                const SizedBox(width: 10),
                _HomeV2QuickCard(
                  icon: Icons.map_outlined,
                  title: 'View on map',
                  subtitle: 'Browse nearby',
                  onTap: onMapTap!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A single modern banner surface backed by the existing promotion provider
/// and the existing admin-configured Home banner values.
class HomeV2PromotionBanner extends ConsumerStatefulWidget {
  const HomeV2PromotionBanner({super.key, required this.settings, this.onTap});

  final Map<String, dynamic> settings;
  final VoidCallback? onTap;

  @override
  ConsumerState<HomeV2PromotionBanner> createState() =>
      _HomeV2PromotionBannerState();
}

class _HomeV2PromotionBannerState extends ConsumerState<HomeV2PromotionBanner> {
  late final PageController _pageController;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promotions = ref.watch(activePromotionsProvider);
    return promotions.maybeWhen(
      data: (items) => items.isEmpty
          ? _configuredBanner(context)
          : _promotionCarousel(context, items),
      orElse: () => _configuredBanner(context),
    );
  }

  Widget _promotionCarousel(BuildContext context, List<Promotion> items) {
    final visible = items.take(10).toList(growable: false);
    if (_activePage >= visible.length) {
      _activePage = 0;
    }
    return Column(
      children: [
        SizedBox(
          height: 154,
          child: PageView.builder(
            controller: _pageController,
            itemCount: visible.length,
            onPageChanged: (index) => setState(() => _activePage = index),
            itemBuilder: (context, index) => _HomeV2PromotionCard(
              promotion: visible[index],
              onTap: widget.onTap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HomeV2PageIndicators(count: visible.length, active: _activePage),
      ],
    );
  }

  Widget _configuredBanner(BuildContext context) {
    final theme = Theme.of(context);
    final text = AdminSettings.text(
      widget.settings['banner_text'],
      'Find and book a space that works for you.',
    );
    final media = widget.settings['banner_media_url']?.toString() ?? '';
    final background = AdminSettings.color(
      widget.settings['banner_background'],
      theme.colorScheme.primaryContainer,
    );
    final foreground = AdminSettings.color(
      widget.settings['banner_text_color'],
      theme.colorScheme.onPrimaryContainer,
    );

    return Column(
      children: [
        GlassmorphicCard(
          enableEntrance: false,
          onTap: widget.onTap,
          surfaceColor: background,
          surfaceAlpha: 0.92,
          accentGradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 126),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SPONSORED',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 17,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        FilledButton.tonal(
                          onPressed: widget.onTap,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Explore now'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (media.isNotEmpty)
                  SizedBox(
                    width: 116,
                    height: 108,
                    child: AppNetworkImage(url: media, fit: BoxFit.cover),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 52,
                      color: foreground.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _HomeV2PageIndicators(count: 1, active: 0),
      ],
    );
  }
}

class _HomeV2PageIndicators extends StatelessWidget {
  const _HomeV2PageIndicators({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: index == active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}

class _HomeV2PromotionCard extends StatelessWidget {
  const _HomeV2PromotionCard({required this.promotion, this.onTap});

  final Promotion promotion;
  final VoidCallback? onTap;

  static Color _parseColor(String? value, Color fallback) {
    if (value == null || value.isEmpty) return fallback;
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return fallback;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;
    return hex.length == 6 ? Color(0xFF000000 | parsed) : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = _parseColor(
      promotion.backgroundColor,
      theme.colorScheme.primaryContainer,
    );
    final foreground = _parseColor(
      promotion.textColor,
      theme.colorScheme.onPrimaryContainer,
    );
    final accent = _parseColor(
      promotion.accentColor,
      theme.colorScheme.primary,
    );

    return GlassmorphicCard(
      enableEntrance: false,
      onTap: onTap,
      surfaceColor: background,
      surfaceAlpha: 0.92,
      accentGradient: LinearGradient(
        colors: [accent, theme.colorScheme.secondary],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Text(
                (promotion.icon?.isNotEmpty ?? false) ? promotion.icon! : '✨',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((promotion.badge ?? '').isNotEmpty)
                  Text(
                    promotion.badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                Text(
                  promotion.title.isEmpty
                      ? 'BookMySpace promotion'
                      : promotion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  promotion.shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground.withValues(alpha: 0.84)),
                ),
                if (promotion.ctaText.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton.tonal(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          promotion.ctaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

class HomeV2CategoryGrid extends StatefulWidget {
  const HomeV2CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  final List<HomeCategoryItem> categories;
  final ValueChanged<HomeCategoryItem> onCategoryTap;

  @override
  State<HomeV2CategoryGrid> createState() => _HomeV2CategoryGridState();
}

class _HomeV2CategoryGridState extends State<HomeV2CategoryGrid> {
  static const _primaryCategoryCount = 6;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final categories = _showAll
        ? widget.categories
        : widget.categories.take(_primaryCategoryCount).toList();
    final hasMore = widget.categories.length > _primaryCategoryCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final category in categories)
              SizedBox(
                width: width,
                child: _HomeV2CategoryCard(
                  key: ValueKey('section_${category.id}'),
                  category: category,
                  index: widget.categories.indexOf(category),
                  onTap: () => widget.onCategoryTap(category),
                ),
              ),
            if (hasMore)
              SizedBox(
                width: width,
                child: _HomeV2MoreCard(
                  expanded: _showAll,
                  onTap: () => setState(() => _showAll = !_showAll),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeV2MoreCard extends StatelessWidget {
  const _HomeV2MoreCard({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InteractiveTiltCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: expanded ? 'Show fewer categories' : 'More categories',
      child: GlassmorphicCard(
        enableEntrance: false,
        isInteractive: false,
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(
                    expanded ? Icons.expand_less_rounded : Icons.apps_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  expanded ? 'Show less' : 'More categories',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeV2CategoryCard extends StatelessWidget {
  const _HomeV2CategoryCard({
    super.key,
    required this.category,
    required this.index,
    required this.onTap,
  });

  final HomeCategoryItem category;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = CustomerSection.fromId(
      category.sectionId.isEmpty
          ? category.configuration.slug
          : category.sectionId,
    );
    final accents = [
      AppTheme.brand,
      const Color(0xFF0F766E),
      const Color(0xFFEA580C),
      const Color(0xFF7C3AED),
    ];
    final accent = accents[index % accents.length];

    return InteractiveTiltCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: category.title,
      child: GlassmorphicCard(
        enableEntrance: false,
        isInteractive: false,
        accentGradient: LinearGradient(
          colors: [accent, theme.colorScheme.secondary],
        ),
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Text(
                    category.configuration.icon.isEmpty
                        ? '✨'
                        : category.configuration.icon,
                    style: const TextStyle(fontSize: 25),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section?.subtitle ?? 'Explore verified spaces nearby',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeV2ActivityCard extends StatelessWidget {
  const HomeV2ActivityCard({
    super.key,
    required this.locationLabel,
    required this.verifiedCount,
    required this.onLocationTap,
  });

  final String locationLabel;
  final int verifiedCount;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      enableEntrance: false,
      padding: const EdgeInsets.all(14),
      accentGradient: LinearGradient(
        colors: [theme.colorScheme.tertiary, theme.colorScheme.primary],
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.radar_rounded,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE SPACE RADAR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$verifiedCount verified spaces available near $locationLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change location',
            onPressed: onLocationTap,
            icon: const Icon(Icons.edit_location_alt_rounded),
          ),
        ],
      ),
    );
  }
}

/// Nearby discovery powered by the existing location-aware venue provider.
/// The card owns no venue data or navigation contract; callers provide the
/// already-loaded value and the existing route callbacks.
class HomeV2SpaceDiscovery extends StatelessWidget {
  const HomeV2SpaceDiscovery({
    super.key,
    required this.locationLabel,
    required this.venues,
    required this.onViewAll,
    required this.onVenueTap,
    this.onRetry,
  });

  final String locationLabel;
  final AsyncValue<List<Venue>> venues;
  final VoidCallback onViewAll;
  final ValueChanged<Venue> onVenueTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Space Radar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    locationLabel.isEmpty
                        ? 'Discover popular spaces near you'
                        : 'Discover popular spaces near $locationLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 246,
          child: venues.when(
            data: (items) {
              if (items.isEmpty) {
                return _HomeV2DiscoveryMessage(
                  message: 'No nearby spaces are available yet.',
                  actionLabel: 'Browse all',
                  onAction: onViewAll,
                );
              }
              return ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                itemCount: items.take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final venue = items[index];
                  return _HomeV2VenueCard(
                    venue: venue,
                    onTap: () => onVenueTap(venue),
                  );
                },
              );
            },
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const _HomeV2VenueSkeleton(),
            ),
            error: (_, _) => _HomeV2DiscoveryMessage(
              message: 'Nearby spaces could not be loaded.',
              actionLabel: onRetry == null ? null : 'Try again',
              onAction: onRetry,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeV2VenueCard extends ConsumerWidget {
  const _HomeV2VenueCard({required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final location = venue.city.isNotEmpty
        ? venue.city
        : venue.addressLine1.isNotEmpty
        ? venue.addressLine1
        : 'Nearby';
    return SizedBox(
      width: 246,
      child: InteractiveTiltCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        semanticLabel: venue.name,
        child: GlassmorphicCard(
          enableEntrance: false,
          isInteractive: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 118,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: venue.coverImageUrl,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: favorite.when(
                        data: (value) => FavoriteButton(
                          isFavorite: value ?? false,
                          onPressed: () =>
                              ref.read(toggleFavoriteProvider(venue.id).future),
                        ),
                        loading: () => const FavoriteButton(
                          isFavorite: false,
                          onPressed: null,
                        ),
                        error: (_, _) => const FavoriteButton(
                          isFavorite: false,
                          onPressed: null,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (venue.isVerified) const VerifiedBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (venue.avgRating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            venue.avgRating.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (venue.ratingCount > 0)
                            Text(
                              ' (${venue.ratingCount})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                        const Spacer(),
                        Text(
                          venue.price > 0
                              ? formatInr(venue.price)
                              : 'Price on request',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

class _HomeV2VenueSkeleton extends StatelessWidget {
  const _HomeV2VenueSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 246,
      child: GlassmorphicCard(
        enableEntrance: false,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const SizedBox(height: 118),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 160,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: 100,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeV2DiscoveryMessage extends StatelessWidget {
  const _HomeV2DiscoveryMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      enableEntrance: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.explore_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Quick access to live customer activity without introducing a second data
/// source. The destination screens remain the source of booking/favourite
/// counts and all authorization decisions.
class HomeV2ActivitySection extends StatelessWidget {
  const HomeV2ActivitySection({
    super.key,
    required this.onBookingsTap,
    required this.onSavedTap,
  });

  final VoidCallback onBookingsTap;
  final VoidCallback onSavedTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      enableEntrance: false,
      padding: const EdgeInsets.all(14),
      accentGradient: LinearGradient(
        colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Activity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Quick access to your bookings and saved spaces',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HomeV2ActivityTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Recent Bookings',
                  subtitle: 'View and manage your bookings',
                  onTap: onBookingsTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeV2ActivityTile(
                  icon: Icons.favorite_rounded,
                  title: 'Saved Spaces',
                  subtitle: 'Your favourite venues',
                  onTap: onSavedTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeV2ActivityTile extends StatelessWidget {
  const _HomeV2ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InteractiveTiltCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: '$title, $subtitle',
      child: GlassmorphicCard(
        enableEntrance: false,
        isInteractive: false,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeV2QuickCard extends StatelessWidget {
  const _HomeV2QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 154,
      child: InteractiveTiltCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        semanticLabel: '$title, $subtitle',
        child: GlassmorphicCard(
          enableEntrance: false,
          isInteractive: false,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
