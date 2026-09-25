import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../domain/venue.dart';
import 'venue_badges.dart';

/// Horizontal 14-day date picker used by listing detail and booking.
class ListingDateStrip extends StatelessWidget {
  const ListingDateStrip({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      14,
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected = date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
          return _DateChip(
            date: date,
            isSelected: isSelected,
            onTap: () => onSelected(date),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = DateFormat('EEE').format(date);
    final dayNum = DateFormat('d').format(date);
    final month = DateFormat('MMM').format(date);

    return Semantics(
      button: true,
      selected: isSelected,
      label: DateFormat.yMMMd().format(date),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 60,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.violet : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.violet
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dayNum,
                style: theme.textTheme.titleMedium?.copyWith(
                  color:
                      isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                month,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white70
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live slot list for a venue/date. Unavailable slots stay visible but disabled.
class ListingSlotList extends ConsumerWidget {
  const ListingSlotList({
    super.key,
    required this.venueId,
    required this.date,
    required this.selectedSlot,
    required this.onSelected,
    this.shrinkWrap = false,
  });

  final String venueId;
  final DateTime date;
  final SlotAvailability? selectedSlot;
  final ValueChanged<SlotAvailability> onSelected;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final availability = ref.watch(
      slotAvailabilityProvider(
        SlotAvailabilityQuery(venueId: venueId, date: date),
      ),
    );

    return availability.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(
          slotAvailabilityProvider(
            SlotAvailabilityQuery(venueId: venueId, date: date),
          ),
        ),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_rounded,
            title: l10n.noSlotsForDate,
          );
        }
        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final slot = slots[i];
            final isSelected = selectedSlot?.slotId == slot.slotId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SlotTile(
                slot: slot,
                isSelected: isSelected,
                onTap: slot.isAvailable ? () => onSelected(slot) : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final SlotAvailability slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = slot.isAvailable;

    return Material(
      color: isSelected
          ? AppTheme.violet.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              isSelected ? AppTheme.violet : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          button: true,
          enabled: enabled,
          selected: isSelected,
          label:
              '${slot.label} ${slot.displayStart} to ${slot.displayEnd} ${enabled ? formatInr(slot.priceAmount) : _reasonLabel(slot.reason)}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${slot.displayStart} – ${slot.displayEnd}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!enabled)
                  Text(
                    _reasonLabel(slot.reason),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    formatInr(slot.priceAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.violet,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _reasonLabel(String reason) {
    return switch (reason) {
      'booked' => 'Full',
      'held' => 'Unavailable',
      'blocked' => 'Blocked',
      'closed' => 'Closed',
      'inactive' => 'Closed',
      _ => 'Unavailable',
    };
  }
}

Future<SlotAvailability?> showListingAvailabilitySheet({
  required BuildContext context,
  required Venue venue,
  DateTime? initialDate,
  SlotAvailability? initialSlot,
}) {
  return showModalBottomSheet<SlotAvailability>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return _AvailabilitySheet(
        venue: venue,
        initialDate: initialDate ?? DateTime.now(),
        initialSlot: initialSlot,
      );
    },
  );
}

class _AvailabilitySheet extends StatefulWidget {
  const _AvailabilitySheet({
    required this.venue,
    required this.initialDate,
    this.initialSlot,
  });

  final Venue venue;
  final DateTime initialDate;
  final SlotAvailability? initialSlot;

  @override
  State<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<_AvailabilitySheet> {
  late DateTime _date;
  SlotAvailability? _slot;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _slot = widget.initialSlot;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final template = widget.venue.listingTemplate;
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    template.ctaAvailability,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          ListingDateStrip(
            selected: _date,
            onSelected: (date) => setState(() {
              _date = date;
              _slot = null;
            }),
          ),
          Expanded(
            child: ListingSlotList(
              venueId: widget.venue.id,
              date: _date,
              selectedSlot: _slot,
              onSelected: (slot) => setState(() => _slot = slot),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const Key('availability_confirm'),
                onPressed:
                    _slot == null ? null : () => Navigator.pop(context, _slot),
                child: Text(
                  _slot == null
                      ? template.ctaAvailability
                      : '${template.ctaBook} · ${formatInr(_slot!.priceAmount)}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
