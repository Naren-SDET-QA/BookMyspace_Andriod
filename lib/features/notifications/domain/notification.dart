enum NotificationType {
  bookingConfirmed,
  bookingCancelled,
  paymentReceived,
  refundProcessed,
  slotReminder,
  system,
  supportReply,
  admin;

  static NotificationType fromDb(String value) => switch (value) {
    'booking_confirmed' => NotificationType.bookingConfirmed,
    'booking_cancelled' => NotificationType.bookingCancelled,
    'payment_received' => NotificationType.paymentReceived,
    'refund_processed' => NotificationType.refundProcessed,
    'slot_reminder' => NotificationType.slotReminder,
    'system' => NotificationType.system,
    'support_reply' => NotificationType.supportReply,
    'admin' => NotificationType.admin,
    _ => NotificationType.system,
  };

  String get dbValue => switch (this) {
    NotificationType.bookingConfirmed => 'booking_confirmed',
    NotificationType.bookingCancelled => 'booking_cancelled',
    NotificationType.paymentReceived => 'payment_received',
    NotificationType.refundProcessed => 'refund_processed',
    NotificationType.slotReminder => 'slot_reminder',
    NotificationType.system => 'system',
    NotificationType.supportReply => 'support_reply',
    NotificationType.admin => 'admin',
  };
}

class Notification {
  /// [type] accepts the stored string value or a [NotificationType]
  /// (release/v1.0 API). [createdAt] defaults to "now" when omitted.
  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    Object type = 'general',
    this.read = false,
    this.data,
    this.readAt,
    DateTime? createdAt,
  })  : type = type is NotificationType ? type.dbValue : '$type',
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      read: json['read'] as bool? ?? json['is_read'] as bool? ?? false,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      if (data != null) 'data': data,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? read,
    Map<String, dynamic>? data,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      read: read ?? this.read,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Typed view of [type] (release/v1.0 API).
  NotificationType get kind => NotificationType.fromDb(type);
}
