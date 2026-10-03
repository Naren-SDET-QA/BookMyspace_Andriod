import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../booking/domain/booking.dart';
import '../../../booking/domain/slot_demand.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../booking/presentation/widgets/peak_booking_hours_card.dart';

/// Card showing crowd density for the user's currently selected slot or peak recommendation.
/// e.g. "6 PM · Peak Crowd · 90% Booked". Updates when slot changes.
class SelectedSlotCrowdCard extends ConsumerWidget {
  const SelectedSlotCrowdCard({
    super.key,
    required this.venueId,
    this.selectedSlot,
  });

  final String venueId;
  final SlotAvailability? selectedSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dayType = DemandDayType.of(now);
    final forecastAsync = ref.watch(venueDemandForecastProvider((venueId, dayType)));

    return forecastAsync.maybeWhen(
      data: (forecast) {
        if (forecast.hours.isEmpty) return const SizedBox.shrink();

        final int focusHour;
        final bool isExplicitSlot;
        final parsedHour = selectedSlot != null && selectedSlot!.startTime.isNotEmpty
            ? SlotDemandForecast.hourOf(selectedSlot!.startTime)
            : null;
        if (parsedHour != null) {
          focusHour = parsedHour;
          isExplicitSlot = true;
        } else {
          focusHour = forecast.peak?.hour ?? 18;
          isExplicitSlot = false;
        }

        final demand = forecast.forHour(focusHour) ??
            forecast.peak ??
            forecast.hours.first;

        final color = crowdColor(demand.level);

        return Container(
          key: const Key('selected_slot_crowd_card'),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              // Hour indicator bubble
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  demand.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Status and Advice
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            demand.level.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isExplicitSlot)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Selected Slot',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          )
                        else
                          Text(
                            'Typical peak time',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Occupancy Percentage
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
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
