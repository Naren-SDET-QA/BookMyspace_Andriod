import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../recently_viewed.dart';

/// Which booking form Home is collecting. Institutes only opens Education.
enum BookingIntent { hotels, halls, pg, institutes }

/// Primary "what are you booking?" cards. One layout: a row from 720px up,
/// a two-column grid below that.
class BookingIntentCards extends StatelessWidget {
  const BookingIntentCards({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BookingIntent? selected;
  final ValueChanged<BookingIntent> onSelected;

  static const _items = <_IntentSpec>[
    _IntentSpec(
      intent: BookingIntent.hotels,
      label: 'Hotels',
      hint: 'Stays & rooms',
      icon: Icons.hotel_rounded,
      color: Color(0xFFF97316),
    ),
    _IntentSpec(
      intent: BookingIntent.halls,
      label: 'Function Halls',
      hint: 'Events & celebrations',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _IntentSpec(
      intent: BookingIntent.pg,
      label: 'PG',
      hint: 'Hostels & co-living',
      icon: Icons.home_rounded,
      color: Color(0xFF14B8A6),
    ),
    _IntentSpec(
      intent: BookingIntent.institutes,
      label: 'Institutes',
      hint: 'Opens Education',
      icon: Icons.school_rounded,
      color: Color(0xFF3B82F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cardWidth = wide
            ? (constraints.maxWidth - 30) / _items.length
            : 168.0;
        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final spec = _items[index];
              return SizedBox(
                width: cardWidth,
                child: _IntentCard(
                  spec: spec,
                  selected: selected == spec.intent,
                  onTap: () => onSelected(spec.intent),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _IntentSpec {
  const _IntentSpec({
    required this.intent,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  final BookingIntent intent;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _IntentSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: selected
          ? spec.color.withValues(alpha: isDark ? 0.22 : 0.12)
          : (isDark ? const Color(0xFF151A2C) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('booking-intent-${spec.intent.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? spec.color
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(spec.icon, color: spec.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      spec.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
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

/// Device-local venues the customer already opened. Renders nothing when
/// the list is empty so Home never shows placeholder listings.
class HomeRecentlyViewed extends StatelessWidget {
  const HomeRecentlyViewed({super.key, required this.venues});

  final List<RecentlyViewedVenue> venues;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently viewed',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: venues.length.clamp(0, 8),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final venue = venues[index];
              return SizedBox(
                width: 220,
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(
                      AppRoutes.venueDetails.replaceAll(':id', venue.id),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: AppNetworkImage(
                                url: venue.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                if (venue.city.isNotEmpty)
                                  Text(
                                    venue.city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                if (venue.rating > 0)
                                  Text(
                                    venue.rating.toStringAsFixed(1),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.brand,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
