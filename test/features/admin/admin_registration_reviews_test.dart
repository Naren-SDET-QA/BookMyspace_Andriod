import 'package:bookmyspace/features/admin/presentation/screens/admin_registration_reviews_screen.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/widgets/reject_reason_dialog.dart';
import 'package:bookmyspace/features/registration/domain/module_submission.dart';
import 'package:bookmyspace/features/registration/domain/submission_review.dart';
import 'package:bookmyspace/features/registration/presentation/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReviewRepo implements SubmissionReviewRepository {
  _FakeReviewRepo(this.items);

  final List<ReviewableSubmission> items;
  final approved = <String>[];
  final rejected = <String, String>{};

  @override
  Future<List<ReviewableSubmission>> pendingReviews() async => items
      .where((i) => !approved.contains(i.id) && !rejected.containsKey(i.id))
      .toList();

  @override
  Future<List<SubmissionDocument>> documents(String submissionId) async => [
    const SubmissionDocument(
      id: 'd1',
      label: 'Aadhaar card',
      storagePath: 'u1/s1/aadhaar.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 20480,
      status: 'uploaded',
    ),
  ];

  @override
  Future<String> signedDocumentUrl(String path) async => 'https://x/$path';

  @override
  Future<ModuleSubmission> approve(ReviewableSubmission submission) async {
    approved.add(submission.id);
    return submission.submission;
  }

  @override
  Future<ModuleSubmission> reject(
    ReviewableSubmission submission,
    String reason,
  ) async {
    rejected[submission.id] = reason;
    return submission.submission;
  }
}

ReviewableSubmission _item(String id, {String status = 'submitted'}) =>
    ReviewableSubmission(
      submission: ModuleSubmission(
        id: id,
        moduleKey: 'pg_hostel',
        status: status,
        values: const {
          'full_name': 'Ravi Kumar',
          'id_number': 'XXXX-1234',
          'agree': true,
        },
      ),
      venueName: 'Green PG',
      fieldLabels: const {'full_name': 'Full name', 'id_number': 'ID number'},
    );

Widget _app(_FakeReviewRepo repo) => ProviderScope(
  overrides: [submissionReviewRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: AdminRegistrationReviewsScreen()),
);

void main() {
  group('reviewTransitionPath', () {
    test('goes through under_review from submitted', () {
      expect(reviewTransitionPath('submitted', 'approved'), [
        'under_review',
        'approved',
      ]);
      expect(reviewTransitionPath('under_review', 'rejected'), ['rejected']);
      expect(reviewTransitionPath('approved', 'approved'), isEmpty);
    });

    test('rejects impossible transitions', () {
      expect(
        () => reviewTransitionPath('confirmed', 'approved'),
        throwsStateError,
      );
      expect(
        () => reviewTransitionPath('submitted', 'confirmed'),
        throwsArgumentError,
      );
    });
  });

  test('displayFields uses labels in form order then extra keys', () {
    final fields = _item('s1').displayFields;
    expect(fields, [
      ('Full name', 'Ravi Kumar'),
      ('ID number', 'XXXX-1234'),
      ('agree', 'Yes'),
    ]);
  });

  testWidgets('lists pending submissions and approves one', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeReviewRepo([_item('s1'), _item('s2')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Pg Hostel'), findsNWidgets(2));
    await tester.tap(find.byKey(AdminRegistrationReviewsScreen.tileKey('s1')));
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Aadhaar card'), findsOneWidget);

    await tester.tap(find.byKey(SubmissionReviewSheet.approveKey));
    await tester.pumpAndSettle();

    expect(repo.approved, ['s1']);
    expect(find.text('Submission approved'), findsOneWidget);
    expect(
      find.byKey(AdminRegistrationReviewsScreen.tileKey('s1')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejecting requires a reason', (tester) async {
    final repo = _FakeReviewRepo([_item('s1', status: 'under_review')]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AdminRegistrationReviewsScreen.tileKey('s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SubmissionReviewSheet.rejectKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a reason'), findsOneWidget);

    await tester.tap(find.byKey(RejectReasonDialog.presetKey(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(repo.rejected, {'s1': kRegistrationRejectionPresets[2]});
    expect(find.text('Submission rejected'), findsOneWidget);
  });

  testWidgets('shows empty state when nothing is pending', (tester) async {
    await tester.pumpWidget(_app(_FakeReviewRepo(const [])));
    await tester.pumpAndSettle();
    expect(find.text('No pending reviews'), findsOneWidget);
  });
}
