import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../owner_bookings/presentation/widgets/reject_reason_dialog.dart';
import '../../../registration/domain/submission_review.dart';
import '../../../registration/presentation/registration_providers.dart';

/// Rejection presets for registration / KYC submissions.
const kRegistrationRejectionPresets = [
  'Document is unclear or unreadable',
  'Document does not match the submitted details',
  'Required document missing',
  'Details incomplete or invalid',
];

/// Admin queue of module registration / KYC submissions awaiting review.
class AdminRegistrationReviewsScreen extends ConsumerWidget {
  const AdminRegistrationReviewsScreen({super.key});

  static Key tileKey(String id) => Key('registration-review-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingSubmissionReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Registration reviews')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(pendingSubmissionReviewsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No pending reviews',
              message: 'New registration and KYC submissions appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingSubmissionReviewsProvider);
              await ref.read(pendingSubmissionReviewsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final submitted =
                    item.submission.submittedAt ?? item.submission.createdAt;
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: tileKey(item.id),
                    leading: const Icon(Icons.assignment_ind_outlined),
                    title: Text(
                      _moduleLabel(item.submission.moduleKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (item.venueName.isNotEmpty) item.venueName,
                        _statusLabel(item.status),
                        if (submitted != null)
                          DateFormat.yMMMd().format(submitted),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => SubmissionReviewSheet(item: item),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _moduleLabel(String key) {
  if (key.isEmpty) return 'Registration';
  final words = key.replaceAll(RegExp(r'[_\-]+'), ' ').trim().split(' ');
  return words
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String _statusLabel(String status) => switch (status) {
  'submitted' => 'Submitted',
  'under_review' => 'Under review',
  _ => status,
};

/// Detail of a submission with its fields, documents and review actions.
class SubmissionReviewSheet extends ConsumerStatefulWidget {
  const SubmissionReviewSheet({super.key, required this.item});

  final ReviewableSubmission item;

  static const approveKey = Key('registration-review-approve');
  static const rejectKey = Key('registration-review-reject');

  @override
  ConsumerState<SubmissionReviewSheet> createState() =>
      _SubmissionReviewSheetState();
}

class _SubmissionReviewSheetState extends ConsumerState<SubmissionReviewSheet> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await showRejectReasonDialog(
        context,
        title: 'Reject submission',
        message: 'The applicant sees this reason and can resubmit.',
        presets: kRegistrationRejectionPresets,
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final repo = ref.read(submissionReviewRepositoryProvider);
      if (approve) {
        await repo.approve(widget.item);
      } else {
        await repo.reject(widget.item, reason!);
      }
      ref.invalidate(pendingSubmissionReviewsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Submission approved' : 'Submission rejected',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _open(SubmissionDocument doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref
          .read(submissionReviewRepositoryProvider)
          .signedDocumentUrl(doc.storagePath);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('Could not open document');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final docs = ref.watch(submissionDocumentsProvider(item.id));
    final fields = item.displayFields;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  _moduleLabel(item.submission.moduleKey),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (item.venueName.isNotEmpty) item.venueName,
                    _statusLabel(item.status),
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Submitted details', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (fields.isEmpty)
                  const Text('No form values were submitted.')
                else
                  for (final (label, value) in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(flex: 3, child: Text(value)),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                Text('Documents', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                docs.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Could not load documents: $e',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  data: (list) => list.isEmpty
                      ? const Text('No documents uploaded.')
                      : Column(
                          children: [
                            for (final doc in list)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  doc.mimeType.contains('pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                ),
                                title: Text(
                                  doc.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${doc.status} · '
                                  '${(doc.sizeBytes / 1024).toStringAsFixed(0)} KB',
                                ),
                                trailing: const Icon(Icons.open_in_new),
                                onTap: () => _open(doc),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: SubmissionReviewSheet.rejectKey,
                      onPressed: _busy ? null : () => _decide(approve: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: SubmissionReviewSheet.approveKey,
                      onPressed: _busy ? null : () => _decide(approve: true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
