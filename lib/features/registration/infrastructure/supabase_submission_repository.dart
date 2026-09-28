import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/module_submission.dart';
import '../domain/submission_review.dart';

class SupabaseSubmissionRepository implements SubmissionReviewRepository {
  SupabaseSubmissionRepository(this.client);
  final SupabaseClient client;

  Future<ModuleSubmission> byId(String id) async {
    final row = await client
        .from('module_form_submissions')
        .select()
        .eq('id', id)
        .single();
    return ModuleSubmission.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadDocument({
    required String submissionId,
    required String requirementId,
    required String userId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final path = '$userId/$submissionId/$requirementId-$filename';
    await client.storage
        .from('module-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    await client.rpc<dynamic>(
      'register_module_submission_document',
      params: {
        'p_submission_id': submissionId,
        'p_requirement_id': requirementId,
        'p_storage_path': path,
        'p_mime_type': mimeType,
        'p_size_bytes': bytes.length,
      },
    );
    return path;
  }

  @override
  Future<String> signedDocumentUrl(
    String path, {
    Duration expiresIn = const Duration(minutes: 10),
  }) => client.storage
      .from('module-documents')
      .createSignedUrl(path, expiresIn.inSeconds);

  Future<void> retryUpload({
    required String submissionId,
    required String requirementId,
    required String userId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) => uploadDocument(
    submissionId: submissionId,
    requirementId: requirementId,
    userId: userId,
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );

  Future<ModuleSubmission> review(
    String id,
    String status, {
    String? reason,
  }) async {
    // review_module_submission returns a single composite row (not a set),
    // which PostgREST serialises as an object; accept a list too.
    final result = await client.rpc<dynamic>(
      'review_module_submission',
      params: {
        'p_submission_id': id,
        'p_next_status': status,
        'p_reason': reason,
      },
    );
    final row = result is List
        ? result.whereType<Map<String, dynamic>>().first
        : Map<String, dynamic>.from(result as Map);
    return ModuleSubmission.fromJson(row);
  }

  @override
  Future<List<ReviewableSubmission>> pendingReviews() async {
    try {
      final rows = await client
          .from('module_form_submissions')
          .select(
            'id, module_key, venue_id, customer_user_id, booking_id, status, '
            'values, rejection_reason, submitted_at, created_at, '
            'venues(name), module_form_versions(fields)',
          )
          .inFilter('status', kPendingReviewStatuses)
          .order('created_at', ascending: true)
          .limit(200);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        final venue = row['venues'];
        final form = row['module_form_versions'];
        final fields = form is Map ? form['fields'] : null;
        return ReviewableSubmission(
          submission: ModuleSubmission.fromJson(row),
          venueName: venue is Map ? venue['name']?.toString() ?? '' : '',
          fieldLabels: {
            if (fields is List)
              for (final f in fields.whereType<Map>())
                if ((f['key'] ?? '').toString().isNotEmpty)
                  f['key'].toString(): (f['label'] ?? '').toString(),
          },
        );
      }).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<SubmissionDocument>> documents(String submissionId) async {
    try {
      final rows = await client
          .from('module_submission_documents')
          .select(
            'id, storage_path, mime_type, size_bytes, status, created_at, '
            'module_document_requirements(label, document_key)',
          )
          .eq('submission_id', submissionId)
          .neq('status', 'deleted')
          .order('created_at');
      return rows
          .whereType<Map<String, dynamic>>()
          .map(SubmissionDocument.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<ModuleSubmission> approve(ReviewableSubmission submission) =>
      _moveTo(submission, 'approved');

  @override
  Future<ModuleSubmission> reject(
    ReviewableSubmission submission,
    String reason,
  ) => _moveTo(submission, 'rejected', reason: reason.trim());

  Future<ModuleSubmission> _moveTo(
    ReviewableSubmission submission,
    String target, {
    String? reason,
  }) async {
    try {
      var latest = submission.submission;
      for (final step in reviewTransitionPath(submission.status, target)) {
        latest = await review(
          submission.id,
          step,
          reason: step == 'rejected' ? reason : null,
        );
      }
      return latest;
    } on StateError catch (e) {
      throw app_errors.BusinessException(e.message);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
