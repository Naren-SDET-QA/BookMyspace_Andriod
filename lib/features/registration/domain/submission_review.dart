import 'module_submission.dart';

/// A module registration / KYC submission as shown in the admin review queue.
class ReviewableSubmission {
  const ReviewableSubmission({
    required this.submission,
    this.venueName = '',
    this.fieldLabels = const {},
  });

  final ModuleSubmission submission;
  final String venueName;

  /// Field key -> human label, from the submission's form version.
  final Map<String, String> fieldLabels;

  String get id => submission.id;
  String get status => submission.status;

  /// Submitted values as (label, display value) pairs, in form order when
  /// labels are known, then any remaining keys.
  List<(String, String)> get displayFields {
    final values = submission.values;
    final ordered = [
      ...fieldLabels.keys.where(values.containsKey),
      ...values.keys.where((k) => !fieldLabels.containsKey(k)),
    ];
    return [
      for (final key in ordered)
        (
          (fieldLabels[key]?.isNotEmpty ?? false) ? fieldLabels[key]! : key,
          displayValue(values[key]),
        ),
    ];
  }

  static String displayValue(Object? value) => switch (value) {
    null => '—',
    final bool b => b ? 'Yes' : 'No',
    final List l => l.map(displayValue).join(', '),
    final Map m =>
      m.entries.map((e) => '${e.key}: ${displayValue(e.value)}').join(', '),
    _ => value.toString().trim().isEmpty ? '—' : value.toString(),
  };
}

/// A document uploaded with a submission.
class SubmissionDocument {
  const SubmissionDocument({
    required this.id,
    required this.label,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
  });

  final String id;
  final String label;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final String status;

  factory SubmissionDocument.fromJson(Map<String, dynamic> json) {
    final requirement = json['module_document_requirements'];
    final req = requirement is Map ? requirement : const {};
    final path = json['storage_path'] as String? ?? '';
    return SubmissionDocument(
      id: json['id'] as String? ?? '',
      label:
          (req['label'] as String?) ??
          (req['document_key'] as String?) ??
          path.split('/').last,
      storagePath: path,
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'uploaded',
    );
  }
}

/// Statuses that belong in the admin review queue.
const kPendingReviewStatuses = ['submitted', 'under_review'];

/// Status hops `review_module_submission` needs to reach [target]
/// (`approved` or `rejected`) from [current], following
/// `validate_module_submission_transition`: submitted -> under_review ->
/// approved|rejected. Throws [StateError] when [current] cannot reach it.
List<String> reviewTransitionPath(String current, String target) {
  if (target != 'approved' && target != 'rejected') {
    throw ArgumentError.value(target, 'target');
  }
  return switch (current) {
    'submitted' => ['under_review', target],
    'under_review' => [target],
    _ when current == target => const [],
    _ => throw StateError('A $current submission cannot be $target.'),
  };
}

/// Admin review of module registration / KYC submissions.
abstract interface class SubmissionReviewRepository {
  /// Submissions awaiting review (submitted / under_review), oldest first.
  Future<List<ReviewableSubmission>> pendingReviews();

  /// Documents uploaded with [submissionId].
  Future<List<SubmissionDocument>> documents(String submissionId);

  /// Short-lived URL to open a document.
  Future<String> signedDocumentUrl(String path);

  Future<ModuleSubmission> approve(ReviewableSubmission submission);

  Future<ModuleSubmission> reject(
    ReviewableSubmission submission,
    String reason,
  );
}
