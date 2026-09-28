class ModuleSubmission {
  const ModuleSubmission({
    required this.id,
    required this.moduleKey,
    required this.status,
    this.venueId,
    this.bookingId,
    this.rejectionReason,
    this.createdAt,
    this.customerUserId,
    this.submittedAt,
    this.values = const {},
  });
  final String id;
  final String moduleKey;
  final String status;
  final String? venueId;
  final String? bookingId;
  final String? rejectionReason;
  final DateTime? createdAt;
  final String? customerUserId;
  final DateTime? submittedAt;

  /// Raw submitted form values keyed by field key.
  final Map<String, dynamic> values;

  factory ModuleSubmission.fromJson(Map<String, dynamic> json) =>
      ModuleSubmission(
        id: json['id'] as String? ?? '',
        moduleKey: json['module_key'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        venueId: json['venue_id'] as String?,
        bookingId: json['booking_id'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        customerUserId: json['customer_user_id'] as String?,
        submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
        values: json['values'] is Map
            ? Map<String, dynamic>.from(json['values'] as Map)
            : const {},
      );
}
