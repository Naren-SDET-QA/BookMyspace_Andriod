import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../stay_results_filter.dart';

/// Booking-results filter column: budget, popular filters, class, type,
/// facilities, guest rating, and distance. Counts use [venues].
class StayFilterPanel extends StatefulWidget {
  const StayFilterPanel({
    super.key,
    required this.venues,
    required this.filter,
    required this.onChanged,
    required this.isPg,
    required this.priceCeiling,
    this.showApplyBar = false,
    this.resultCount = 0,
    this.onApply,
    this.onClear,
  });

  final List<Venue> venues;
  final StayResultsFilter filter;
  final ValueChanged<StayResultsFilter> onChanged;
  final bool isPg;

  /// Slider maximum remembered from an unfiltered result page.
  final double priceCeiling;
  final bool showApplyBar;
  final int resultCount;
  final VoidCallback? onApply;
  final VoidCallback? onClear;

  @override
  State<StayFilterPanel> createState() => _StayFilterPanelState();
}

class _StayFilterPanelState extends State<StayFilterPanel> {
  RangeValues? _dragPrice;
  var _showAllFacilities = false;

  @override
  void didUpdateWidget(StayFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.minPrice != widget.filter.minPrice ||
        oldWidget.filter.maxPrice != widget.filter.maxPrice) {
      _dragPrice = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = widget.filter;
    final venues = widget.venues;
    final ceiling = widget.priceCeiling > 0 ? widget.priceCeiling : 20000.0;
    final price =
        _dragPrice ??
        RangeValues(filter.minPrice ?? 0, filter.maxPrice ?? ceiling);
    final propertyRows = _propertyRows();
    final popularRows = _popularRows();
    final starRows = widget.isPg ? const <Widget>[] : _starRows();
    final facilityRows = _facilityRows();
    final reviewRows = _reviewRows();
    final distanceRows = _distanceRows();

    return Material(
      key: const Key('stay_filter_panel'),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      'Filter by:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (filter.activeCount > 0)
                      TextButton(
                        key: const Key('stay_filter_clear'),
                        onPressed: widget.onClear,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                if (ceiling > 0) ...[
                  const _SectionTitle('Your budget'),
                  Text(
                    '${formatInr(price.start)} – ${formatInr(price.end)}'
                    ' ${widget.isPg ? 'per month' : 'per night'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  _PriceHistogram(
                    venues: venues,
                    ceiling: ceiling,
                    min: price.start,
                    max: price.end,
                  ),
                  RangeSlider(
                    key: const Key('stay_price_slider'),
                    min: 0,
                    max: ceiling,
                    divisions: _divisions(ceiling),
                    values: RangeValues(
                      price.start.clamp(0, ceiling).toDouble(),
                      price.end.clamp(0, ceiling).toDouble(),
                    ),
                    onChanged: (value) => setState(() => _dragPrice = value),
                    onChangeEnd: _commitPrice,
                  ),
                ],
                if (popularRows.isNotEmpty) ...[
                  const _SectionTitle('Popular filters'),
                  ...popularRows,
                ],
                if (starRows.isNotEmpty) ...[
                  const _SectionTitle('Property rating'),
                  ...starRows,
                ],
                if (propertyRows.isNotEmpty) ...[
                  const _SectionTitle('Property type'),
                  ...propertyRows,
                ],
                if (facilityRows.isNotEmpty) ...[
                  const _SectionTitle('Facilities'),
                  ...facilityRows,
                ],
                if (reviewRows.isNotEmpty) ...[
                  const _SectionTitle('Review score'),
                  ...reviewRows,
                ],
                if (distanceRows.isNotEmpty) ...[
                  const _SectionTitle('Distance from centre'),
                  ...distanceRows,
                ],
              ],
            ),
          ),
          if (widget.showApplyBar)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('stay_filter_apply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.action,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: widget.onApply,
                    child: Text(
                      widget.resultCount == 0
                          ? 'Apply'
                          : 'Show ${widget.resultCount} '
                                '${widget.resultCount == 1 ? 'property' : 'properties'}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _commitPrice(RangeValues values) {
    final ceiling = widget.priceCeiling > 0 ? widget.priceCeiling : 20000.0;
    final start = values.start <= 0 ? null : values.start;
    final end = values.end >= ceiling ? null : values.end;
    widget.onChanged(
      widget.filter.copyWith(minPrice: () => start, maxPrice: () => end),
    );
  }

  List<Widget> _propertyRows() {
    final rows = <Widget>[];
    for (final option in StayResultsFilterEngine.propertyOptions(
      isPg: widget.isPg,
    )) {
      final selected = widget.filter.propertyTypes.contains(option.$1);
      final count = StayResultsFilterEngine.count(
        widget.venues,
        widget.filter
            .without(StayFacet.propertyType)
            .copyWith(propertyTypes: {option.$1}),
        isPg: widget.isPg,
      );
      rows.add(
        _CheckRow(
          key: Key('stay_property_${option.$1}'),
          label: option.$2,
          count: count,
          selected: selected,
          onChanged: (value) {
            final next = {...widget.filter.propertyTypes};
            if (value) {
              next.add(option.$1);
            } else {
              next.remove(option.$1);
            }
            widget.onChanged(widget.filter.copyWith(propertyTypes: next));
          },
        ),
      );
    }
    return rows;
  }

  List<Widget> _popularRows() {
    final filter = widget.filter;
    final rows = <Widget>[];
    void add({
      required String key,
      required String label,
      required bool selected,
      required int count,
      required ValueChanged<bool> onChanged,
    }) {
      rows.add(
        _CheckRow(
          key: Key(key),
          label: label,
          count: count,
          selected: selected,
          onChanged: onChanged,
        ),
      );
    }

    add(
      key: 'stay_popular_cancellation',
      label: 'Free cancellation',
      selected: filter.freeCancellation,
      count: StayResultsFilterEngine.count(
        widget.venues,
        filter.copyWith(freeCancellation: true),
        isPg: widget.isPg,
      ),
      onChanged: (value) =>
          widget.onChanged(filter.copyWith(freeCancellation: value)),
    );
    add(
      key: 'stay_popular_breakfast',
      label: 'Breakfast included',
      selected: filter.breakfast,
      count: StayResultsFilterEngine.count(
        widget.venues,
        filter.copyWith(breakfast: true),
        isPg: widget.isPg,
      ),
      onChanged: (value) => widget.onChanged(filter.copyWith(breakfast: value)),
    );
    add(
      key: 'stay_popular_parking',
      label: 'Parking',
      selected: filter.parking,
      count: StayResultsFilterEngine.count(
        widget.venues,
        filter.copyWith(parking: true),
        isPg: widget.isPg,
      ),
      onChanged: (value) => widget.onChanged(filter.copyWith(parking: value)),
    );
    add(
      key: 'stay_popular_rating',
      label: 'Very good: 4+',
      selected: filter.minRating == 4,
      count: StayResultsFilterEngine.count(
        widget.venues,
        filter.without(StayFacet.rating).copyWith(minRating: () => 4),
        isPg: widget.isPg,
      ),
      onChanged: (value) =>
          widget.onChanged(filter.copyWith(minRating: () => value ? 4 : null)),
    );
    if (!widget.isPg) {
      add(
        key: 'stay_popular_stars',
        label: '4 stars',
        selected: filter.starClasses.contains(4),
        count: StayResultsFilterEngine.count(
          widget.venues,
          filter.without(StayFacet.stars).copyWith(starClasses: {4}),
          isPg: widget.isPg,
        ),
        onChanged: (value) {
          final next = {...filter.starClasses};
          if (value) {
            next.add(4);
          } else {
            next.remove(4);
          }
          widget.onChanged(filter.copyWith(starClasses: next));
        },
      );
    }
    return rows;
  }

  List<Widget> _starRows() {
    final rows = <Widget>[];
    for (final stars in [5, 4, 3, 2, 1, 0]) {
      final selected = widget.filter.starClasses.contains(stars);
      final count = StayResultsFilterEngine.count(
        widget.venues,
        widget.filter.without(StayFacet.stars).copyWith(starClasses: {stars}),
        isPg: false,
      );
      rows.add(
        _CheckRow(
          key: Key('stay_star_$stars'),
          label: stars == 0 ? 'Unrated' : '$stars stars',
          count: count,
          selected: selected,
          labelChild: stars == 0
              ? null
              : Row(
                  children: [
                    for (var index = 0; index < stars; index++)
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFFFB700),
                      ),
                  ],
                ),
          onChanged: (value) {
            final next = {...widget.filter.starClasses};
            if (value) {
              next.add(stars);
            } else {
              next.remove(stars);
            }
            widget.onChanged(widget.filter.copyWith(starClasses: next));
          },
        ),
      );
    }
    return rows;
  }

  List<Widget> _facilityRows() {
    final labels = StayResultsFilterEngine.facilityLabels(widget.venues);
    final ranked = <({String key, String label, int count, bool selected})>[];
    for (final entry in labels.entries) {
      final selected = widget.filter.facilities.contains(entry.key);
      final count = StayResultsFilterEngine.count(
        widget.venues,
        widget.filter.copyWith(
          facilities: {...widget.filter.facilities, entry.key},
        ),
        isPg: widget.isPg,
      );
      ranked.add((
        key: entry.key,
        label: entry.value,
        count: count,
        selected: selected,
      ));
    }
    ranked.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    final visible = _showAllFacilities ? ranked : ranked.take(5).toList();
    final rows = <Widget>[
      for (final item in visible)
        _CheckRow(
          key: Key('stay_facility_${item.key}'),
          label: item.label,
          count: item.count,
          selected: item.selected,
          onChanged: (value) {
            final next = {...widget.filter.facilities};
            if (value) {
              next.add(item.key);
            } else {
              next.remove(item.key);
            }
            widget.onChanged(widget.filter.copyWith(facilities: next));
          },
        ),
    ];
    if (ranked.length > 5) {
      rows.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('stay_facilities_toggle'),
            onPressed: () =>
                setState(() => _showAllFacilities = !_showAllFacilities),
            child: Text(
              _showAllFacilities ? 'Show less' : 'Show all ${ranked.length}',
            ),
          ),
        ),
      );
    }
    return rows;
  }

  List<Widget> _reviewRows() {
    final rows = <Widget>[];
    for (final option in StayReviewCopy.thresholds) {
      final selected = widget.filter.minRating == option.$1;
      final count = StayResultsFilterEngine.count(
        widget.venues,
        widget.filter
            .without(StayFacet.rating)
            .copyWith(minRating: () => option.$1),
        isPg: widget.isPg,
      );
      rows.add(
        _CheckRow(
          key: Key('stay_review_${option.$1}'),
          label: option.$2,
          count: count,
          selected: selected,
          onChanged: (value) => widget.onChanged(
            widget.filter.copyWith(minRating: () => value ? option.$1 : null),
          ),
        ),
      );
    }
    return rows;
  }

  List<Widget> _distanceRows() {
    final rows = <Widget>[];
    for (final km in const [1.0, 3.0, 5.0]) {
      final selected = widget.filter.maxDistanceKm == km;
      final count = StayResultsFilterEngine.count(
        widget.venues,
        widget.filter
            .without(StayFacet.distance)
            .copyWith(maxDistanceKm: () => km),
        isPg: widget.isPg,
      );
      final label = km == 1 ? 'Less than 1 km' : 'Less than ${km.toInt()} km';
      rows.add(
        _CheckRow(
          key: Key('stay_distance_$km'),
          label: label,
          count: count,
          selected: selected,
          onChanged: (value) => widget.onChanged(
            widget.filter.copyWith(maxDistanceKm: () => value ? km : null),
          ),
        ),
      );
    }
    return rows;
  }

  int? _divisions(double ceiling) {
    if (ceiling <= 0) return null;
    final step = ceiling >= 5000 ? 500 : (ceiling >= 1000 ? 100 : 50);
    final divisions = (ceiling / step).round();
    return divisions < 1 ? null : divisions;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onChanged,
    this.labelChild,
  });

  final String label;
  final int count;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget? labelChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: IgnorePointer(
                child: Checkbox(
                  value: selected,
                  onChanged: (_) {},
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  labelChild ??
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceHistogram extends StatelessWidget {
  const _PriceHistogram({
    required this.venues,
    required this.ceiling,
    required this.min,
    required this.max,
  });

  final List<Venue> venues;
  final double ceiling;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const buckets = 24;
    final counts = List<int>.filled(buckets, 0);
    for (final venue in venues) {
      if (venue.price <= 0 || ceiling <= 0) continue;
      final index = ((venue.price / ceiling) * buckets).floor().clamp(
        0,
        buckets - 1,
      );
      counts[index]++;
    }
    final peak = counts.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < buckets; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _inRange(index, buckets)
                        ? AppTheme.action
                        : scheme.outlineVariant,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                  child: SizedBox(
                    height: peak == 0 ? 2 : 8 + (34 * counts[index] / peak),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _inRange(int index, int buckets) {
    if (ceiling <= 0) return false;
    final start = ceiling * index / buckets;
    final end = ceiling * (index + 1) / buckets;
    return end >= min && start <= max;
  }
}

/// Always-visible filter chips. The groups are a fixed catalog, the same way
/// BookMyShow shows Languages, Genres and Format before any result arrives.
class StayFilterChipBar extends StatelessWidget {
  const StayFilterChipBar({
    super.key,
    required this.filter,
    required this.isPg,
    required this.priceCeiling,
    required this.onChanged,
    required this.onOpenAll,
  });

  final StayResultsFilter filter;
  final bool isPg;
  final double priceCeiling;
  final ValueChanged<StayResultsFilter> onChanged;
  final VoidCallback onOpenAll;

  double get _ceiling => priceCeiling > 0 ? priceCeiling : 20000.0;

  @override
  Widget build(BuildContext context) {
    final propertyLabel = _joined(
      StayResultsFilterEngine.propertyOptions(isPg: isPg)
          .where((option) => filter.propertyTypes.contains(option.$1))
          .map((option) => option.$2),
      'Property type',
    );
    final starLabel = filter.starClasses.isEmpty
        ? 'Property rating'
        : (filter.starClasses.length == 1
              ? (filter.starClasses.single == 0
                    ? 'Unrated'
                    : '${filter.starClasses.single} stars')
              : 'Property rating (${filter.starClasses.length})');
    final reviewLabel =
        StayReviewCopy.thresholds
            .where((option) => filter.minRating == option.$1)
            .map((option) => option.$2)
            .firstOrNull ??
        'Review score';
    final budgetActive = filter.minPrice != null || filter.maxPrice != null;
    final budgetLabel = budgetActive
        ? '${formatInr(filter.minPrice ?? 0)} – ${formatInr(filter.maxPrice ?? _ceiling)}'
        : 'Budget';

    return SizedBox(
      key: const Key('stay_filter_chips'),
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _DropChip(
            key: const Key('stay_open_filters'),
            label: filter.activeCount == 0
                ? 'Filters'
                : 'Filters (${filter.activeCount})',
            icon: Icons.tune_rounded,
            selected: filter.activeCount > 0,
            dropdown: false,
            onTap: onOpenAll,
          ),
          _DropChip(
            key: const Key('stay_chip_property'),
            label: propertyLabel,
            selected: filter.propertyTypes.isNotEmpty,
            onTap: () => _openMulti(
              context,
              title: 'Property type',
              options: [
                for (final option in StayResultsFilterEngine.propertyOptions(
                  isPg: isPg,
                ))
                  (option.$1, option.$2),
              ],
              selected: filter.propertyTypes,
              onApply: (next) =>
                  onChanged(filter.copyWith(propertyTypes: next)),
            ),
          ),
          if (!isPg)
            _DropChip(
              key: const Key('stay_chip_stars'),
              label: starLabel,
              selected: filter.starClasses.isNotEmpty,
              onTap: () => _openMulti(
                context,
                title: 'Property rating',
                options: [
                  for (final stars in [5, 4, 3, 2, 1, 0])
                    ('$stars', stars == 0 ? 'Unrated' : '$stars stars'),
                ],
                selected: filter.starClasses.map((stars) => '$stars').toSet(),
                onApply: (next) => onChanged(
                  filter.copyWith(starClasses: next.map(int.parse).toSet()),
                ),
              ),
            ),
          _DropChip(
            key: const Key('stay_chip_review'),
            label: reviewLabel,
            selected: filter.minRating != null,
            onTap: () => _openSingle(
              context,
              title: 'Review score',
              options: [
                for (final option in StayReviewCopy.thresholds)
                  (option.$1.toString(), option.$2),
              ],
              selected: filter.minRating?.toString(),
              onApply: (next) => onChanged(
                filter.copyWith(
                  minRating: () => next == null ? null : double.parse(next),
                ),
              ),
            ),
          ),
          _DropChip(
            key: const Key('stay_chip_budget'),
            label: budgetLabel,
            selected: budgetActive,
            onTap: () => _openBudgetSheet(context),
          ),
          _DropChip(
            label: 'Free cancellation',
            selected: filter.freeCancellation,
            dropdown: false,
            onTap: () => onChanged(
              filter.copyWith(freeCancellation: !filter.freeCancellation),
            ),
          ),
          _DropChip(
            label: 'Breakfast included',
            selected: filter.breakfast,
            dropdown: false,
            onTap: () =>
                onChanged(filter.copyWith(breakfast: !filter.breakfast)),
          ),
          _DropChip(
            label: 'Parking',
            selected: filter.parking,
            dropdown: false,
            onTap: () => onChanged(filter.copyWith(parking: !filter.parking)),
          ),
        ],
      ),
    );
  }

  String _joined(Iterable<String> labels, String fallback) {
    final text = labels.join(', ');
    return text.isEmpty ? fallback : text;
  }

  Future<void> _openMulti(
    BuildContext context, {
    required String title,
    required List<(String, String)> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final draft = {...selected};
        return StatefulBuilder(
          builder: (context, setLocal) {
            return _CatalogSheet(
              title: title,
              onClear: () {
                onApply(const {});
                Navigator.pop(context);
              },
              onApply: () {
                onApply(draft);
                Navigator.pop(context);
              },
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    CheckboxListTile(
                      key: Key('stay_sheet_${option.$1}'),
                      value: draft.contains(option.$1),
                      title: Text(option.$2),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setLocal(() {
                        if (checked ?? false) {
                          draft.add(option.$1);
                        } else {
                          draft.remove(option.$1);
                        }
                      }),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSingle(
    BuildContext context, {
    required String title,
    required List<(String, String)> options,
    required String? selected,
    required ValueChanged<String?> onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = selected;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return _CatalogSheet(
              title: title,
              onClear: () {
                onApply(null);
                Navigator.pop(context);
              },
              onApply: () {
                onApply(draft);
                Navigator.pop(context);
              },
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    CheckboxListTile(
                      value: draft == option.$1,
                      title: Text(option.$2),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setLocal(
                        () => draft = (checked ?? false) ? option.$1 : null,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openBudgetSheet(BuildContext context) async {
    var values = RangeValues(filter.minPrice ?? 0, filter.maxPrice ?? _ceiling);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => _CatalogSheet(
          title: 'Your budget',
          onClear: () {
            onChanged(
              filter.copyWith(minPrice: () => null, maxPrice: () => null),
            );
            Navigator.pop(context);
          },
          onApply: () {
            final start = values.start <= 0 ? null : values.start;
            final end = values.end >= _ceiling ? null : values.end;
            onChanged(
              filter.copyWith(minPrice: () => start, maxPrice: () => end),
            );
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formatInr(values.start)} – ${formatInr(values.end)}'
                  ' ${isPg ? 'per month' : 'per night'}',
                ),
                RangeSlider(
                  min: 0,
                  max: _ceiling,
                  divisions: _ceiling >= 5000 ? 40 : 20,
                  values: RangeValues(
                    values.start.clamp(0, _ceiling).toDouble(),
                    values.end.clamp(0, _ceiling).toDouble(),
                  ),
                  onChanged: (next) => setLocal(() => values = next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogSheet extends StatelessWidget {
  const _CatalogSheet({
    required this.title,
    required this.child,
    required this.onClear,
    required this.onApply,
  });

  final String title;
  final Widget child;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Flexible(child: child),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(onPressed: onClear, child: const Text('Clear')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.action,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: onApply,
                      child: const Text('Apply'),
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

class _DropChip extends StatelessWidget {
  const _DropChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dropdown = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = selected
        ? AppTheme.action
        : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.action.withValues(alpha: 0.12)
            : theme.colorScheme.surface,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppTheme.action),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (dropdown)
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: selected
                        ? AppTheme.action
                        : theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
