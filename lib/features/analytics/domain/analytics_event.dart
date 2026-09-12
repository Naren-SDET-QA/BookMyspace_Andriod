enum AnalyticsEventType {
  screenView,
  buttonTap,
  bookingCreated,
  bookingConfirmed,
  paymentCaptured,
  refundRequested,
  refundProcessed,
  eventRegistered,
  courseEnrolled,
  supportTicketCreated,
  supportTicketResolved,
  ownerRegistered,
  venueCreated,
  venueUpdated,
  notificationSent,
  crashReported,
  custom;

  static AnalyticsEventType fromDb(String value) => switch (value) {
        'screen_view' => AnalyticsEventType.screenView,
        'button_tap' => AnalyticsEventType.buttonTap,
        'booking_created' => AnalyticsEventType.bookingCreated,
        'booking_confirmed' => AnalyticsEventType.bookingConfirmed,
        'payment_captured' => AnalyticsEventType.paymentCaptured,
        'refund_requested' => AnalyticsEventType.refundRequested,
        'refund_processed' => AnalyticsEventType.refundProcessed,
        'event_registered' => AnalyticsEventType.eventRegistered,
        'course_enrolled' => AnalyticsEventType.courseEnrolled,
        'support_ticket_created' => AnalyticsEventType.supportTicketCreated,
        'support_ticket_resolved' => AnalyticsEventType.supportTicketResolved,
        'owner_registered' => AnalyticsEventType.ownerRegistered,
        'venue_created' => AnalyticsEventType.venueCreated,
        'venue_updated' => AnalyticsEventType.venueUpdated,
        'notification_sent' => AnalyticsEventType.notificationSent,
        'crash_reported' => AnalyticsEventType.crashReported,
        _ => AnalyticsEventType.custom,
      };

  String get dbValue => switch (this) {
        AnalyticsEventType.screenView => 'screen_view',
        AnalyticsEventType.buttonTap => 'button_tap',
        AnalyticsEventType.bookingCreated => 'booking_created',
        AnalyticsEventType.bookingConfirmed => 'booking_confirmed',
        AnalyticsEventType.paymentCaptured => 'payment_captured',
        AnalyticsEventType.refundRequested => 'refund_requested',
        AnalyticsEventType.refundProcessed => 'refund_processed',
        AnalyticsEventType.eventRegistered => 'event_registered',
        AnalyticsEventType.courseEnrolled => 'course_enrolled',
        AnalyticsEventType.supportTicketCreated => 'support_ticket_created',
        AnalyticsEventType.supportTicketResolved => 'support_ticket_resolved',
        AnalyticsEventType.ownerRegistered => 'owner_registered',
        AnalyticsEventType.venueCreated => 'venue_created',
        AnalyticsEventType.venueUpdated => 'venue_updated',
        AnalyticsEventType.notificationSent => 'notification_sent',
        AnalyticsEventType.crashReported => 'crash_reported',
        AnalyticsEventType.custom => 'custom',
      };
}

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    this.properties = const {},
    this.createdAt,
  });

  final String id;
  final String? userId;
  final AnalyticsEventType eventType;
  final Map<String, dynamic> properties;
  final DateTime? createdAt;

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => AnalyticsEvent(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String?,
        eventType:
            AnalyticsEventType.fromDb(json['event_type'] as String? ?? ''),
        properties: json['properties'] is Map
            ? Map<String, dynamic>.from(json['properties'] as Map)
            : const {},
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String? ?? '')
            : null,
      );
}
