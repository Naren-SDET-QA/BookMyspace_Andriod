import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exceptions.dart' show AppException;
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/app_role.dart';
import '../../../auth/presentation/role_providers.dart';
import '../../domain/admin_booking_filters.dart';
import '../../domain/listing_moderation.dart';
import '../admin_moderation_providers.dart';

enum AdminOversightKind { bookings, payments, refunds }

class AdminOversightScreen extends ConsumerWidget {
  const AdminOversightScreen({super.key, required this.kind});

  final AdminOversightKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kind == AdminOversightKind.bookings) {
      return const AdminBookingsManagementView();
    }
    final async = switch (kind) {
      AdminOversightKind.bookings => ref.watch(adminBookingsOversightProvider),
      AdminOversightKind.payments => ref.watch(adminPaymentsOversightProvider),
      AdminOversightKind.refunds => ref.watch(adminRefundsOversightProvider),
    };
    final title = switch (kind) {
      AdminOversightKind.bookings => 'Booking oversight',
      AdminOversightKind.payments => 'Payment oversight',
      AdminOversightKind.refunds => 'Refund oversight',
    };
    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: Text(title),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(adminBookingsOversightProvider);
            ref.invalidate(adminPaymentsOversightProvider);
            ref.invalidate(adminRefundsOversightProvider);
          },
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No records',
              message:
                  'No $title rows are visible under current authorization.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _RowCard(row: rows[i]),
          );
        },
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});

  final OversightRow row;

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    final created = row.createdAt;
    return Card(
      child: ListTile(
        title: Text(row.title),
        subtitle: Text(
          [
            row.status,
            row.subtitle,
            if (created != null) DateFormat.yMMMd().format(created),
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        trailing: amount == null
            ? null
            : Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

/// Admin bookings management: status tabs with counts, free-text search, an
/// admin cancellation action for confirmed bookings, and Approve / Decline for
/// booking requests awaiting approval.
///
/// Every request in `awaiting_owner_approval` goes to the venue owner AND the
/// platform administrators; either one may decide and only one decision is
/// needed. `approve_venue_booking` / `reject_venue_booking` enforce that on
/// the server; the buttons are only shown to administrators. Approval moves
/// the request to `pending`; the customer still has to pay.
class AdminBookingsManagementView extends ConsumerStatefulWidget {
  const AdminBookingsManagementView({super.key});

  static const searchFieldKey = Key('admin-bookings-search');
  static Key filterKey(AdminBookingFilter f) =>
      Key('admin-bookings-filter-${f.name}');
  static Key cancelKey(String id) => Key('admin-booking-cancel-$id');
  static Key approveKey(String id) => Key('admin-booking-approve-$id');
  static Key declineKey(String id) => Key('admin-booking-decline-$id');

  @override
  ConsumerState<AdminBookingsManagementView> createState() =>
      _AdminBookingsManagementViewState();
}

class _AdminBookingsManagementViewState
    extends ConsumerState<AdminBookingsManagementView> {
  AdminBookingFilter _filter = AdminBookingFilter.all;
  String _query = '';
  final Set<String> _busy = {};

  Future<void> _cancel(OversightRow row) async {
    final result = await showDialog<_AdminCancelRequest>(
      context: context,
      builder: (_) => _AdminCancelDialog(row: row),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(row.id));
    try {
      await ref
          .read(listingModerationRepositoryProvider)
          .adminCancelBooking(
            bookingId: row.id,
            reason: result.reason,
            refundAmount: result.refundAmount,
          );
      ref.invalidate(adminBookingsOversightProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking cancelled by platform admin')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(row.id));
    }
  }

  /// Codes after which the row must be re-read: someone else already decided
  /// it, or the server moved it to another status.
  static const _staleCodes = {
    'ALREADY_PROCESSED',
    'INVALID_STATUS',
    'APPROVAL_EXPIRED',
    'EXTERNALLY_BOOKED',
  };

  String _errorText(Object e) => e is AppException ? e.message : e.toString();

  Future<void> _approve(OversightRow row) async {
    if (_busy.contains(row.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(row.id));
    try {
      await ref
          .read(listingModerationRepositoryProvider)
          .adminApproveBooking(row.id);
      ref.invalidate(adminBookingsOversightProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request approved. The customer can now pay.'),
        ),
      );
    } catch (e) {
      if (e is AppException && _staleCodes.contains(e.code)) {
        ref.invalidate(adminBookingsOversightProvider);
      }
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(row.id));
    }
  }

  Future<void> _decline(OversightRow row) async {
    if (_busy.contains(row.id)) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _AdminDeclineDialog(row: row),
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(row.id));
    try {
      await ref
          .read(listingModerationRepositoryProvider)
          .adminRejectBooking(row.id, reason: reason);
      ref.invalidate(adminBookingsOversightProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request declined. The slot was released.'),
        ),
      );
    } catch (e) {
      if (e is AppException && _staleCodes.contains(e.code)) {
        ref.invalidate(adminBookingsOversightProvider);
      }
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(row.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminBookingsOversightProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: const Text('Bookings management'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminBookingsOversightProvider),
        ),
        data: (rows) {
          final counts = adminBookingCounts(rows);
          final visible = filterAdminBookings(
            rows,
            filter: _filter,
            query: _query,
          );
          // Roles are only read when a decidable row is on screen. The server
          // re-checks authorization on every approve/decline call.
          final canDecide = visible.any(_isDecidable) && _isPlatformAdmin(ref);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminBookingsOversightProvider);
              await ref.read(adminBookingsOversightProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _CountsRow(counts: counts),
                const SizedBox(height: 12),
                TextField(
                  key: AdminBookingsManagementView.searchFieldKey,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by reference, venue or customer',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in AdminBookingFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: AdminBookingsManagementView.filterKey(f),
                            label: Text('${f.label} (${counts[f] ?? 0})'),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No bookings match',
                      message: 'Try another status tab or search term.',
                    ),
                  )
                else
                  for (final row in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AdminBookingCard(
                        row: row,
                        busy: _busy.contains(row.id),
                        onCancel:
                            AdminBookingFilter.bucketOf(row.status) ==
                                AdminBookingFilter.confirmed
                            ? () => _cancel(row)
                            : null,
                        onApprove: canDecide && _isDecidable(row)
                            ? () => _approve(row)
                            : null,
                        onDecline: canDecide && _isDecidable(row)
                            ? () => _decline(row)
                            : null,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

bool _isPlatformAdmin(WidgetRef ref) {
  final roles =
      ref.watch(currentUserRolesProvider).valueOrNull ?? const <AppRole>{};
  return roles.contains(AppRole.administrator) ||
      roles.contains(AppRole.superAdministrator);
}

/// Only requests still awaiting a decision can be approved or declined.
bool _isDecidable(OversightRow row) =>
    row.status.trim().toLowerCase() == 'awaiting_owner_approval';

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.counts});

  final Map<AdminBookingFilter, int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(String label, int value, {bool highlight = false}) => Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: highlight
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '$value',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
    final pending = counts[AdminBookingFilter.pendingApproval] ?? 0;
    return Row(
      children: [
        tile('Awaiting review', pending, highlight: pending > 0),
        const SizedBox(width: 8),
        tile('Unpaid', counts[AdminBookingFilter.pendingPayment] ?? 0),
        const SizedBox(width: 8),
        tile('Confirmed', counts[AdminBookingFilter.confirmed] ?? 0),
      ],
    );
  }
}

class _AdminBookingCard extends StatelessWidget {
  const _AdminBookingCard({
    required this.row,
    required this.busy,
    this.onCancel,
    this.onApprove,
    this.onDecline,
  });

  final OversightRow row;
  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = row.amount;
    final created = row.createdAt;
    final customer = [
      row.customerName,
      row.customerContact,
    ].where((s) => s.isNotEmpty).join(' · ');
    final owner = [
      row.ownerName,
      row.ownerContact,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (amount != null)
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                row.subtitle,
                row.status,
                if (created != null) DateFormat.yMMMd().format(created),
              ].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (customer.isNotEmpty)
              Text(
                customer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            if (owner.isNotEmpty)
              Text(
                'Owner: $owner',
                key: Key('admin-booking-owner-${row.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            if (onApprove != null || onDecline != null) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onDecline != null)
                    OutlinedButton.icon(
                      key: AdminBookingsManagementView.declineKey(row.id),
                      onPressed: busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                    ),
                  if (onApprove != null)
                    FilledButton.icon(
                      key: AdminBookingsManagementView.approveKey(row.id),
                      onPressed: busy ? null : onApprove,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                ],
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: AdminBookingsManagementView.cancelKey(row.id),
                  onPressed: busy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Cancel as admin'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminCancelRequest {
  const _AdminCancelRequest(this.reason, this.refundAmount);

  final String reason;
  final double? refundAmount;
}

class _AdminCancelDialog extends StatefulWidget {
  const _AdminCancelDialog({required this.row});

  final OversightRow row;

  @override
  State<_AdminCancelDialog> createState() => _AdminCancelDialogState();
}

class _AdminCancelDialogState extends State<_AdminCancelDialog> {
  static const _presets = [
    'Declined by Platform Admin',
    'Policy violation',
    'Duplicate booking',
    'Venue unavailable',
  ];
  final _reason = TextEditingController(text: _presets.first);
  final _refund = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _refund.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please enter a reason');
      return;
    }
    final rawRefund = _refund.text.trim();
    double? refund;
    if (rawRefund.isNotEmpty) {
      refund = double.tryParse(rawRefund);
      final max = widget.row.amount;
      if (refund == null || refund < 0 || (max != null && refund > max)) {
        setState(
          () => _error = 'Enter a refund between 0 and the booking total',
        );
        return;
      }
    }
    Navigator.of(context).pop(_AdminCancelRequest(reason, refund));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel booking'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.row.title} · ${widget.row.subtitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(p),
                    selected: _reason.text.trim() == p,
                    onSelected: (_) => setState(() {
                      _reason.text = p;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-cancel-reason'),
              controller: _reason,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-cancel-refund'),
              controller: _refund,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Refund amount (optional)',
                helperText: 'Leave blank to cancel without a refund',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep booking'),
        ),
        FilledButton(
          key: const Key('admin-cancel-confirm'),
          onPressed: _submit,
          child: const Text('Cancel booking'),
        ),
      ],
    );
  }
}

/// Confirms an admin decline of a booking request and collects the
/// reason (required), following the cancel dialog's preset-chips pattern.
/// Pops the trimmed reason, or null when the admin keeps the request.
class _AdminDeclineDialog extends StatefulWidget {
  const _AdminDeclineDialog({required this.row});

  final OversightRow row;

  @override
  State<_AdminDeclineDialog> createState() => _AdminDeclineDialogState();
}

class _AdminDeclineDialogState extends State<_AdminDeclineDialog> {
  static const _presets = [
    'Declined by Platform Admin',
    'Venue unavailable on this date',
    'Duplicate request',
    'Policy violation',
  ];
  final _reason = TextEditingController(text: _presets.first);
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please enter a reason');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.row.title} · ${widget.row.subtitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Text(
              'The customer is notified, the slot is released and no payment '
              'is taken.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(p),
                    selected: _reason.text.trim() == p,
                    onSelected: (_) => setState(() {
                      _reason.text = p;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-decline-reason'),
              controller: _reason,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep request'),
        ),
        FilledButton(
          key: const Key('admin-decline-confirm'),
          onPressed: _submit,
          child: const Text('Decline request'),
        ),
      ],
    );
  }
}
