import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../../venues/domain/listing_template.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/listing_availability.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/booking.dart';
import '../../domain/date_availability.dart';
import '../booking_providers.dart';
import '../widgets/peak_booking_hours_card.dart';
import '../../../offers/domain/coupon.dart';
import '../../../offers/presentation/coupon_providers.dart';
import '../../../admin/domain/platform_status.dart';
import '../../../admin/presentation/platform_status_providers.dart';
import '../../../admin/presentation/widgets/platform_status_banner.dart';

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
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  final Map<String, String> _extraValues = {};
  final TextEditingController _couponController = TextEditingController();
  Coupon? _appliedCoupon;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _customerNameController = TextEditingController(text: user?.fullName ?? '');
    _customerPhoneController = TextEditingController(text: user?.phone ?? '');
    final prefs = ref.read(discoveryBookingPrefsProvider);
    _selectedDate = prefs.day;
    if (prefs.guests > 0) {
      _extraValues['guests'] = '${prefs.guests}';
    }
    final templateId = widget.venue.listingTemplate.templateId;
    if (templateId == 'hotel' && prefs.rooms > 0) {
      _extraValues['rooms'] = '${prefs.rooms}';
    } else if (templateId == 'pg') {
      final sharing = switch (prefs.sharing) {
        'single' => 'Single',
        'double' => 'Double',
        'triple' => 'Triple',
        _ => null,
      };
      if (sharing != null) _extraValues['rooms'] = sharing;
    }
  }

  /// Live slot price, used for coupon minimum-amount validation.
  double? get slotPrice => _selectedSlot?.priceAmount;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  /// Validates the entered code against the venue's active public coupons
  /// (`public.coupons`, RLS-gated to active rows).
  ///
  /// This is a UX gate only. The server remains the sole authority for the
  /// booking total: `request_venue_booking` recomputes base, tax and total
  /// from the live slot and currently books at full price (the RPC accepts no
  /// coupon parameter), so the coupon is recorded as a request note and the
  /// confirm dialog states that the applied offer is settled at payment time.
  void _applyCoupon() {
    final coupons = ref.read(activeCouponsProvider).valueOrNull ?? const [];
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final match = coupons.cast<Coupon?>().firstWhere(
      (c) => c!.code.toUpperCase() == code,
      orElse: () => null,
    );
    String? error;
    if (match == null) {
      error = 'Invalid or expired coupon code';
    } else {
      final price = slotPrice;
      final min = match.minBookingAmount;
      final floor = (min == null || min <= 0) ? 0.0 : min;
      if (price != null && price < floor) {
        error =
            'Requires a minimum booking of \${formatInr(floor)} for this slot';
      }
    }
    setState(() {
      _appliedCoupon = error == null ? match : null;
      _couponError = error;
    });
  }

  /// Availability level of [date] computed from the slots already loaded
  /// for it (same provider instance as the slot list; no extra request).
  DateAvailability? _dateAvailability(DateTime? date) {
    if (date == null) return null;
    final slots = ref
        .watch(
          slotAvailabilityProvider(
            SlotAvailabilityQuery(venueId: widget.venue.id, date: date),
          ),
        )
        .valueOrNull;
    if (slots == null) return null;
    return DateAvailability.evaluate(slots, date);
  }

  @override
  Widget build(BuildContext context) {
    final date = _selectedDate;
    final template = widget.venue.listingTemplate;
    final dateAvailability = _dateAvailability(date);
    final platform =
        ref.watch(platformStatusProvider).valueOrNull ?? PlatformStatus.none;
    final canBook =
        (dateAvailability?.isBookable ?? true) && !platform.maintenanceEnabled;

    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: Text(template.ctaBook),
        bottom: platform.maintenanceEnabled
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: PlatformStatusBanner(status: platform),
              )
            : null,
      ),
      body: date == null
          ? const BookingSummarySkeleton()
          : ResponsiveLayoutBuilder(
              builder: (context, responsive) {
                final extras = _BookingExtraFields(
                  fields: template.bookingFields,
                  values: _extraValues,
                  onChanged: (key, value) =>
                      setState(() => _extraValues[key] = value),
                );
                final couponWidget = _CouponField(
                  controller: _couponController,
                  appliedCoupon: _appliedCoupon,
                  errorText: _couponError,
                  onApply: _applyCoupon,
                  onRemove: () => setState(() {
                    _appliedCoupon = null;
                    _couponError = null;
                    _couponController.clear();
                  }),
                );
                final slots = ListingSlotList(
                  venueId: widget.venue.id,
                  date: date,
                  selectedSlot: _selectedSlot,
                  onSelected: (slot) => setState(() => _selectedSlot = slot),
                );
                if (responsive.isExpanded || responsive.isExtraWide) {
                  // The form sits beside a 320px summary. A fixed column
                  // overflows short desktop windows, so the form scrolls and
                  // the slot list keeps its own viewport.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            _VenueHeader(venue: widget.venue),
                            _BookingContactFields(
                              nameController: _customerNameController,
                              phoneController: _customerPhoneController,
                            ),
                            extras,
                            couponWidget,
                            ListingDateStrip(
                              selected: date,
                              onSelected: (d) {
                                setState(() {
                                  _selectedDate = d;
                                  _selectedSlot = null;
                                });
                              },
                            ),
                            _DateAvailabilityBadge(info: dateAvailability),
                            PeakBookingHoursCard(
                              venueId: widget.venue.id,
                              selectedDate: date,
                              selectedSlotStart: _selectedSlot?.startTime,
                              initiallyExpanded: true,
                            ),
                            SizedBox(height: 440, child: slots),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 320,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _selectedSlot == null
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Select an available slot'),
                                )
                              : _ConfirmBar(
                                  venue: widget.venue,
                                  date: date,
                                  slot: _selectedSlot!,
                                  confirming: _confirming,
                                  ctaLabel: template.ctaBook,
                                  onConfirm: canBook
                                      ? () => _confirmBooking(date)
                                      : null,
                                ),
                        ),
                      ),
                    ],
                  );
                }
                // Phones and portrait tablets: one scroll view for the whole
                // form, so short screens (e.g. 320x568) can still reach the
                // date strip, Peak Booking Hours and every slot. The confirm
                // bar lives in bottomNavigationBar, which the Scaffold lays
                // out below this body, so nothing scrolls underneath it.
                return ListView(
                  key: const Key('booking_phone_scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _VenueHeader(venue: widget.venue),
                    _BookingContactFields(
                      nameController: _customerNameController,
                      phoneController: _customerPhoneController,
                    ),
                    extras,
                    couponWidget,
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
                    _DateAvailabilityBadge(info: dateAvailability),
                    PeakBookingHoursCard(
                      venueId: widget.venue.id,
                      selectedDate: date,
                      selectedSlotStart: _selectedSlot?.startTime,
                    ),
                    ListingSlotList(
                      key: const Key('booking_phone_slots'),
                      venueId: widget.venue.id,
                      date: date,
                      selectedSlot: _selectedSlot,
                      onSelected: (slot) =>
                          setState(() => _selectedSlot = slot),
                      shrinkWrap: true,
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar:
          _selectedSlot != null &&
              date != null &&
              MediaQuery.sizeOf(context).width < 840
          ? _ConfirmBar(
              venue: widget.venue,
              date: date,
              slot: _selectedSlot!,
              confirming: _confirming,
              ctaLabel: template.ctaBook,
              onConfirm: canBook ? () => _confirmBooking(date) : null,
            )
          : null,
    );
  }

  String? _missingRequiredField() {
    for (final field in widget.venue.listingTemplate.bookingFields) {
      if (!field.required || !field.isActive) continue;
      if (field.type == ListingFieldType.date ||
          field.type == ListingFieldType.slot) {
        continue;
      }
      final value = _extraValues[field.key]?.trim() ?? '';
      if (value.isEmpty) return field.label;
    }
    return null;
  }

  String? _registrationError() {
    return AppValidators.name(_customerNameController.text) ??
        AppValidators.phone(_customerPhoneController.text);
  }

  Future<void> _confirmBooking(DateTime date) async {
    final slot = _selectedSlot;
    if (slot == null || _confirming) return;
    final l10n = AppLocalizations.of(context);
    final registrationError = _registrationError();
    if (registrationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(registrationError)));
      return;
    }
    final missing = _missingRequiredField();
    if (missing != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter $missing')));
      return;
    }
    final repo = ref.read(bookingRepositoryProvider);

    final taxRate = widget.venue.taxRate;
    final amount = slot.priceAmount;
    final tax = (amount * taxRate / 100).roundToDouble();
    final total = amount + tax;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmBooking),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _SummaryRow(label: l10n.venueDetails, value: widget.venue.name),
            _SummaryRow(
              label: 'Guest name',
              value: _customerNameController.text.trim(),
            ),
            _SummaryRow(
              label: 'Mobile',
              value: _customerPhoneController.text.trim(),
            ),
            _SummaryRow(
              label: l10n.selectDate,
              value: DateFormat.yMMMd().format(date),
            ),
            _SummaryRow(
              label: l10n.selectTimeSlot,
              value: '${slot.displayStart} – ${slot.displayEnd}',
            ),
            for (final field in widget.venue.listingTemplate.bookingFields)
              if (field.type != ListingFieldType.date &&
                  field.type != ListingFieldType.slot &&
                  (_extraValues[field.key]?.trim().isNotEmpty ?? false))
                _SummaryRow(
                  label: field.label,
                  value: _extraValues[field.key]!.trim(),
                ),
            const Divider(height: 24),
            _SummaryRow(label: l10n.basePrice, value: formatInr(amount)),
            if (_appliedCoupon != null)
              _SummaryRow(
                label: 'Coupon',
                value: '${_appliedCoupon!.code} (settled at payment)',
                discountRow: true,
              ),
            _SummaryRow(label: l10n.taxRate, value: formatInr(tax)),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.total,
              value: formatInr(total),
              emphasize: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request will be routed to venue host for slot approval.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        couponCode: _appliedCoupon?.code,
        metadata: {
          'customer_name': _customerNameController.text.trim(),
          'customer_phone': _customerPhoneController.text.trim(),
          'full_name': _customerNameController.text.trim(),
          'phone': _customerPhoneController.text.trim(),
          ..._extraValues,
        },
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      // This is a request acknowledgement, not a booking confirmation. The
      // server status is rendered by the destination screen.
      unawaited(context.push('/bookings/${booking.id}/success'));
    } on BookingConflictException catch (e) {
      if (!mounted) return;
      if (e.code == 'slot_unavailable') {
        setState(() => _confirming = false);
        await _offerAlternativeSlots(date, slot);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// The chosen slot was taken by someone else: refresh the date's slots and
  /// offer the other currently-free slots on the same date to re-pick.
  Future<void> _offerAlternativeSlots(
    DateTime date,
    SlotAvailability taken,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = slotAvailabilityProvider(
      SlotAvailabilityQuery(venueId: widget.venue.id, date: date),
    );
    ref.invalidate(provider);
    setState(() => _selectedSlot = null);
    List<SlotAvailability> fresh;
    try {
      fresh = await ref.read(provider.future);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This slot was just taken. Please pick another.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final alternatives = DateAvailability.alternatives(
      fresh,
      excludeSlotId: taken.slotId,
    );
    final picked = await showModalBottomSheet<SlotAvailability>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => _AlternativeSlotsSheet(
        date: date,
        taken: taken,
        alternatives: alternatives,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedSlot = picked);
  }
}

class _AlternativeSlotsSheet extends StatelessWidget {
  const _AlternativeSlotsSheet({
    required this.date,
    required this.taken,
    required this.alternatives,
  });

  final DateTime date;
  final SlotAvailability taken;
  final List<SlotAvailability> alternatives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        key: const Key('alternative_slots_sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This slot was just taken',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              alternatives.isEmpty
                  ? 'No other slots are free on '
                        '${DateFormat.yMMMd().format(date)}. '
                        'Please pick another date.'
                  : 'Other free slots on ${DateFormat.yMMMd().format(date)}:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (alternatives.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in alternatives)
                        ActionChip(
                          key: ValueKey('alternative_slot_${slot.slotId}'),
                          avatar: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(
                            '${slot.label.isNotEmpty ? '${slot.label} · ' : ''}'
                            '${slot.displayStart} – ${slot.displayEnd} · '
                            '${formatInr(slot.priceAmount)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => Navigator.of(context).pop(slot),
                        ),
                    ],
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Choose another date'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Availability badge for the selected date ("Sold out", "Limited",
/// "Filling fast", "Past"); hidden while loading or when plenty is free.
class _DateAvailabilityBadge extends StatelessWidget {
  const _DateAvailabilityBadge({required this.info});

  final DateAvailability? info;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    final label = info?.label;
    if (info == null || label == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (info.status) {
      DateAvailabilityStatus.soldOut => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.block_rounded,
      ),
      DateAvailabilityStatus.past => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.history_rounded,
      ),
      DateAvailabilityStatus.limited => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.local_fire_department_rounded,
      ),
      _ => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.trending_up_rounded,
      ),
    };
    final detail = switch (info.status) {
      DateAvailabilityStatus.soldOut => 'No slots left on this date',
      DateAvailabilityStatus.past => 'This date has passed',
      _ => '${info.freeSlots} of ${info.totalSlots} slots free',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        key: const Key('date_availability_badge'),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingContactFields extends StatelessWidget {
  const _BookingContactFields({
    required this.nameController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('booking_customer_name'),
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('booking_customer_phone'),
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              isDense: true,
            ),
          ),
        ],
      ),
    );
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
        .where(
          (field) =>
              field.type != ListingFieldType.date &&
              field.type != ListingFieldType.slot,
        )
        .toList(growable: false);
    if (extras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: extras.map((field) {
            final value = values[field.key] ?? '';
            if (field.type == ListingFieldType.dropdown) {
              // Fills the row on narrow forms, capped on wide ones; the
              // expanded button keeps the selected label inside its box.
              return SizedBox(
                width: constraints.maxWidth < 280 ? constraints.maxWidth : 280,
                child: DropdownButtonFormField<String>(
                  key: Key('booking_field_${field.key}'),
                  isExpanded: true,
                  initialValue: field.options.contains(value) ? value : null,
                  decoration: InputDecoration(labelText: field.label),
                  selectedItemBuilder: (context) => field.options
                      .map(
                        (option) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            option,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
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
              child: TextFormField(
                key: Key('booking_field_${field.key}'),
                initialValue: value,
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
  final VoidCallback? onConfirm;
  final String? ctaLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tax = (slot.priceAmount * venue.taxRate / 100).roundToDouble();
    final total = slot.priceAmount + tax;

    final price = Column(
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
    );
    final button = FilledButton.icon(
      onPressed: confirming ? null : onConfirm,
      icon: confirming
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_rounded),
      label: Text(
        ctaLabel ?? l10n.confirmBooking,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The desktop summary is 320px wide. A price-plus-button row
        // overflows there; phones wider than 360px keep the single row.
        final stack = constraints.maxWidth < 360;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: stack
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      price,
                      const SizedBox(height: 12),
                      button,
                    ],
                  )
                : Row(
                    children: [
                      price,
                      const SizedBox(width: 16),
                      Expanded(child: button),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.discountRow = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool discountRow;

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
                color: discountRow
                    ? Colors.green.shade700
                    : (emphasize
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant),
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
                color: discountRow
                    ? Colors.green.shade700
                    : (emphasize ? AppTheme.violet : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coupon code entry widget — validates against activeCouponsProvider client-side.
class _CouponField extends ConsumerWidget {
  const _CouponField({
    required this.controller,
    required this.onApply,
    required this.onRemove,
    this.appliedCoupon,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final Coupon? appliedCoupon;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (appliedCoupon != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            const Icon(
              Icons.local_offer_rounded,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${appliedCoupon!.code} — ${appliedCoupon!.valueLabel} applied',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Coupon code',
                prefixIcon: const Icon(Icons.local_offer_outlined, size: 20),
                errorText: errorText,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => onApply(),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(top: errorText != null ? 0 : 0),
            child: OutlinedButton(
              onPressed: onApply,
              // The app theme sets minimumSize to Size.fromHeight(52), i.e.
              // infinite width, which crashes layout inside this Row.
              style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
