/// Permission status for system-level push notifications.
enum PushPermissionStatus {
  granted,
  denied,
  notDetermined,
  provisional;

  bool get isGranted => this == PushPermissionStatus.granted;
}

/// Information about a registered push device token or Web Push subscription.
class PushTokenInfo {
  const PushTokenInfo({
    required this.token,
    required this.platform,
    this.subscriptionData,
    required this.updatedAt,
  });

  final String token;
  final String platform; // 'ios' | 'web' | 'android'
  final Map<String, dynamic>?
      subscriptionData; // e.g. keys: {auth, p256dh} for Web Push
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'token': token,
        'platform': platform,
        if (subscriptionData != null) 'subscription_data': subscriptionData,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PushTokenInfo.fromJson(Map<String, dynamic> json) => PushTokenInfo(
        token: json['token'] as String? ?? '',
        platform: json['platform'] as String? ?? 'web',
        subscriptionData: json['subscription_data'] != null
            ? Map<String, dynamic>.from(json['subscription_data'] as Map)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Payload received from incoming push notification or simulated payload.
class PushNotificationPayload {
  const PushNotificationPayload({
    required this.title,
    required this.body,
    this.type =
        'general', // '1_hour_reminder' | 'booking' | 'course_alert' | 'general'
    this.bookingId,
    this.venueName,
    this.slotTime,
    this.bookingDate,
    this.qrCodeToken,
    this.venueId,
    this.courseId,
    this.classId,
    this.action,
    this.data,
  });

  final String title;
  final String body;
  final String type;
  final String? bookingId;
  final String? venueName;
  final String? slotTime;
  final String? bookingDate;
  final String? qrCodeToken;
  final String? venueId;
  final String? courseId;
  final String? classId;
  final String? action;
  final Map<String, dynamic>? data;

  factory PushNotificationPayload.fromMap(Map<String, dynamic> map) {
    final dataMap = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    return PushNotificationPayload(
      title: map['title'] as String? ??
          dataMap['title'] as String? ??
          'BookMySpace Alert',
      body: map['body'] as String? ?? dataMap['body'] as String? ?? '',
      type: dataMap['type'] as String? ??
          dataMap['reminder_type'] as String? ??
          'general',
      bookingId:
          dataMap['booking_id'] as String? ?? dataMap['bookingId'] as String?,
      venueName:
          dataMap['venue_name'] as String? ?? dataMap['venueName'] as String?,
      slotTime:
          dataMap['slot_time'] as String? ?? dataMap['slotTime'] as String?,
      bookingDate: dataMap['booking_date'] as String? ??
          dataMap['bookingDate'] as String?,
      qrCodeToken:
          dataMap['qr_token'] as String? ?? dataMap['qrCodeToken'] as String?,
      venueId: dataMap['venue_id'] as String? ?? dataMap['venueId'] as String?,
      courseId:
          dataMap['course_id'] as String? ?? dataMap['courseId'] as String?,
      classId: dataMap['class_id'] as String? ?? dataMap['classId'] as String?,
      action: map['action'] as String? ?? dataMap['action'] as String?,
      data: dataMap,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        if (bookingId != null) 'booking_id': bookingId,
        if (venueName != null) 'venue_name': venueName,
        if (slotTime != null) 'slot_time': slotTime,
        if (bookingDate != null) 'booking_date': bookingDate,
        if (qrCodeToken != null) 'qr_token': qrCodeToken,
        if (venueId != null) 'venue_id': venueId,
        if (courseId != null) 'course_id': courseId,
        if (classId != null) 'class_id': classId,
        if (action != null) 'action': action,
        if (data != null) 'data': data,
      };
}

/// Represents an active scheduled 1-hour pre-booking reminder.
class ScheduledReminderInfo {
  const ScheduledReminderInfo({
    required this.bookingId,
    required this.venueName,
    required this.slotLabel,
    required this.bookingDate,
    required this.scheduledTriggerEpochMs,
    this.reminderType = '1_HOUR_PRE_SLOT',
    this.isActive = true,
  });

  final String bookingId;
  final String venueName;
  final String slotLabel;
  final String bookingDate;
  final int scheduledTriggerEpochMs;
  final String reminderType;
  final bool isActive;

  String getTimeRemainingFormatted() {
    final diffMs =
        scheduledTriggerEpochMs - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 'Triggering soon / Active';
    final hours = diffMs ~/ (1000 * 60 * 60);
    final minutes = (diffMs % (1000 * 60 * 60)) ~/ (1000 * 60);
    if (hours > 24) {
      return '${hours ~/ 24}d ${hours % 24}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
