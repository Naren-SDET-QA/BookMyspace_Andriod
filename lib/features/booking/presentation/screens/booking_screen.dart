import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../venues/domain/listing_template.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/listing_availability.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';

/// Booking flow: pick a date, pick an available slot, and submit an owner
/// approval request.
///
/// The slot lock is acquired atomically on the server (via the
/// `create-booking-hold` Edge Function) when the user submits. The server
/// returns an `awaiting_owner_approval` booking; payment is intentionally not
/// available until the venue owner accepts it.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.venue});

  final Venue venue;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime? _selectedDate;
  SlotAvailability? _selectedSlot;
  bool _confirming = false;
  final Map<String, String> _extraValues = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final date = _selectedDate;
    final template = widget.venue.listingTemplate;

    return Scaffold(
      appBar: AppBar(title: Text(template.ctaBook)),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayoutBuilder(
              builder: (context, responsive) {
                final extras = _BookingExtraFields(
                  fields: template.bookingFields,
                  values: _extraValues,
                  onChanged: (key, value) =>
                      setState(() => _extraValues[key] = value),
                );
                final slots = ListingSlotList(
                  venueId: widget.venue.id,
                  date: date,
                  selectedSlot: _selectedSlot,
                  onSelected: (slot) => setState(() => _selectedSlot = slot),
                );
                if (responsive.isExpanded || responsive.isExtraWide) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            _VenueHeader(venue: widget.venue),
                            extras,
                            ListingDateStrip(
                              selected: date,
                              onSelected: (d) {
                                setState(() {
                                  _selectedDate = d;
                                  _selectedSlot = null;
                                });
                              },
                            ),
                            Expanded(child: slots),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: _selectedSlot == null
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Select an available slot'),
                                ),
                              )
                            : _ConfirmBar(
                                venue: widget.venue,
                                date: date,
                                slot: _selectedSlot!,
                                confirming: _confirming,
                                ctaLabel: template.ctaBook,
                                onConfirm: () => _confirmBooking(date),
                              ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _VenueHeader(venue: widget.venue),
                    extras,
                    const Divider(height: 1),
                    ListingDateStrip(
                      selected: date,
                      onSelected: (d) {
                        setState(() {
                          _selectedDate = d;
                          _selectedSlot = null;
                        });
                      },
                    ),
                    Expanded(child: slots),
                  ],
                );
              },
            ),
      bottomNavigationBar: _selectedSlot != null &&
              date != null &&
              MediaQuery.sizeOf(context).width < 840
          ? _ConfirmBar(
              venue: widget.venue,
              date: date,
              slot: _selectedSlot!,
              confirming: _confirming,
              ctaLabel: template.ctaBook,
              onConfirm: () => _confirmBooking(date),
            )
          : null,
    );
  }

  Future<void> _confirmBooking(DateTime date) async {
    final slot = _selectedSlot;
    if (slot == null || _confirming) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(bookingRepositoryProvider);

    final taxRate = widget.venue.taxRate;
    final amount = slot.priceAmount;
    final tax = (amount * taxRate / 100).roundToDouble();
    final total = amount + tax;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmBooking),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(label: l10n.venueDetails, value: widget.venue.name),
            _SummaryRow(
              label: l10n.selectDate,
              value: DateFormat.yMMMd().format(date),
            ),
            _SummaryRow(
              label: l10n.selectTimeSlot,
              value: '${slot.displayStart} – ${slot.displayEnd}',
            ),
            const Divider(height: 24),
            _SummaryRow(label: l10n.basePrice, value: formatInr(amount)),
            _SummaryRow(label: l10n.taxRate, value: formatInr(tax)),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.total,
              value: formatInr(total),
              emphasize: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _confirming = true);
    try {
      final booking = await repo.requestBooking(
        venueId: widget.venue.id,
        slotId: slot.slotId,
        bookDate: date,
        amount: amount,
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      // This is a request acknowledgement, not a booking confirmation. The
      // server status is rendered by the destination screen.
      unawaited(context.push('/bookings/${booking.id}/success'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}

class _BookingExtraFields extends StatelessWidget {
  const _BookingExtraFields({
    required this.fields,
    required this.values,
    required this.onChanged,
  });

  final List<ListingFieldDefinition> fields;
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final extras = fields
        .where((field) =>
            field.type != ListingFieldType.date &&
            field.type != ListingFieldType.slot)
        .toList(growable: false);
    if (extras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: extras.map((field) {
          final value = values[field.key] ?? '';
          if (field.type == ListingFieldType.dropdown) {
            return SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: Key('booking_field_${field.key}'),
                initialValue: field.options.contains(value) ? value : null,
                decoration: InputDecoration(
                  labelText: field.label,
                ),
                items: field.options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (next) => onChanged(field.key, next ?? ''),
              ),
            );
          }
          if (field.type == ListingFieldType.toggle) {
            return FilterChip(
              key: Key('booking_field_${field.key}'),
              label: Text(field.label),
              selected: value == 'true',
              onSelected: (selected) =>
                  onChanged(field.key, selected ? 'true' : 'false'),
            );
          }
          return SizedBox(
            width: 160,
            child: TextField(
              key: Key('booking_field_${field.key}'),
              keyboardType: field.type == ListingFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: field.placeholder,
              ),
              onChanged: (next) => onChanged(field.key, next),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VenueHeader extends StatelessWidget {
  const _VenueHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (venue.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    venue.address,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (venue.capacity > 0)
            Chip(
              avatar: const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: AppTheme.violet,
              ),
              label: Text('${venue.capacity}'),
            ),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.venue,
    required this.date,
    required this.slot,
    required this.confirming,
    required this.onConfirm,
    this.ctaLabel,
  });

  final Venue venue;
  final DateTime date;
  final SlotAvailability slot;
  final bool confirming;
  final VoidCallback onConfirm;
  final String? ctaLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tax = (slot.priceAmount * venue.taxRate / 100).roundToDouble();
    final total = slot.priceAmount + tax;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.total,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  formatInr(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.violet,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: confirming ? null : onConfirm,
                icon: confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_rounded),
                label: Text(ctaLabel ?? l10n.confirmBooking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: emphasize
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: emphasize ? AppTheme.violet : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
