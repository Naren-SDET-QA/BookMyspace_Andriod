import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
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
import '../../domain/home_appearance.dart';
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
    this.onLocationTap,
    this.locationLabel,
    this.onDateTap,
    this.dateLabel,
    this.onGuestsTap,
    this.guestsLabel,
  });

  final VoidCallback onTap;
  final VoidCallback onVoiceTap;
  final VoidCallback? onLocationTap;
  final String? locationLabel;
  final VoidCallback? onDateTap;
  final String? dateLabel;
  final VoidCallback? onGuestsTap;
  final String? guestsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151A2C) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(
                    alpha: isDark ? 0.28 : 0.08,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                wide ? 10 : 12,
                10,
                wide ? 10 : 12,
              ),
              child: wide ? _wideRow(theme) : _compactColumn(theme),
            ),
          ),
        );
      },
    );
  }

  Widget _wideRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(flex: 3, child: _queryField(theme, onTap: onTap)),
        const SizedBox(width: 8),
        if (onLocationTap != null) ...[
          Expanded(
            child: _HeroMiniChip(
              icon: Icons.location_on_rounded,
              label: 'Location',
              value: _locationValue,
              onTap: onLocationTap!,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onDateTap != null) ...[
          Expanded(
            child: _HeroMiniChip(
              icon: Icons.event_rounded,
              label: 'Date',
              value: dateLabel ?? 'Today',
              onTap: onDateTap!,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onGuestsTap != null) ...[
          Expanded(
            child: _HeroMiniChip(
              key: const Key('home-guests-chip'),
              icon: Icons.person_rounded,
              label: 'Guests',
              value: guestsLabel ?? '2 Guests',
              onTap: onGuestsTap!,
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          tooltip: 'Voice search',
          onPressed: onVoiceTap,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
            foregroundColor: AppTheme.violetDeep,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.mic_rounded),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.violet,
            foregroundColor: Colors.white,
            minimumSize: const Size(96, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Search'),
        ),
      ],
    );
  }

  Widget _compactColumn(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _queryField(theme, onTap: onTap)),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Voice search',
              onPressed: onVoiceTap,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.mic_rounded),
            ),
          ],
        ),
        if (onLocationTap != null ||
            onDateTap != null ||
            onGuestsTap != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (onLocationTap != null)
                Expanded(
                  child: _HeroMiniChip(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: _locationValue,
                    onTap: onLocationTap!,
                  ),
                ),
              if (onLocationTap != null && onDateTap != null)
                const SizedBox(width: 8),
              if (onDateTap != null)
                Expanded(
                  child: _HeroMiniChip(
                    icon: Icons.event_rounded,
                    label: 'Date',
                    value: dateLabel ?? 'Today',
                    onTap: onDateTap!,
                  ),
                ),
              if (onDateTap != null && onGuestsTap != null)
                const SizedBox(width: 8),
              if (onGuestsTap != null)
                Expanded(
                  child: _HeroMiniChip(
                    key: const Key('home-guests-chip'),
                    icon: Icons.person_rounded,
                    label: 'Guests',
                    value: guestsLabel ?? '2 Guests',
                    onTap: onGuestsTap!,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String get _locationValue =>
      locationLabel == null || locationLabel!.trim().isEmpty
          ? 'Select location'
          : locationLabel!;

  Widget _queryField(ThemeData theme, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'What are you looking for?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Height-safe guests picker. Constrains itself to the available viewport
/// and scrolls, so short web/phone heights never overflow.
class HomeGuestsPickerSheet extends StatelessWidget {
  const HomeGuestsPickerSheet({
    super.key,
    required this.selected,
    this.maxGuests = 8,
  });

  final int selected;
  final int maxGuests;

  static Future<int?> show(
    BuildContext context, {
    required int selected,
    int maxGuests = 8,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => HomeGuestsPickerSheet(
        selected: selected,
        maxGuests: maxGuests,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.55;
    return KeyedSubtree(
      key: const Key('home-guests-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight.clamp(220.0, 460.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Guests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: maxGuests,
                itemBuilder: (context, index) {
                  final n = index + 1;
                  return ListTile(
                    title: Text(n == 1 ? '1 Guest' : '$n Guests'),
                    selected: n == selected,
                    onTap: () => Navigator.pop(context, n),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMiniChip extends StatelessWidget {
  const _HeroMiniChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
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

/// Picks one display image per spotlight venue so consecutive pages don't
/// repeat the same artwork.
///
/// Priority per venue:
/// 1. Admin-configured spotlight artwork, cycled per index.
/// 2. The venue's own cover image -- but only when it is distinct from the
///    cover of every previous page (seeded listings often share one stock
///    cover, which made the whole carousel show the same photo).
/// 3. The app's stock photo pool (poster/alternate/fallback per
///    [MainHomeSection]), rotated deterministically by index and nudged by a
///    hash of the venue id so equal covers land on different pool entries.
List<String> spotlightImagesForVenues(List<Venue> venues,
    {List<String> adminImages = const []}) {
  if (venues.isEmpty) return const [];

  final pool = <String>[
    for (final section in MainHomeSection.values) ...[
      section.posterImageUrl,
      section.alternateImageUrl,
      section.fallbackImageUrl,
    ],
  ];

  final urls = <String>[];

  // Next unused stock image, scanning from a stable per-venue offset so
  // venues with identical covers still land on different pool entries.
  String nextStock(int index, Venue venue) {
    final start = (index + venue.id.hashCode) % pool.length;
    for (var step = 0; step < pool.length; step++) {
      final candidate = pool[(start + step) % pool.length];
      if (!urls.contains(candidate)) return candidate;
    }
    return pool[start]; // Pool exhausted: allow repeats, never loop forever.
  }

  for (var i = 0; i < venues.length; i++) {
    if (adminImages.isNotEmpty) {
      urls.add(adminImages[i % adminImages.length]);
      continue;
    }

    final cover = venues[i].coverImageUrl;
    if (cover.isNotEmpty && !urls.contains(cover)) {
      urls.add(cover);
    } else {
      urls.add(nextStock(i, venues[i]));
    }
  }
  return urls;
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
    final images = spotlightImagesForVenues(widget.venues);

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
                child: _SpotlightHeroCard(
                  venue: widget.venues[index],
                  imageUrl: images[index],
                ),
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
  const _SpotlightHeroCard({required this.venue, this.imageUrl});

  final Venue venue;

  /// Per-page display image; falls back to the venue cover when null.
  final String? imageUrl;

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
            AppNetworkImage(
              url: imageUrl ?? venue.coverImageUrl,
              fit: BoxFit.cover,
            ),
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

/// Colourful, dynamic spotlight carousel.
///
/// Admin config controls the title, artwork, accent rim and glow; the venue
/// data itself always comes from live listings.
class HomeSpotlightRow extends StatefulWidget {
  const HomeSpotlightRow({
    super.key,
    required this.venues,
    this.title = 'Top-rated spaces',
    this.subtitle = '',
    this.style = const HomeBlockStyle(),
    this.images = const [],
  });

  final List<Venue> venues;
  final String title;
  final String subtitle;
  final HomeBlockStyle style;

  /// Optional admin artwork, cycled across cards when shorter than the list.
  final List<String> images;

  @override
  State<HomeSpotlightRow> createState() => _HomeSpotlightRowState();
}

class _HomeSpotlightRowState extends State<HomeSpotlightRow> {
  static const _cardWidth = 236.0;
  static const _gap = 12.0;

  final ScrollController _controller = ScrollController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final next = ((_controller.offset + _cardWidth / 2) / (_cardWidth + _gap))
        .floor()
        .clamp(0, widget.venues.length - 1);
    if (next != _index) setState(() => _index = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venues = widget.venues;
    if (venues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = widget.style;
    final images =
        spotlightImagesForVenues(venues, adminImages: widget.images);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'SPOTLIGHT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: style.titleColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_index + 1}/${venues.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (widget.subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 268,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: venues.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              final venue = venues[index];
              return SizedBox(
                width: _cardWidth,
                child: _SpotlightCard(
                  venue: venue,
                  imageUrl: images[index],
                  accentGradient: style.backgroundColors.isEmpty
                      ? null
                      : LinearGradient(colors: style.backgroundColors),
                  glow: style.glow,
                  borderWidth: style.borderWidth,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpotlightCard extends ConsumerWidget {
  const _SpotlightCard({
    required this.venue,
    this.imageUrl,
    this.accentGradient,
    this.glow = false,
    this.borderWidth = 1.2,
  });

  final Venue venue;
  final String? imageUrl;
  final Gradient? accentGradient;
  final bool glow;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppTheme.cyan.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: GlassmorphicCard(
        borderRadius: 22,
        borderWidth: borderWidth,
        accentGradient: accentGradient,
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
                    url: imageUrl ?? venue.coverImageUrl,
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore Top Coaching & Training Academies',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Book your spot in the best classes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.education),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final course = courses[index];
              final totalSeats =
                  course.batches.fold<int>(0, (sum, b) => sum + b.capacity);
              final seatsLeft =
                  course.batches.fold<int>(0, (sum, b) => sum + b.seatsLeft);
              return SizedBox(
                width: 240,
                child: GlassmorphicCard(
                  borderRadius: 16,
                  enableEntrance: false,
                  onTap: () => context.push(
                    AppRoutes.courseDetails.replaceAll(':id', course.id),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 82,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppNetworkImage(
                              url: course.coverImage,
                              fit: BoxFit.cover,
                            ),
                            // Category pill overlay
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  course.mode.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            // Verified badge
                            if (course.instituteVerified)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: Color(0xFF10B981),
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Seat availability
                              if (totalSeats > 0)
                                Row(
                                  children: [
                                    Icon(
                                      seatsLeft <= 3
                                          ? Icons.event_seat_rounded
                                          : Icons.event_available_rounded,
                                      size: 12,
                                      color: seatsLeft <= 3
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$seatsLeft seats left',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: seatsLeft <= 3
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatInr(course.feeAmount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (course.durationWeeks > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${course.durationWeeks} wks',
                                        style: theme.textTheme.labelSmall,
                                      ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).homeRecentBookingsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.bookings),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...bookings.take(3).map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(AppRoutes.bookings),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.violet.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppTheme.violetDeep,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.venueName.isNotEmpty
                                      ? booking.venueName
                                      : booking.bookingRef,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (booking.venueCity.isNotEmpty)
                                  Text(
                                    booking.venueCity,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _BookingStatusChip(status: booking.status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == BookingStatus.confirmed ||
        status == BookingStatus.completed;
    final color = confirmed ? AppTheme.success : AppTheme.violet;
    final label = switch (status) {
      BookingStatus.confirmed => 'Confirmed',
      BookingStatus.completed => 'Completed',
      BookingStatus.pending => 'Pending',
      BookingStatus.awaitingOwnerApproval => 'Pending',
      BookingStatus.cancelled => 'Cancelled',
      _ => status.dbValue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// The live space radar: the venues nearest to the reader right now.
///
/// It shows only what the backend actually knows — distance from the reader's
/// selected location, rating and artwork. This codebase holds no availability
/// data, so the block deliberately does **not** claim to know which slots are
/// free; inventing that would be worse than leaving it out.
///
/// Without a location there is nothing honest to show, so it renders nothing at
/// all rather than falling back to a made-up city — the same rule the spotlight
/// and category blocks follow.
class HomeLiveRadar extends StatelessWidget {
  const HomeLiveRadar({
    super.key,
    required this.venues,
    required this.title,
    this.subtitle = '',
    this.onVenueTap,
  });

  final List<Venue> venues;
  final String title;
  final String subtitle;

  /// Defaults to opening the venue's details screen.
  final ValueChanged<Venue>? onVenueTap;

  /// Three keeps the block a glance rather than a list.
  static const int maxCards = 3;

  /// Card height, sized so the artwork plus two text lines always fit.
  static const double stripHeight = 136;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = nearestFirst(venues).take(maxCards).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final venue = shown[index];
              return _RadarCard(
                venue: venue,
                onTap: () {
                  final handler = onVenueTap;
                  if (handler != null) {
                    handler(venue);
                  } else {
                    context.push(
                      AppRoutes.venueDetails.replaceFirst(':id', venue.id),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Nearest first. A venue the backend returned without a distance keeps its
  /// relative order at the back rather than being dropped.
  static List<Venue> nearestFirst(List<Venue> venues) {
    final sorted = [...venues];
    sorted.sort((a, b) {
      final da = a.distanceKm;
      final db = b.distanceKm;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted;
  }

  /// The venue's cover artwork: an explicit cover wins, then sort order.
  static String coverUrl(Venue venue) {
    if (venue.images.isEmpty) return '';
    final sorted = [...venue.images]..sort((a, b) {
        if (a.isCover != b.isCover) return a.isCover ? -1 : 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    final cover = sorted.first;
    final thumbnail = cover.thumbnailUrl;
    return thumbnail != null && thumbnail.isNotEmpty ? thumbnail : cover.url;
  }

  /// Distance when the backend supplied one, otherwise the city.
  ///
  /// Metres and kilometres read the same in every shipped language, so no
  /// translation is needed here.
  static String distanceLabel(Venue venue) {
    final km = venue.distanceKm;
    if (km == null) return venue.city;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}

class _RadarCard extends StatelessWidget {
  const _RadarCard({required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 158,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppNetworkImage(
                url: HomeLiveRadar.coverUrl(venue),
                width: double.infinity,
                height: 64,
                fit: BoxFit.cover,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 12,
                            color: AppTheme.brand,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              HomeLiveRadar.distanceLabel(venue),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            venue.avgRating.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}
