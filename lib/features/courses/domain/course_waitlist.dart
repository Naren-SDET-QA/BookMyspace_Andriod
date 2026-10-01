/// A learner's place in a full batch's waitlist.
///
/// [status] is `waiting` or `offered`. When a seat frees up the first
/// waiting learner is moved to `offered` and notified; the seat is reserved
/// for them until they enroll or leave the waitlist.
class CourseWaitlistEntry {
  const CourseWaitlistEntry({
    required this.batchId,
    required this.status,
    required this.position,
  });

  final String batchId;
  final String status;

  /// 1-based queue position; 0 when a seat has been offered.
  final int position;

  bool get isOffered => status == 'offered';

  factory CourseWaitlistEntry.fromJson(Map<String, dynamic> json) =>
      CourseWaitlistEntry(
        batchId: json['batch_id'] as String? ?? '',
        status: json['status'] as String? ?? 'waiting',
        position: (json['queue_position'] as num?)?.toInt() ?? 0,
      );
}

/// Server-authoritative waitlist for full course batches.
abstract interface class CourseWaitlistRepository {
  /// Joins the waitlist for [batchId]; returns the queue position
  /// (0 if a seat is already offered to this learner).
  Future<int> join(String batchId);

  /// Leaves the waitlist for [batchId]. Releases an offered seat.
  Future<void> leave(String batchId);

  /// The signed-in learner's active waitlist entries.
  Future<List<CourseWaitlistEntry>> mine();
}
