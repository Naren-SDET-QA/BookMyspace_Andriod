import 'listing_moderation.dart';

/// Status tabs on the admin bookings management screen.
enum AdminBookingFilter {
  all('All'),
  pendingApproval('Pending approval'),
  pendingPayment('Pending payment'),
  confirmed('Confirmed'),
  cancelled('Cancelled');

  const AdminBookingFilter(this.label);

  final String label;

  /// Whether a raw `bookings.status` value belongs to this tab.
  bool matches(String status) => switch (this) {
    AdminBookingFilter.all => true,
    _ => bucketOf(status) == this,
  };

  /// The tab a raw `bookings.status` value is counted under, or null for
  /// statuses that only appear under [all] (e.g. completed, no_show).
  static AdminBookingFilter? bucketOf(String status) {
    switch (status.trim().toLowerCase()) {
      case 'awaiting_owner_approval':
      case 'pending_owner_approval':
        return AdminBookingFilter.pendingApproval;
      case 'pending':
      case 'held':
        return AdminBookingFilter.pendingPayment;
      case 'confirmed':
        return AdminBookingFilter.confirmed;
      case 'cancelled':
      case 'rejected':
      case 'owner_rejected':
      case 'approval_expired':
      case 'expired':
        return AdminBookingFilter.cancelled;
      default:
        return null;
    }
  }
}

/// Row counts per [AdminBookingFilter] tab.
Map<AdminBookingFilter, int> adminBookingCounts(List<OversightRow> rows) {
  final counts = {for (final f in AdminBookingFilter.values) f: 0};
  counts[AdminBookingFilter.all] = rows.length;
  for (final row in rows) {
    final bucket = AdminBookingFilter.bucketOf(row.status);
    if (bucket != null) counts[bucket] = counts[bucket]! + 1;
  }
  return counts;
}

/// Applies the status [filter] and a case-insensitive free-text [query]
/// matched against the booking reference/id, venue name and customer.
List<OversightRow> filterAdminBookings(
  List<OversightRow> rows, {
  AdminBookingFilter filter = AdminBookingFilter.all,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return rows.where((row) {
    if (!filter.matches(row.status)) return false;
    if (q.isEmpty) return true;
    return [
      row.reference,
      row.id,
      row.subtitle,
      row.title,
      row.customerName,
      row.customerContact,
    ].any((field) => field.toLowerCase().contains(q));
  }).toList();
}
