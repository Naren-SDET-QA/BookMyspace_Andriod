class Notification {
  const Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.read = false,
    this.data,
    this.readAt,
    required this.createdAt,
  });

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
}
