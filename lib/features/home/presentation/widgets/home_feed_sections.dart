import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/category_accent.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../booking/domain/booking.dart';
import '../../../courses/domain/course.dart';
import '../../../events/domain/event.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../../location/domain/gps_location.dart';
import '../../../offers/domain/coupon.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../discovery_location.dart';
import '../home_category_catalog.dart';

class HomeLocationHeader extends StatelessWidget {
  const HomeLocationHeader({
    required this.cityLabel,
    required this.radiusKm,
    required this.onTap,
    this.source = DiscoveryLocationSource.none,
    this.gpsPhase = GpsPhase.idle,
  });

  final String cityLabel;
  final int radiusKm;
  final VoidCallback onTap;
  final DiscoveryLocationSource source;
  final GpsPhase gpsPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = gpsPhase.isBusy;
    final title = busy
        ? 'Getting your location…'
        : (cityLabel.trim().isEmpty ? 'Select location' : cityLabel);
    final subtitle = busy
        ? 'Hang tight — this will not take long'
        : switch (source) {
            DiscoveryLocationSource.gps => 'Near you',
            DiscoveryLocationSource.pin => 'PIN location · ${radiusKm} km',
            DiscoveryLocationSource.city => 'Find spaces near you',
            DiscoveryLocationSource.none => 'Find spaces near you',
          };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(
            busy ? Icons.near_me_rounded : Icons.location_on_rounded,
            color: theme.colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.expand_more_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Full-width location banner shown just under the header, matching the
/// approved reference design's purple location pill: a location icon in a
/// soft circle, the current locality as a bold title, a short subtitle, and
/// a "Change" pill button on the right. Reuses the same discovery-location
/// data ([cityLabel]/[radiusKm]/[source]/[gpsPhase]) that the previous
/// inline [HomeLocationHeader] read -- no new location fields are invented
/// here (a fully-qualified state/district breadcrumb isn't part of the
/// existing location model, so the subtitle stays the same short status
/// text the app already computes elsewhere).
class HomeLocationBanner extends StatelessWidget {
  const HomeLocationBanner({
    required this.cityLabel,
    required this.radiusKm,
    required this.onTap,
    this.source = DiscoveryLocationSource.none,
    this.gpsPhase = GpsPhase.idle,
  });

  final String cityLabel;
  final int radiusKm;
  final VoidCallback onTap;
  final DiscoveryLocationSource source;
  final GpsPhase gpsPhase;

  @override
  Widget build(BuildContext context) {
    final busy = gpsPhase.isBusy;
    final title = busy
        ? 'Getting your location…'
        : (cityLabel.trim().isEmpty ? 'Select location' : cityLabel);
    final subtitle = busy
        ? 'Hang tight — this will not take long'
        : switch (source) {
            DiscoveryLocationSource.gps => 'Near you',
            DiscoveryLocationSource.pin => 'PIN location · ${radiusKm} km',
            DiscoveryLocationSource.city => 'Find spaces near you',
            DiscoveryLocationSource.none => 'Find spaces near you',
          };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.violetDeep.withValues(alpha: 0.85),
                AppTheme.violet.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  busy ? Icons.near_me_rounded : Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    required this.onTap,
    required this.onVoiceTap,
  });

  final VoidCallback onTap;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(
                      alpha: isDark ? 0.28 : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Say a city, category, or budget...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Voice search',
                      onPressed: onVoiceTap,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppTheme.violet.withValues(alpha: 0.14),
                        foregroundColor: AppTheme.violetDeep,
                      ),
                      icon: const Icon(Icons.mic_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Voice search uses the same live filters as typed search.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

/// Full-bleed hero carousel matching the approved reference design's
/// "Top-Rated Spaces" section: a small "SPOTLIGHT" badge + title + page
/// counter + prev/next arrows above one large image card per page
/// ("Featured Spotlight" chip, rating badge, gradient overlay with venue
/// name/location/distance, price and a circular arrow CTA), with a dot
/// indicator below. Reuses the same [venues] list the previous
/// [HomeSpotlightRow] read (already filtered/sorted by the caller) --
/// this only changes the presentation, not what data feeds it.
class HomeSpotlightCarousel extends StatefulWidget {
  const HomeSpotlightCarousel({required this.venues});

  final List<Venue> venues;

  @override
  State<HomeSpotlightCarousel> createState() => _HomeSpotlightCarouselState();
}

class _HomeSpotlightCarouselState extends State<HomeSpotlightCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final count = widget.venues.length;
    if (count == 0) return;
    final next = (_index + delta).clamp(0, count - 1);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.venues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final count = widget.venues.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.spotlightAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 13, color: AppTheme.spotlightAmber),
                  const SizedBox(width: 4),
                  Text(
                    'SPOTLIGHT',
                    style: TextStyle(
                      color: AppTheme.spotlightAmber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Top-rated spaces',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              onPressed: _index > 0 ? () => _go(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              '${_index + 1}/$count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: _index < count - 1 ? () => _go(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _SpotlightHeroCard(venue: widget.venues[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.violet
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SpotlightHeroCard extends ConsumerWidget {
  const _SpotlightHeroCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real, persisted toggle (the header's "Color & 3D" pill) -- when off,
    // the card renders flat with no perspective transform at all.
    final effects3d = ref.watch(home3dEffectsProvider);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: GestureDetector(
        onTap: () => context.push(
          AppRoutes.venueDetails.replaceAll(':id', venue.id),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.spotlightAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 12, color: AppTheme.spotlightAmber),
                    const SizedBox(width: 4),
                    const Text(
                      'Featured Spotlight',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (venue.ratingCount > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 3),
                      Text(
                        '${venue.avgRating.toStringAsFixed(1)} (${venue.ratingCount})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (venue.city.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: 13, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                venue.distanceKm != null
                                    ? '${venue.city} · ${formatDistance(venue.distanceKm)}'
                                    : venue.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatInr(venue.pricingBaseAmount),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        'starts from',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.violet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
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
    );

    if (!effects3d) return card;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(-0.03)
        ..rotateY(0.015),
      child: card,
    );
  }
}

/// "Quick access" price-card row matching the reference design's Marriage
/// Halls / 24h Lodge Rooms / PG & Hostels shortcuts. Prices shown are real:
/// the lowest [Venue.pricingBaseAmount] currently loaded for that master
/// category, computed from the same [venues] list the rest of Home already
/// has in memory -- never a fabricated figure. A category with no matching
/// loaded venue shows "Explore" instead of a price.
class HomeQuickAccessRow extends StatelessWidget {
  const HomeQuickAccessRow({
    required this.venues,
    required this.onSectionTap,
  });

  final List<Venue> venues;
  final void Function(MainHomeSection section) onSectionTap;

  static const _sections = [
    MainHomeSection.functionHalls,
    MainHomeSection.lodgeRooms,
    MainHomeSection.pgHostels,
  ];

  double? _fromPrice(MainHomeSection section) {
    double? lowest;
    for (final venue in venues) {
      if (venue.category?.parentSection != section.id) continue;
      if (lowest == null || venue.pricingBaseAmount < lowest) {
        lowest = venue.pricingBaseAmount;
      }
    }
    return lowest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick access',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final section in _sections) ...[
              Expanded(
                child: _QuickAccessCard(
                  section: section,
                  fromPrice: _fromPrice(section),
                  onTap: () => onSectionTap(section),
                ),
              ),
              if (section != _sections.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.section,
    required this.fromPrice,
    required this.onTap,
  });

  final MainHomeSection section;
  final double? fromPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = categoryAccentColor(section.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.iconData, color: accent, size: 20),
              const SizedBox(height: 8),
              Text(
                section.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fromPrice != null ? '${formatInr(fromPrice!)}+' : 'Explore',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSpotlightRow extends StatelessWidget {
  const HomeSpotlightRow({required this.venues});

  final List<Venue> venues;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top-rated spaces',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 268,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: venues.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final venue = venues[index];
              return _SpotlightCard(venue: venue);
            },
          ),
        ),
      ],
    );
  }
}

class _SpotlightCard extends ConsumerWidget {
  const _SpotlightCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    return SizedBox(
      width: 212,
      child: GlassmorphicCard(
        borderRadius: 22,
        enableEntrance: false,
        onTap: () => context.push(
          AppRoutes.venueDetails.replaceAll(':id', venue.id),
        ),
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
                    top: 8,
                    left: 8,
                    child: favorite.when(
                      data: (isFav) => FavoriteButton(
                        isFavorite: isFav,
                        onPressed: () async {
                          if (ref.read(currentUserProvider) == null) {
                            context.push(AppRoutes.login);
                            return;
                          }
                          await ref
                              .read(favoriteControllerProvider)
                              .toggle(venue.id);
                        },
                      ),
                      loading: () => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                      error: (_, __) => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                    ),
                  ),
                  if (venue.ratingCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${venue.avgRating.toStringAsFixed(1)} (${venue.ratingCount})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (venue.city.isNotEmpty)
                      Text(
                        venue.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      formatInr(venue.pricingBaseAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: FilledButton(
                        onPressed: () => context.push(
                          AppRoutes.bookingFlow.replaceAll(':id', venue.id),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Book'),
                      ),
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

class HomeCouponRow extends StatelessWidget {
  const HomeCouponRow({required this.coupons});

  final List<Coupon> coupons;

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active offers',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: coupons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              return Container(
                width: 196,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppTheme.violet.withValues(alpha: 0.22),
                            AppTheme.violetSoft.withValues(alpha: 0.14),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.92),
                            AppTheme.violet.withValues(alpha: 0.10),
                          ],
                  ),
                  border: Border.all(
                    color: AppTheme.violet.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.violet.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      coupon.isPercentage
                          ? Icons.percent_rounded
                          : Icons.card_giftcard_rounded,
                      color: AppTheme.violetDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            coupon.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            coupon.valueLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeHorizontalEvents extends StatelessWidget {
  const HomeHorizontalEvents({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Upcoming events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.eventsList),
              child: const Text('View all'),
            ),
          ],
        ),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 280,
              child: EventCard(event: events[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeHorizontalCourses extends StatelessWidget {
  const HomeHorizontalCourses({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Courses',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.coursesList),
              child: const Text('View all'),
            ),
          ],
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final course = courses[index];
              return SizedBox(
                width: 236,
                child: GlassmorphicCard(
                  borderRadius: 20,
                  enableEntrance: false,
                  onTap: () => context.push(
                    AppRoutes.courseDetails.replaceAll(':id', course.id),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 88,
                        width: double.infinity,
                        child: AppNetworkImage(
                          url: course.coverImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (course.instituteName.isNotEmpty)
                                Text(
                                  course.instituteName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatInr(course.feeAmount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (course.durationWeeks > 0)
                                    Text(
                                      '${course.durationWeeks} wks',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeRecentBookings extends StatelessWidget {
  const HomeRecentBookings({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your recent bookings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 8),
        ...bookings.take(3).map(
              (booking) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  booking.venueName.isNotEmpty
                      ? booking.venueName
                      : booking.bookingRef,
                ),
                subtitle: Text(booking.status.dbValue),
                onTap: () => context.go(AppRoutes.bookings),
              ),
            ),
      ],
    );
  }
}
