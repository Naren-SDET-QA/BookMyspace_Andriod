import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../admin/domain/admin_settings.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../promotions/domain/promotion.dart';
import '../../../promotions/presentation/promotion_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';

/// "Modern" Home layout (admin setting `home_layout: modern`).
///
/// Presentation only: every widget here forwards taps to callbacks owned by
/// HomeScreen and reads data from the same providers the glass layout uses.
/// The glass layout (home_v2_widgets.dart) is untouched and remains
/// selectable from Admin settings -> Home UI.

const _ink = Color(0xFF14163A);
const _brandDeep = Color(0xFF3730A3);
const _brandViolet = Color(0xFF7C3AED);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _cardColor(BuildContext context) => _isDark(context)
    ? Theme.of(context).colorScheme.surfaceContainerHigh
    : Colors.white;

Color _titleColor(BuildContext context) =>
    _isDark(context) ? Theme.of(context).colorScheme.onSurface : _ink;

Color _mutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

List<BoxShadow> _softShadow(BuildContext context) => _isDark(context)
    ? const []
    : [
        BoxShadow(
          color: AppTheme.brand.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

Border _hairline(BuildContext context) => Border.all(
  color: _isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE9EAF5),
);

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class ModernHomeHeader extends StatelessWidget {
  const ModernHomeHeader({
    super.key,
    required this.user,
    required this.locationLabel,
    required this.horizontalPadding,
    required this.showNotifications,
    required this.onLocationTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.onLoginTap,
    this.unreadCount = 0,
  });

  final dynamic user;
  final String locationLabel;
  final double horizontalPadding;
  final bool showNotifications;
  final int unreadCount;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = () {
      try {
        return (user as AuthUser?)?.avatarUrl ?? '';
      } catch (_) {
        return '';
      }
    }();
    final initial = () {
      try {
        final name = (user as AuthUser?)?.fullName ?? '';
        final email = (user as AuthUser?)?.email ?? '';
        final source = name.isNotEmpty ? name : email;
        return source.isEmpty ? 'U' : source[0].toUpperCase();
      } catch (_) {
        return 'U';
      }
    }();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppTheme.brand, _brandViolet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
            child: const Icon(
              Icons.apartment_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppTheme.brand, _brandViolet],
                  ).createShader(rect),
                  child: const Text(
                    'BookMySpace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  'Spaces for Every Moment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (locationLabel.isNotEmpty)
            Flexible(
              child: Material(
                color: AppTheme.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onLocationTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: AppTheme.brand,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _titleColor(context),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _titleColor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showNotifications)
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotificationsTap,
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                smallSize: 9,
                backgroundColor: const Color(0xFFEF4444),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 27,
                  color: AppTheme.brand,
                ),
              ),
            ),
          if (user == null)
            TextButton(
              onPressed: onLoginTap,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.brand,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 40),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            InkWell(
              onTap: onProfileTap,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.brand.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
                  foregroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class ModernHomeSearchBar extends StatefulWidget {
  const ModernHomeSearchBar({
    super.key,
    required this.onSubmit,
    this.hint = 'Search spaces, events, classes, PGs...',
    this.onVoiceTap,
    this.onScanTap,
  });

  final ValueChanged<String> onSubmit;
  final String hint;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onScanTap;

  @override
  State<ModernHomeSearchBar> createState() => _ModernHomeSearchBarState();
}

class _ModernHomeSearchBarState extends State<ModernHomeSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: _hairline(context),
        boxShadow: _softShadow(context),
      ),
      padding: const EdgeInsets.only(left: 16, right: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 26, color: _titleColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmit,
              style: TextStyle(fontSize: 15, color: _titleColor(context)),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: widget.hint,
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: _mutedColor(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (widget.onVoiceTap != null)
            IconButton(
              tooltip: 'Search by voice',
              onPressed: widget.onVoiceTap,
              icon: const Icon(Icons.mic_none_rounded, color: AppTheme.brand),
            ),
          if (widget.onScanTap != null)
            IconButton(
              tooltip: 'Scan QR',
              onPressed: widget.onScanTap,
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppTheme.brand,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category tiles
// ---------------------------------------------------------------------------

class ModernCategoryTile {
  const ModernCategoryTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.accent,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final Color accent;
  final VoidCallback onTap;
}

class ModernCategoryGrid extends StatelessWidget {
  const ModernCategoryGrid({super.key, required this.tiles});

  final List<ModernCategoryTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 300
            ? 2
            : 1;
        const gap = 10.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: _ModernCategoryCard(tile: tile, width: tileWidth),
              ),
          ],
        );
      },
    );
  }
}

class _ModernCategoryCard extends StatelessWidget {
  const _ModernCategoryCard({required this.tile, required this.width});

  final ModernCategoryTile tile;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final bubble = (width * 0.3).clamp(42.0, 66.0);
    final background = dark
        ? tile.accent.withValues(alpha: 0.16)
        : Color.alphaBlend(tile.accent.withValues(alpha: 0.09), Colors.white);
    return Semantics(
      button: true,
      label: '${tile.title}. ${tile.subtitle}',
      child: Material(
        key: ValueKey('home_tile_${tile.id}'),
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: tile.onTap,
          child: Container(
            height: 106,
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tile.accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: bubble,
                  height: bubble,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tile.accent.withValues(alpha: dark ? 0.30 : 0.20),
                        tile.accent.withValues(alpha: dark ? 0.12 : 0.06),
                      ],
                    ),
                  ),
                  child: Text(
                    tile.emoji,
                    style: TextStyle(fontSize: bubble * 0.52),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tile.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _titleColor(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tile.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          color: _mutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _titleColor(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero banner
// ---------------------------------------------------------------------------

class ModernHeroBanner extends ConsumerStatefulWidget {
  const ModernHeroBanner({super.key, required this.settings, this.onTap});

  final Map<String, dynamic> settings;
  final VoidCallback? onTap;

  @override
  ConsumerState<ModernHeroBanner> createState() => _ModernHeroBannerState();
}

class _ModernHeroBannerState extends ConsumerState<ModernHeroBanner> {
  static const _defaultImage =
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&auto=format&fit=crop&q=80';

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promotions =
        ref.watch(activePromotionsProvider).valueOrNull ?? const <Promotion>[];
    final media = widget.settings['banner_media_url']?.toString() ?? '';
    final image = media.isNotEmpty ? media : _defaultImage;
    final slides = <_HeroSlide>[
      _HeroSlide(
        title: AdminSettings.text(
          widget.settings['hero_banner_title'],
          'Book Smarter\nLive Better',
        ),
        subtitle: AdminSettings.text(
          widget.settings['hero_banner_subtitle'],
          'Amazing spaces. Unforgettable moments.',
        ),
        cta: 'Explore Now',
        imageUrl: image,
      ),
      for (final promo in promotions.take(5))
        _HeroSlide(
          title: promo.title.isEmpty ? 'BookMySpace offer' : promo.title,
          subtitle: promo.shortDescription,
          cta: promo.ctaText.isEmpty ? 'Explore Now' : promo.ctaText,
          imageUrl: image,
          badge: promo.badge,
        ),
    ];
    if (_page >= slides.length) _page = 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 196,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) =>
                  _HeroSlideView(slide: slides[i], onTap: widget.onTap),
            ),
            if (slides.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _page ? 1 : 0.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
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

class _HeroSlide {
  const _HeroSlide({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.imageUrl,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String cta;
  final String imageUrl;
  final String? badge;
}

class _HeroSlideView extends StatelessWidget {
  const _HeroSlideView({required this.slide, this.onTap});

  final _HeroSlide slide;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppNetworkImage(url: slide.imageUrl, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.45, 0.8],
                colors: [Color(0xF2231A7A), Color(0xCC4C1D95), Color(0x00000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((slide.badge ?? '').isNotEmpty)
                  Text(
                    slide.badge!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.66,
                  child: Text(
                    slide.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandDeep,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slide.cta,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
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

// ---------------------------------------------------------------------------
// Section card shell used by Space Radar and Activity
// ---------------------------------------------------------------------------

class _ModernSectionHeader extends StatelessWidget {
  const _ModernSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: AppTheme.brand, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _titleColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: _mutedColor(context)),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Your Space Radar
// ---------------------------------------------------------------------------

class ModernSpaceRadar extends StatelessWidget {
  const ModernSpaceRadar({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: _hairline(context),
        boxShadow: _softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernSectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Your Space Radar',
            subtitle: locationLabel.isEmpty
                ? 'Discover popular spaces near you'
                : 'Discover popular spaces near $locationLabel',
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(foregroundColor: AppTheme.brand),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 212,
            child: venues.when(
              data: (items) {
                if (items.isEmpty) {
                  return _RadarMessage(
                    message: 'No nearby spaces are available yet.',
                    actionLabel: 'Browse all',
                    onAction: onViewAll,
                  );
                }
                final visible = items.take(10).toList(growable: false);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _RadarVenueCard(
                    venue: visible[i],
                    onTap: () => onVenueTap(visible[i]),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              error: (_, _) => _RadarMessage(
                message: 'Nearby spaces could not be loaded.',
                actionLabel: onRetry == null ? null : 'Try again',
                onAction: onRetry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarMessage extends StatelessWidget {
  const _RadarMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: TextStyle(color: _mutedColor(context))),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RadarVenueCard extends ConsumerWidget {
  const _RadarVenueCard({required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(isFavoriteProvider(venue.id)).valueOrNull;
    final location = [
      venue.addressLine2,
      venue.city,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return SizedBox(
      width: 222,
      child: Material(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: _hairline(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 108,
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
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: favorite == null
                                ? null
                                : () => ref.read(
                                    toggleFavoriteProvider(venue.id).future,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                favorite == true
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: favorite == true
                                    ? const Color(0xFFE11D48)
                                    : _ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _titleColor(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppTheme.brand,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location.isEmpty ? 'Nearby' : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _mutedColor(context),
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
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              venue.avgRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _titleColor(context),
                              ),
                            ),
                            if (venue.ratingCount > 0)
                              Text(
                                ' (${venue.ratingCount})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _mutedColor(context),
                                ),
                              ),
                          ],
                          const Spacer(),
                          Flexible(
                            child: Text(
                              venue.price > 0
                                  ? formatInr(venue.price)
                                  : 'Price on request',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _titleColor(context),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Your Activity
// ---------------------------------------------------------------------------

class ModernActivitySection extends StatelessWidget {
  const ModernActivitySection({
    super.key,
    required this.onBookingsTap,
    required this.onSavedTap,
  });

  final VoidCallback onBookingsTap;
  final VoidCallback onSavedTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: _hairline(context),
        boxShadow: _softShadow(context),
      ),
      child: Column(
        children: [
          _ModernSectionHeader(
            icon: Icons.access_time_filled_rounded,
            title: 'Your Activity',
            subtitle: 'Quick access to your recent bookings & favorites',
            onTap: onBookingsTap,
            trailing: Padding(
              padding: const EdgeInsets.only(top: 10, right: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                color: _titleColor(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 330;
                final tiles = [
                  _ActivityTile(
                    icon: Icons.calendar_month_rounded,
                    iconColor: AppTheme.brand,
                    tint: const Color(0xFFE8EDFF),
                    title: 'Recent Bookings',
                    subtitle: 'View and manage your bookings',
                    onTap: onBookingsTap,
                  ),
                  _ActivityTile(
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFE11D48),
                    tint: const Color(0xFFFFE4EC),
                    title: 'Saved Spaces',
                    subtitle: 'Your favorite spaces',
                    onTap: onSavedTap,
                  ),
                ];
                if (stacked) {
                  return Column(
                    children: [
                      tiles[0],
                      const SizedBox(height: 8),
                      tiles[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 8),
                    Expanded(child: tiles[1]),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Material(
      color: _cardColor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: _hairline(context),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: dark ? iconColor.withValues(alpha: 0.18) : tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _titleColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _titleColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
