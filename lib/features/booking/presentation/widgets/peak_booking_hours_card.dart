import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/slot_demand.dart';
import '../booking_providers.dart';

const _quietColor = Color(0xFF10B981);
const _moderateColor = Color(0xFFF59E0B);
const _peakColor = Color(0xFFEF4444);

Color crowdColor(CrowdLevel level) => switch (level) {
  CrowdLevel.quiet => _quietColor,
  CrowdLevel.moderate => _moderateColor,
  CrowdLevel.peak => _peakColor,
};

/// "Peak Booking Hours" card shown while booking: popular times and crowd
/// density for the venue, from real upcoming slot occupancy.
///
/// The day filter follows [selectedDate] (weekday / weekend), and the
/// detail row follows [selectedSlotStart] so the customer sees how busy the
/// slot they picked usually is.
///
/// Availability for the forecast window is only requested once the card is
/// expanded, so a collapsed card on phones costs no extra network calls.
class PeakBookingHoursCard extends ConsumerStatefulWidget {
  const PeakBookingHoursCard({
    super.key,
    required this.venueId,
    required this.selectedDate,
    this.selectedSlotStart,
    this.initiallyExpanded = false,
  });

  final String venueId;
  final DateTime selectedDate;

  /// `HH:mm[:ss]` start time of the chosen slot, if any.
  final String? selectedSlotStart;
  final bool initiallyExpanded;

  @override
  ConsumerState<PeakBookingHoursCard> createState() =>
      _PeakBookingHoursCardState();
}

class _PeakBookingHoursCardState extends ConsumerState<PeakBookingHoursCard> {
  late DemandDayType _dayType = DemandDayType.of(widget.selectedDate);
  late bool _expanded = widget.initiallyExpanded;
  bool _opened = false;
  int? _inspectedHour;

  @override
  void didUpdateWidget(covariant PeakBookingHoursCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _dayType = DemandDayType.of(widget.selectedDate);
      _inspectedHour = null;
    }
    if (oldWidget.selectedSlotStart != widget.selectedSlotStart) {
      _inspectedHour = null; // follow the newly picked slot
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Lazy: nothing is fetched until the customer first opens the card.
    // After that the data stays watched (cached) while the screen is open,
    // so collapsing and re-opening does not refetch.
    if (_expanded) _opened = true;
    final AsyncValue<SlotDemandForecast>? forecast = _opened
        ? ref.watch(venueDemandForecastProvider((widget.venueId, _dayType)))
        : null;

    return Card(
      key: const Key('peak_booking_hours_card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('peak_booking_hours_toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.14,
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peak Booking Hours',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          // Wraps rather than truncating on narrow phones
                          // and with large text.
                          _summary(forecast),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _LiveChip(),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: forecast!.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const _Message(
                  'Crowd data is unavailable right now.',
                ),
                data: _body,
              ),
            ),
        ],
      ),
    );
  }

  String _summary(AsyncValue<SlotDemandForecast>? forecast) {
    final f = forecast?.valueOrNull;
    if (f == null) return 'Popular times & crowd density';
    if (f.hours.isEmpty) return 'No open slots in the next two weeks';
    if (!f.hasSignal) return 'No bookings yet: every slot is quiet';
    return 'Best ${f.best!.label} · Busiest ${f.peak!.label}';
  }

  Widget _body(SlotDemandForecast forecast) {
    final children = <Widget>[
      _DayToggle(
        value: _dayType,
        onChanged: (value) => setState(() {
          _dayType = value;
          _inspectedHour = null;
        }),
      ),
      const SizedBox(height: 12),
    ];

    if (forecast.hours.isEmpty) {
      children.add(
        _Message(
          'No open ${_dayType.noun} slots in the next '
          '$venueDemandWindowDays days.',
        ),
      );
    } else if (!forecast.hasSignal) {
      children.add(
        const _Message(
          'No bookings yet in the next two weeks, so every slot is quiet. '
          'Popular times appear here as people book.',
        ),
      );
    } else {
      // The picked slot only maps onto this chart when the chart shows the
      // same day type as the picked date.
      final slotHour =
          widget.selectedSlotStart == null ||
              DemandDayType.of(widget.selectedDate) != _dayType
          ? null
          : SlotDemandForecast.hourOf(widget.selectedSlotStart!);
      final focusHour = _inspectedHour ?? slotHour ?? forecast.peak!.hour;
      final focus = forecast.forHour(focusHour) ?? forecast.peak!;
      children.addAll([
        Row(
          children: [
            Expanded(
              child: _StatTile(
                key: const Key('peak_best_time'),
                icon: Icons.check_circle_rounded,
                title: 'Best Visit Time',
                demand: forecast.best!,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                key: const Key('peak_highest'),
                icon: Icons.local_fire_department_rounded,
                title: 'Highest Peak',
                demand: forecast.peak!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tap any point to inspect that hour',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        _DemandChart(
          hours: forecast.hours,
          focusHour: focus.hour,
          onTapHour: (hour) => setState(() => _inspectedHour = hour),
        ),
        const SizedBox(height: 12),
        _FocusRow(
          demand: focus,
          isYourSlot: slotHour != null && slotHour == focus.hour,
        ),
        const SizedBox(height: 6),
        Text(
          'Based on ${forecast.sampledDays} upcoming '
          '${_dayType == DemandDayType.weekend ? 'weekend' : 'week'} days.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _peakColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 14, color: _peakColor),
          SizedBox(width: 4),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _peakColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.value, required this.onChanged});

  final DemandDayType value;
  final ValueChanged<DemandDayType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DemandDayType>(
      key: const Key('peak_day_toggle'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: DemandDayType.weekday,
          icon: Icon(Icons.work_outline_rounded, size: 16),
          label: Text('Weekdays'),
        ),
        ButtonSegment(
          value: DemandDayType.weekend,
          icon: Icon(Icons.weekend_outlined, size: 16),
          label: Text('Weekends'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.title,
    required this.demand,
  });

  final IconData icon;
  final String title;
  final HourDemand demand;

  @override
  Widget build(BuildContext context) {
    final color = crowdColor(demand.level);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title, // wraps on narrow tiles instead of truncating
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            demand.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${demand.percent.round()}% booked (${demand.level.label})',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.demand, required this.isYourSlot});

  final HourDemand demand;
  final bool isYourSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = crowdColor(demand.level);
    return Container(
      key: const Key('peak_focus_row'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isYourSlot ? 'Your slot · ${demand.label}' : demand.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        demand.level.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  demand.level.advice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${demand.percent.round()}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                'Booked',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Smoothed occupancy line with a gradient fill, crowd-coloured points and
/// a dashed marker on the focused hour. Tapping picks the nearest hour.
class _DemandChart extends StatelessWidget {
  const _DemandChart({
    required this.hours,
    required this.focusHour,
    required this.onTapHour,
  });

  final List<HourDemand> hours;
  final int focusHour;
  final ValueChanged<int> onTapHour;

  static const _height = 170.0;
  // Bottom padding leaves room for the hour labels painted under the line.
  static const _pad = EdgeInsets.fromLTRB(28, 10, 14, 24);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: const Key('peak_chart'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final hour = _nearestHour(details.localPosition.dx, width);
            if (hour != null) onTapHour(hour);
          },
          child: Semantics(
            label: 'Hourly crowd chart',
            child: CustomPaint(
              size: Size(width, _height),
              painter: _DemandPainter(
                hours: hours,
                focusHour: focusHour,
                line: theme.colorScheme.primary,
                grid: theme.dividerColor.withValues(alpha: 0.25),
                label: theme.colorScheme.onSurfaceVariant,
                padding: _pad,
              ),
            ),
          ),
        );
      },
    );
  }

  int? _nearestHour(double dx, double width) {
    if (hours.isEmpty) return null;
    if (hours.length == 1) return hours.first.hour;
    final usable = width - _pad.left - _pad.right;
    final t = ((dx - _pad.left) / usable).clamp(0.0, 1.0);
    final index = (t * (hours.length - 1)).round();
    return hours[index].hour;
  }
}

class _DemandPainter extends CustomPainter {
  _DemandPainter({
    required this.hours,
    required this.focusHour,
    required this.line,
    required this.grid,
    required this.label,
    required this.padding,
  });

  final List<HourDemand> hours;
  final int focusHour;
  final Color line;
  final Color grid;
  final Color label;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    final left = padding.left;
    final top = padding.top;
    final w = size.width - padding.left - padding.right;
    final h = size.height - padding.top - padding.bottom;

    // Grid + y labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final pct in const [0, 50, 100]) {
      final y = top + h * (1 - pct / 100);
      _dashed(canvas, Offset(left, y), Offset(left + w, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$pct%',
          style: TextStyle(fontSize: 9, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final points = <Offset>[
      for (var i = 0; i < hours.length; i++)
        Offset(
          hours.length == 1 ? left + w / 2 : left + w * i / (hours.length - 1),
          top + h * (1 - hours[i].percent / 100),
        ),
    ];
    if (points.isEmpty) return;

    // Hour labels sit exactly under their points; thinned to ~6 so they
    // never collide, always keeping the last hour.
    final step = hours.length <= 6 ? 1 : (hours.length / 6).ceil();
    for (var i = 0; i < hours.length; i++) {
      final last = i == hours.length - 1;
      if (i % step != 0 && !last) continue;
      if (last && i % step != 0 && i - (i ~/ step) * step < step / 2) {
        continue; // too close to the previous label
      }
      final tp = TextPainter(
        text: TextSpan(
          text: hours[i].label,
          style: TextStyle(fontSize: 9, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (points[i].dx - tp.width / 2).clamp(
        0.0,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(x, top + h + 8));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, top + h)
      ..lineTo(points.first.dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.35), line.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < points.length; i++) {
      final focused = hours[i].hour == focusHour;
      final color = crowdColor(hours[i].level);
      if (focused) {
        _dashed(
          canvas,
          Offset(points[i].dx, top),
          Offset(points[i].dx, top + h),
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          points[i],
          9,
          Paint()..color = color.withValues(alpha: 0.25),
        );
      }
      canvas.drawCircle(points[i], focused ? 5.5 : 3.5, Paint()..color = color);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = (d + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DemandPainter old) =>
      old.hours != hours ||
      old.focusHour != focusHour ||
      old.line != line ||
      old.grid != grid;
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        key: const Key('peak_message'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
