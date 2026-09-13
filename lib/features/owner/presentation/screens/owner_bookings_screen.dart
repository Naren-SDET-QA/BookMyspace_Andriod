import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../owner_providers.dart';

class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  final Set<String> _updating = <String>{};
  RealtimeChannel? _bookingChannel;

  @override
  void initState() {
    super.initState();
    try {
      final client = ref.read(supabaseProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        _bookingChannel = client
            .channel('owner-bookings-${user.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'bookings',
              callback: (_) {
                if (mounted) ref.invalidate(ownerVenueBookingsProvider);
              },
            )
            .subscribe();
      }
    } on AssertionError {
      // The role-gated screen can be rendered by preview tests without a
      // configured Supabase client; the live owner screen is initialized.
    }
  }

  @override
  void dispose() {
    final channel = _bookingChannel;
    if (channel != null) {
      unawaited(ref.read(supabaseProvider).removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _approve(Booking booking) async {
    await _updateBooking(
      booking,
      () => ref.read(bookingRepositoryProvider).approveBooking(booking.id),
    );
  }

  Future<void> _reject(Booking booking) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Decline booking request'),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Tell the customer why the request was declined',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep request'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    await _updateBooking(
      booking,
      () => ref
          .read(bookingRepositoryProvider)
          .rejectBooking(booking.id, reason: reason),
    );
  }

  Future<void> _updateBooking(
    Booking booking,
    Future<Booking> Function() operation,
  ) async {
    if (!_updating.add(booking.id)) return;
    setState(() {});
    try {
      await operation();
      ref.invalidate(ownerVenueBookingsProvider);
      ref.invalidate(ownerDashboardSnapshotProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(booking.id));
      } else {
        _updating.remove(booking.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final bookings = ref.watch(ownerVenueBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venue bookings')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(ownerVenueBookingsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No venue bookings',
                message:
                    'Bookings for spaces you own will appear here after customers reserve them.',
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ownerVenueBookingsProvider);
                  await ref.read(ownerVenueBookingsProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _OwnerBookingTile(
                    booking: items[index],
                    updating: _updating.contains(items[index].id),
                    onApprove: items[index].status ==
                            BookingStatus.awaitingOwnerApproval
                        ? () => _approve(items[index])
                        : null,
                    onReject: items[index].status ==
                            BookingStatus.awaitingOwnerApproval
                        ? () => _reject(items[index])
                        : null,
                  ),
                ),
              ),
      ),
    );
  }
}

class _OwnerBookingTile extends StatelessWidget {
  const _OwnerBookingTile({
    required this.booking,
    required this.updating,
    this.onApprove,
    this.onReject,
  });

  final Booking booking;
  final bool updating;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.venueName.isNotEmpty
                        ? booking.venueName
                        : 'Venue booking',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  booking.status.dbValue,
                  style: TextStyle(
                    color: AppTheme.brandDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                booking.bookingRef,
                DateFormat.yMMMd().format(booking.bookDate),
                if (booking.slotLabel.isNotEmpty) booking.slotLabel,
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              formatInr(booking.totalAmount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: updating ? null : onReject,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: updating ? null : onApprove,
                      child: updating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept & request payment'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
