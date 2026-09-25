import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../home_category_catalog.dart';

/// "Explore" showcase shown under the Explore categories row on Home:
/// a 2-column category grid, a promo banner, the Space Radar venue strip
/// and quick links to the reader's own activity.
///
/// Every tile routes to an existing, working screen; venue-backed tiles go
/// through [onOpenSection] so they share Home's search/location wiring.
class HomeExploreShowcase extends ConsumerWidget {
  const HomeExploreShowcase({
    super.key,
    required this.venues,
    required this.locationLabel,
    required this.onOpenSection,
    required this.onExploreAll,
  });

  /// Venues for the Space Radar strip (nearby first, else popular).
  final List<Venue> venues;

  /// Current discovery location label, e.g. "Hyderabad".
  final String locationLabel;
  final ValueChanged<MainHomeSection> onOpenSection;
  final VoidCallback onExploreAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <_ShowcaseTile>[
      _ShowcaseTile(
        key: 'spaces',
        title: 'Spaces',
        subtitle: 'Halls, Venues & Event Spaces',
        icon: Icons.account_balance_rounded,
        accent: const Color(0xFF2563EB),
        onTap: () => onOpenSection(MainHomeSection.functionHalls),
      ),
      _ShowcaseTile(
        key: 'institutes',
        title: 'Institutes',
        subtitle: 'Find courses & coaching',
        icon: Icons.school_rounded,
        accent: const Color(0xFF7C3AED),
        onTap: () => context.push(AppRoutes.education),
      ),
      _ShowcaseTile(
        key: 'classes',
        title: 'Classes',
        subtitle: 'Dance, Music & Skill Training',
        icon: Icons.co_present_rounded,
        accent: const Color(0xFF059669),
        onTap: () => context.push(AppRoutes.coursesList),
      ),
      _ShowcaseTile(
        key: 'pg',
        title: 'PG / Hostels',
        subtitle: 'Comfortable Living Spaces',
        icon: Icons.bed_rounded,
        accent: const Color(0xFFEA580C),
        onTap: () => onOpenSection(MainHomeSection.pgHostels),
      ),
      _ShowcaseTile(
        key: 'stays',
        title: 'Stays',
        subtitle: 'Hotels, Guest Houses & Day Rooms',
        icon: Icons.apartment_rounded,
        accent: const Color(0xFFDB2777),
        onTap: () => onOpenSection(MainHomeSection.lodgeRooms),
      ),
      _ShowcaseTile(
        key: 'sports',
        title: 'Sports',
        subtitle: 'Turfs, Courts & Arenas',
        icon: Icons.sports_soccer_rounded,
        accent: const Color(0xFFCA8A04),
        onTap: () => onOpenSection(MainHomeSection.sportsTurfs),
      ),
    ];

    return Column(
      key: const Key('home-explore-showcase'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryGrid(tiles: tiles),
        const SizedBox(height: 20),
        _PromoBanner(
          imageUrl: venues
              .map((v) => v.coverOrSampleImageUrl)
              .firstWhere((u) => u.isNotEmpty, orElse: () => ''),
          onExplore: onExploreAll,
        ),
        const SizedBox(height: 20),
        _SpaceRadar(
          venues: venues,
          locationLabel: locationLabel,
          onViewAll: onExploreAll,
        ),
        const SizedBox(height: 20),
        const _YourActivity(),
      ],
    );
  }
}

class _ShowcaseTile {
  const _ShowcaseTile({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.tiles});

  final List<_ShowcaseTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on phones, 3 on wider layouts.
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: _CategoryTileCard(tile: tile),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTileCard extends StatelessWidget {
  const _CategoryTileCard({required this.tile});

  final _ShowcaseTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      tile.accent.withValues(alpha: isDark ? 0.18 : 0.08),
      theme.colorScheme.surface,
    );
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('showcase-${tile.key}'),
        borderRadius: BorderRadius.circular(16),
        onTap: tile.onTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 200;
            final icon = Container(
              width: compact ? 40 : 52,
              height: compact ? 40 : 52,
              decoration: BoxDecoration(
                color: tile.accent.withValues(alpha: isDark ? 0.30 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tile.icon,
                color: tile.accent,
                size: compact ? 22 : 28,
              ),
            );
            final texts = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            if (compact) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 132),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          icon,
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      texts,
                    ],
                  ),
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: texts),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.imageUrl, required this.onExplore});

  final String imageUrl;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 200,
          minWidth: double.infinity,
        ),
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    heightFactor: 1,
                    child: AppNetworkImage(url: imageUrl),
                  ),
                ),
              ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.45, 1.0],
                    colors: [
                      Color(0xFF312E81),
                      Color(0xE6312E81),
                      Color(0x33312E81),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Book Smarter\nLive Better',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Amazing spaces. Unforgettable moments.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('showcase-explore-now'),
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF312E81),
                      shape: const StadiumBorder(),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Explore Now',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceRadar extends StatelessWidget {
  const _SpaceRadar({
    required this.venues,
    required this.locationLabel,
    required this.onViewAll,
  });

  final List<Venue> venues;
  final String locationLabel;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place =
        locationLabel.trim().isEmpty ||
            locationLabel.toLowerCase().contains('select')
        ? 'you'
        : locationLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Space Radar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Discover popular spaces near $place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('showcase-radar-view-all'),
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (venues.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No spaces to show yet. Pick a location or tap View all.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          SizedBox(
            height: 216,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: venues.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _RadarCard(venue: venues[i]),
            ),
          ),
      ],
    );
  }
}

class _RadarCard extends ConsumerWidget {
  const _RadarCard({required this.venue});

  final Venue venue;

  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFav = ref.watch(isFavoriteProvider(venue.id)).valueOrNull ?? false;
    final price = venue.pricingBaseAmount > 0
        ? venue.pricingBaseAmount
        : venue.price;
    final place = [
      venue.address.split(',').first.trim(),
      venue.city,
    ].where((s) => s.isNotEmpty).toSet().join(', ');

    return SizedBox(
      width: 220,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('radar-venue-${venue.id}'),
          onTap: () =>
              context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    venue.coverOrSampleImageUrl.isEmpty
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_outlined),
                          )
                        : AppNetworkImage(url: venue.coverOrSampleImageUrl),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: Key('radar-fav-${venue.id}'),
                          visualDensity: VisualDensity.compact,
                          tooltip: isFav ? 'Remove from saved' : 'Save',
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isFav
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF334155),
                          ),
                          onPressed: () => _toggle(context, ref),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (venue.ratingCount > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${venue.avgRating.toStringAsFixed(1)} '
                            '(${venue.ratingCount})',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const Spacer(),
                        if (price > 0)
                          Flexible(
                            child: Text(
                              _inr.format(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (ref.read(currentUserProvider) == null) {
      context.push(AppRoutes.login);
      return;
    }
    try {
      await ref.read(favoriteControllerProvider).toggle(venue.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update saved spaces.')),
      );
    }
  }
}

class _YourActivity extends StatelessWidget {
  const _YourActivity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Quick access to your recent bookings & favorites',
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
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            const bookings = _ActivityCard(
              keyName: 'bookings',
              icon: Icons.calendar_month_rounded,
              accent: Color(0xFF2563EB),
              title: 'Recent Bookings',
              subtitle: 'View and manage your bookings',
              route: AppRoutes.bookings,
            );
            const saved = _ActivityCard(
              keyName: 'saved',
              icon: Icons.favorite_rounded,
              accent: Color(0xFFE11D48),
              title: 'Saved Spaces',
              subtitle: 'Your favorite spaces',
              route: AppRoutes.saved,
            );
            if (c.maxWidth < 480) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [bookings, SizedBox(height: 10), saved],
              );
            }
            return const Row(
              children: [
                Expanded(child: bookings),
                SizedBox(width: 12),
                Expanded(child: saved),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.keyName,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String keyName;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('showcase-activity-$keyName'),
        borderRadius: BorderRadius.circular(16),
        // Both destinations are shell tabs, so `go` switches tabs instead of
        // stacking a second copy of the tab on top of Home.
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
