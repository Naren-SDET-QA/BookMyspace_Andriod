enum TicketPriority {
  low,
  medium,
  high,
  urgent;

  static TicketPriority fromDb(String value) =>
      TicketPriority.values.firstWhere(
        (priority) => priority.name == value,
        orElse: () => TicketPriority.medium,
      );

  String get dbValue => name;
}

enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed;

  static TicketStatus fromDb(String value) => switch (value) {
        'in_progress' => TicketStatus.inProgress,
        'resolved' => TicketStatus.resolved,
        'closed' => TicketStatus.closed,
        _ => TicketStatus.open,
      };

  String get dbValue => switch (this) {
        TicketStatus.inProgress => 'in_progress',
        _ => name,
      };
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.userId,
    this.adminReply,
    this.createdAt,
  });

  final String id;
  final String subject;
  final String description;
  final String category;
  final TicketPriority priority;
  final TicketStatus status;
  final String? userId;
  final String? adminReply;
  final DateTime? createdAt;

  bool get isResolved =>
      status == TicketStatus.resolved || status == TicketStatus.closed;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'general',
        priority:
            TicketPriority.fromDb(json['priority'] as String? ?? 'medium'),
        status: TicketStatus.fromDb(json['status'] as String? ?? 'open'),
        userId: json['user_id'] as String?,
        adminReply: json['admin_reply'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}
