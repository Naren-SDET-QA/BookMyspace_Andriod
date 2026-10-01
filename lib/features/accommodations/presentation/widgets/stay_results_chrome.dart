import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../stay_results_filter.dart';

const _stayMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatStayDay(DateTime date) {
  return '${date.day} ${_stayMonths[date.month - 1]}';
}

ButtonStyle stayActionStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppTheme.action,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );
}

/// Destination, dates, and guests in one search bar.
class StaySearchBar extends StatelessWidget {
  const StaySearchBar({
    super.key,
    required this.isPg,
    required this.controller,
    required this.hasSearch,
    required this.prefs,
    required this.onChanged,
    required this.onClear,
    required this.onPickDates,
    required this.onPickGuests,
    required this.onSearch,
  });

  final bool isPg;
  final TextEditingController controller;
  final bool hasSearch;
  final DiscoveryBookingPrefs prefs;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onPickDates;
  final VoidCallback onPickGuests;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final destination = TextField(
      key: const Key('stay_search_destination'),
      controller: controller,
      onChanged: onChanged,
      onSubmitted: (_) => onSearch(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: isPg ? 'Search a PG or area' : 'Where are you going?',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasSearch
            ? IconButton(
                tooltip: 'Clear destination',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
      ),
    );
    final dates = isPg
        ? _SearchField(
            key: const Key('stay_search_dates'),
            icon: Icons.calendar_month_outlined,
            caption: 'Move-in',
            value: formatStayDay(prefs.day),
            onTap: onPickDates,
          )
        : Row(
            children: [
              Expanded(
                child: _SearchField(
                  key: const Key('stay_search_check_in'),
                  icon: Icons.calendar_month_outlined,
                  caption: 'Check-in',
                  value: formatStayDay(prefs.day),
                  onTap: onPickDates,
                ),
              ),
              Expanded(
                child: _SearchField(
                  key: const Key('stay_search_check_out'),
                  icon: Icons.calendar_month_outlined,
                  caption: 'Check-out',
                  value: formatStayDay(prefs.checkOutDay),
                  onTap: onPickDates,
                ),
              ),
            ],
          );
    final guests = _SearchField(
      key: const Key('stay_search_guests'),
      icon: Icons.person_outline_rounded,
      caption: isPg ? 'Guests' : 'Guests and rooms',
      value: isPg
          ? '${prefs.guests} guests · ${prefs.tenureMonths} '
                '${prefs.tenureMonths == 1 ? 'month' : 'months'}'
          : '${prefs.guests} adults · ${prefs.rooms} '
                '${prefs.rooms == 1 ? 'room' : 'rooms'}',
      onTap: onPickGuests,
    );
    // Theme buttons use Size.fromHeight, whose width is infinite. A Row
    // cannot lay that out, and the failure blanks the filter chips below.
    final search = FilledButton(
      key: const Key('stay_search_submit'),
      style: stayActionStyle().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(104, 48)),
      ),
      onPressed: onSearch,
      child: const Text('Search'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 4, child: destination),
                    const _FieldDivider(),
                    Expanded(flex: 4, child: dates),
                    const _FieldDivider(),
                    Expanded(flex: 3, child: guests),
                    const SizedBox(width: 8),
                    search,
                  ],
                )
              : Column(
                  children: [
                    destination,
                    const Divider(height: 1),
                    dates,
                    const Divider(height: 1),
                    guests,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: search),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    super.key,
    required this.icon,
    required this.caption,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String caption;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class StaySortButton extends StatelessWidget {
  const StaySortButton({
    super.key,
    required this.sort,
    required this.onSelected,
  });

  final StaySort sort;
  final ValueChanged<StaySort> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<StaySort>(
      key: const Key('stay_sort_button'),
      initialValue: sort,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in StaySort.values)
          PopupMenuItem(value: option, child: Text(option.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Sort by: ${sort.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.action,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.action),
          ],
        ),
      ),
    );
  }
}

/// Property card: photo, name and class, review score, price, availability.
class StayResultCard extends ConsumerStatefulWidget {
  const StayResultCard({
    super.key,
    required this.venue,
    required this.isPg,
    required this.prefs,
    required this.horizontal,
    required this.onTap,
  });

  final Venue venue;
  final bool isPg;
  final DiscoveryBookingPrefs prefs;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  ConsumerState<StayResultCard> createState() => _StayResultCardState();
}

class _StayResultCardState extends ConsumerState<StayResultCard> {
  var _imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = widget.venue;
    final images = venue.galleryImageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    final imageUrl = images.isEmpty
        ? venue.coverOrSampleImageUrl
        : images[_imageIndex.clamp(0, images.length - 1)];
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final saved = favorite.asData?.value ?? false;
    final photo = _Photo(
      url: imageUrl,
      saved: saved,
      photoCount: images.length,
      photoIndex: images.isEmpty ? 0 : _imageIndex.clamp(0, images.length - 1),
      onSave: () => ref.read(favoriteControllerProvider).toggle(venue.id),
      onPrevious: images.length < 2
          ? null
          : () => setState(() {
              _imageIndex = (_imageIndex - 1 + images.length) % images.length;
            }),
      onNext: images.length < 2
          ? null
          : () => setState(() {
              _imageIndex = (_imageIndex + 1) % images.length;
            }),
    );
    final details = _Details(venue: venue, isPg: widget.isPg);
    final price = _PriceColumn(
      venue: venue,
      isPg: widget.isPg,
      prefs: widget.prefs,
      onTap: widget.onTap,
    );

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: widget.horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 248, height: 206, child: photo),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: details,
                    ),
                  ),
                  SizedBox(
                    width: 188,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
                      child: price,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: 1.7, child: photo),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [details, const SizedBox(height: 12), price],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.url,
    required this.saved,
    required this.photoCount,
    required this.photoIndex,
    required this.onSave,
    required this.onPrevious,
    required this.onNext,
  });

  final String url;
  final bool saved;
  final int photoCount;
  final int photoIndex;
  final VoidCallback onSave;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(url: url, fit: BoxFit.cover),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSave,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  saved ? Icons.favorite_rounded : Icons.favorite_border,
                  size: 20,
                  color: saved
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        ),
        if (onPrevious != null)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _PhotoStep(icon: Icons.chevron_left, onTap: onPrevious!),
            ),
          ),
        if (onNext != null)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _PhotoStep(icon: Icons.chevron_right, onTap: onNext!),
            ),
          ),
        if (photoCount > 1)
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  '${photoIndex + 1} / $photoCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoStep extends StatelessWidget {
  const _PhotoStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 22, color: const Color(0xFF1F2937)),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.venue, required this.isPg});

  final Venue venue;
  final bool isPg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = venue.address.trim().isNotEmpty ? venue.address : venue.city;
    final stars = venue.starRating;
    final perks = <String>[
      if (StayResultsFilterEngine.hasFreeCancellation(venue))
        'Free cancellation',
      if (StayResultsFilterEngine.hasBreakfast(venue))
        isPg ? 'Meals included' : 'Breakfast included',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              venue.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.action,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!isPg && stars != null && stars >= 1 && stars <= 5)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < stars; index++)
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFB700),
                    ),
                ],
              ),
            if (venue.isVerified) const VerifiedBadge(),
          ],
        ),
        if (place.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            place,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (venue.distanceKm != null) ...[
          const SizedBox(height: 2),
          Text(
            '${formatDistance(venue.distanceKm)} from centre',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (venue.avgRating > 0) ...[
          const SizedBox(height: 8),
          _ScoreLine(rating: venue.avgRating, count: venue.ratingCount),
        ],
        for (final perk in perks) ...[
          const SizedBox(height: 4),
          Text(
            perk,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF067A3D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = StayReviewCopy.adjective(rating);
    final color = rating >= 4
        ? AppTheme.action
        : rating >= 3
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF64748B);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: word,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (count > 0)
                  TextSpan(
                    text: ' · $count reviews',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.venue,
    required this.isPg,
    required this.prefs,
    required this.onTap,
  });

  final Venue venue;
  final bool isPg;
  final DiscoveryBookingPrefs prefs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = isPg ? prefs.tenureMonths : prefs.nights;
    final listed = venue.price > 0 ? venue.price * units : 0.0;
    final unitLabel = isPg
        ? '${formatInr(venue.price)} per month'
        : '${formatInr(venue.price)} per night';
    final stayLabel = isPg
        ? '$units ${units == 1 ? 'month' : 'months'}, ${prefs.guests} guests'
        : '$units ${units == 1 ? 'night' : 'nights'}, '
              '${prefs.guests} adults · ${prefs.rooms} '
              '${prefs.rooms == 1 ? 'room' : 'rooms'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          stayLabel,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (venue.price <= 0)
          Text(
            'Price on request',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          )
        else ...[
          if (venue.hasDiscount)
            Text(
              formatInr(venue.originalPrice! * units),
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            formatInr(listed),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unitLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (venue.taxRate > 0)
            Text(
              '+ taxes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: Key('stay_see_${venue.id}'),
            style: stayActionStyle(),
            onPressed: onTap,
            child: const Text('See availability'),
          ),
        ),
      ],
    );
  }
}
