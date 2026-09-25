import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RLS integration test for the additive `institutes_admin_write`,
/// `courses_admin_write`, `course_batches_admin_write`,
/// `course_batches_owner_insert/update/delete` policies added in
/// `institutes_courses_batches_write_rls`.
///
/// This talks to Supabase directly through the real Flutter client SDK using
/// real `signInWithPassword` sessions for five dedicated test accounts — it
/// does not impersonate Postgres roles, grant database roles, or touch
/// `pg_policies`/`pg_roles` in any way. Every write attempted here goes
/// through the same PostgREST path the app itself uses.
///
/// Run with (all values required, none hardcoded):
///   flutter test integration_test/e2e/rls_institute_course_batch_test.dart \
///     --dart-define-from-file=.env.dev \
///     --dart-define=RLS_ADMIN_EMAIL=... --dart-define=RLS_ADMIN_PASSWORD=... \
///     --dart-define=RLS_OWNER_A_EMAIL=... --dart-define=RLS_OWNER_A_PASSWORD=... \
///     --dart-define=RLS_OWNER_B_EMAIL=... --dart-define=RLS_OWNER_B_PASSWORD=... \
///     --dart-define=RLS_NORMAL_EMAIL=... --dart-define=RLS_NORMAL_PASSWORD=...
///
/// RLS_OWNER_A must own the organization that owns the institute used for
/// its fixtures (an existing venue_owner/institute_owner test account works
/// as long as it owns at least one row in `organizations`). RLS_OWNER_B must
/// own a *different* organization than RLS_OWNER_A. RLS_ADMIN must hold the
/// `administrator` role, and RLS_NORMAL must hold neither an admin role nor
/// own any organization.
///
/// Every fixture row created by a test is deleted in that test's `finally`
/// block using the admin session, since the newly-added admin-write
/// policies give it write access regardless of which identity created the
/// row (this test asserts that fact for itself in group 1, so relying on it
/// for cleanup is not circular — cleanup only runs after that assertion has
/// already passed once per test run).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  const adminEmail = String.fromEnvironment('RLS_ADMIN_EMAIL');
  const adminPassword = String.fromEnvironment('RLS_ADMIN_PASSWORD');
  const ownerAEmail = String.fromEnvironment('RLS_OWNER_A_EMAIL');
  const ownerAPassword = String.fromEnvironment('RLS_OWNER_A_PASSWORD');
  const ownerBEmail = String.fromEnvironment('RLS_OWNER_B_EMAIL');
  const ownerBPassword = String.fromEnvironment('RLS_OWNER_B_PASSWORD');
  const normalEmail = String.fromEnvironment('RLS_NORMAL_EMAIL');
  const normalPassword = String.fromEnvironment('RLS_NORMAL_PASSWORD');

  late SupabaseClient adminClient;
  late SupabaseClient ownerAClient;
  late SupabaseClient ownerBClient;
  late SupabaseClient normalClient;
  late SupabaseClient anonClient;

  // Org ids resolved at runtime for owner A / owner B so this test never
  // hardcodes a specific dev-database org — it asks each signed-in owner
  // which organization they actually own.
  String? orgAId;
  String? orgBId;

  Future<SupabaseClient> signedInClient(String email, String password) async {
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    final res =
        await client.auth.signInWithPassword(email: email, password: password);
    expect(res.session, isNotNull,
        reason: 'expected a real session for $email — check the test '
            'account exists and the password is correct');
    return client;
  }

  setUpAll(() async {
    expect(supabaseUrl, isNotEmpty,
        reason: 'SUPABASE_URL must be supplied via --dart-define-from-file');
    adminClient = await signedInClient(adminEmail, adminPassword);
    ownerAClient = await signedInClient(ownerAEmail, ownerAPassword);
    ownerBClient = await signedInClient(ownerBEmail, ownerBPassword);
    normalClient = await signedInClient(normalEmail, normalPassword);
    anonClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

    final orgA = await ownerAClient
        .from('organizations')
        .select('id')
        .eq('owner_user_id', ownerAClient.auth.currentUser!.id)
        .limit(1)
        .maybeSingle();
    final orgB = await ownerBClient
        .from('organizations')
        .select('id')
        .eq('owner_user_id', ownerBClient.auth.currentUser!.id)
        .limit(1)
        .maybeSingle();
    orgAId = orgA?['id'] as String?;
    orgBId = orgB?['id'] as String?;
    expect(orgAId, isNotNull,
        reason: 'RLS_OWNER_A must own at least one organizations row');
    expect(orgBId, isNotNull,
        reason: 'RLS_OWNER_B must own at least one organizations row');
    expect(orgAId, isNot(equals(orgBId)),
        reason: 'owner A and owner B must own two different organizations');
  });

  /// Deletes the row regardless of which policy allows it, using the admin
  /// session (broadest write access after this migration). Ignores errors
  /// so a partially-created fixture from a failed assertion doesn't mask
  /// the original failure.
  Future<void> adminCleanupBatch(String id) async {
    try {
      await adminClient.from('course_batches').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> adminCleanupCourse(String id) async {
    try {
      await adminClient.from('courses').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> adminCleanupInstitute(String id) async {
    try {
      await adminClient.from('institutes').delete().eq('id', id);
    } catch (_) {}
  }

  group('1. Admin: institutes/courses/batches CRUD', () {
    testWidgets('admin can create, update, delete an institute',
        (tester) async {
      final id = 'c1a00000-0000-4000-8000-000000000001';
      try {
        await adminClient.from('institutes').insert({
          'id': id,
          'org_id': orgAId,
          'name': 'RLS_TEST admin institute',
        });
        final created =
            await adminClient.from('institutes').select().eq('id', id).single();
        expect(created['name'], 'RLS_TEST admin institute');

        await adminClient.from('institutes').update(
            {'name': 'RLS_TEST admin institute (updated)'}).eq('id', id);
        final updated =
            await adminClient.from('institutes').select().eq('id', id).single();
        expect(updated['name'], 'RLS_TEST admin institute (updated)');

        await adminClient.from('institutes').delete().eq('id', id);
        final afterDelete = await adminClient
            .from('institutes')
            .select()
            .eq('id', id)
            .maybeSingle();
        expect(afterDelete, isNull);
      } finally {
        await adminCleanupInstitute(id);
      }
    });

    testWidgets('admin can create, update, delete a course', (tester) async {
      final instId = 'c1a00000-0000-4000-8000-000000000002';
      final courseId = 'c1a00000-0000-4000-8000-000000000003';
      try {
        await adminClient.from('institutes').insert({
          'id': instId,
          'org_id': orgAId,
          'name': 'RLS_TEST admin course host'
        });
        await adminClient.from('courses').insert({
          'id': courseId,
          'institute_id': instId,
          'title': 'RLS_TEST admin course',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });
        await adminClient
            .from('courses')
            .update({'status': 'published'}).eq('id', courseId);
        final published = await adminClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .single();
        expect(published['status'], 'published');

        await adminClient.from('courses').delete().eq('id', courseId);
        final afterDelete = await adminClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .maybeSingle();
        expect(afterDelete, isNull);
      } finally {
        await adminCleanupCourse(courseId);
        await adminCleanupInstitute(instId);
      }
    });

    testWidgets('admin can create, update, delete a batch', (tester) async {
      final instId = 'c1a00000-0000-4000-8000-000000000004';
      final courseId = 'c1a00000-0000-4000-8000-000000000005';
      final batchId = 'c1a00000-0000-4000-8000-000000000006';
      try {
        await adminClient.from('institutes').insert({
          'id': instId,
          'org_id': orgAId,
          'name': 'RLS_TEST admin batch host'
        });
        await adminClient.from('courses').insert({
          'id': courseId,
          'institute_id': instId,
          'title': 'RLS_TEST admin batch course',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });
        await adminClient.from('course_batches').insert({
          'id': batchId,
          'course_id': courseId,
          'label': 'RLS_TEST admin batch',
          'starts_on': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first,
          'capacity': 10,
        });
        await adminClient
            .from('course_batches')
            .update({'capacity': 20}).eq('id', batchId);
        final updated = await adminClient
            .from('course_batches')
            .select()
            .eq('id', batchId)
            .single();
        expect(updated['capacity'], 20);

        await adminClient.from('course_batches').delete().eq('id', batchId);
        final afterDelete = await adminClient
            .from('course_batches')
            .select()
            .eq('id', batchId)
            .maybeSingle();
        expect(afterDelete, isNull);
      } finally {
        await adminCleanupBatch(batchId);
        await adminCleanupCourse(courseId);
        await adminCleanupInstitute(instId);
      }
    });
  });

  group('2-3. Institute owner A: own records only', () {
    testWidgets(
        'owner A can modify own institute/course/batch; '
        'owner B cannot touch owner A\'s records', (tester) async {
      final instId = 'c2a00000-0000-4000-8000-000000000001';
      final courseId = 'c2a00000-0000-4000-8000-000000000002';
      final batchId = 'c2a00000-0000-4000-8000-000000000003';
      try {
        // Owner A creates their own institute/course/batch.
        await ownerAClient.from('institutes').insert({
          'id': instId,
          'org_id': orgAId,
          'name': 'RLS_TEST owner A institute'
        });
        await ownerAClient.from('courses').insert({
          'id': courseId,
          'institute_id': instId,
          'title': 'RLS_TEST owner A course',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });
        await ownerAClient.from('course_batches').insert({
          'id': batchId,
          'course_id': courseId,
          'label': 'RLS_TEST owner A batch',
          'starts_on': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first,
          'capacity': 10,
        });
        // 4. Owner A can update their own row.
        await ownerAClient.from('courses').update(
            {'title': 'RLS_TEST owner A course (updated)'}).eq('id', courseId);
        final ownUpdate = await ownerAClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .single();
        expect(ownUpdate['title'], 'RLS_TEST owner A course (updated)');

        // 5. Owner B cannot update/delete/insert-into owner A's records.
        // PostgREST returns 0 affected rows (not an exception) when RLS
        // silently excludes the target row from an UPDATE/DELETE, so the
        // assertion is "no row changed", not "an exception was thrown".
        final ownerBUpdateResult = await ownerBClient
            .from('courses')
            .update({'title': 'HIJACKED'})
            .eq('id', courseId)
            .select();
        expect(ownerBUpdateResult, isEmpty,
            reason: 'owner B must not be able to update owner A\'s course');

        final ownerBDeleteResult = await ownerBClient
            .from('course_batches')
            .delete()
            .eq('id', batchId)
            .select();
        expect(ownerBDeleteResult, isEmpty,
            reason: 'owner B must not be able to delete owner A\'s batch');

        var ownerBInsertDenied = false;
        try {
          await ownerBClient.from('course_batches').insert({
            'id': 'c2a00000-0000-4000-8000-00000000baad',
            'course_id': courseId, // owner A's course
            'label': 'RLS_TEST owner B illegal batch',
            'starts_on': DateTime.now()
                .add(const Duration(days: 7))
                .toIso8601String()
                .split('T')
                .first,
            'capacity': 5,
          });
        } on PostgrestException {
          ownerBInsertDenied = true;
        }
        expect(ownerBInsertDenied, isTrue,
            reason: 'owner B must not be able to insert a batch under '
                'owner A\'s course');
        await adminCleanupBatch('c2a00000-0000-4000-8000-00000000baad');

        // Confirm the row genuinely wasn't touched.
        final stillOwnerA = await adminClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .single();
        expect(stillOwnerA['title'], 'RLS_TEST owner A course (updated)');
      } finally {
        await adminCleanupBatch(batchId);
        await adminCleanupCourse(courseId);
        await adminCleanupInstitute(instId);
      }
    });
  });

  group('6-7. Normal user and anonymous cannot write', () {
    testWidgets('normal authenticated user cannot write; anon cannot write',
        (tester) async {
      final instId = 'c3a00000-0000-4000-8000-000000000001';
      final courseId = 'c3a00000-0000-4000-8000-000000000002';
      try {
        await adminClient.from('institutes').insert({
          'id': instId,
          'org_id': orgAId,
          'name': 'RLS_TEST normal/anon target institute'
        });
        await adminClient.from('courses').insert({
          'id': courseId,
          'institute_id': instId,
          'title': 'RLS_TEST normal/anon target course',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });

        final normalUpdateResult = await normalClient
            .from('courses')
            .update({'title': 'HIJACKED BY NORMAL USER'})
            .eq('id', courseId)
            .select();
        expect(normalUpdateResult, isEmpty,
            reason: 'a normal authenticated user must not be able to '
                'update any course');

        var normalInsertDenied = false;
        try {
          await normalClient.from('institutes').insert({
            'id': 'c3a00000-0000-4000-8000-00000000baad',
            'org_id': orgAId,
            'name': 'RLS_TEST illegal normal-user institute',
          });
        } on PostgrestException {
          normalInsertDenied = true;
        }
        expect(normalInsertDenied, isTrue,
            reason: 'a normal authenticated user must not be able to '
                'insert an institute');
        await adminCleanupInstitute('c3a00000-0000-4000-8000-00000000baad');

        var anonInsertDenied = false;
        try {
          await anonClient.from('courses').insert({
            'id': 'c3a00000-0000-4000-8000-0000000anon',
            'institute_id': instId,
            'title': 'RLS_TEST illegal anon course',
            'mode': 'online',
            'duration_weeks': 4,
            'fee_amount': 100,
            'status': 'draft',
          });
        } on PostgrestException {
          anonInsertDenied = true;
        }
        expect(anonInsertDenied, isTrue,
            reason: 'an anonymous user must not be able to insert a course');
        await adminCleanupCourse('c3a00000-0000-4000-8000-0000000anon');

        final anonUpdateResult = await anonClient
            .from('courses')
            .update({'title': 'HIJACKED BY ANON'})
            .eq('id', courseId)
            .select();
        expect(anonUpdateResult, isEmpty,
            reason: 'an anonymous user must not be able to update any course');
      } finally {
        await adminCleanupCourse(courseId);
        await adminCleanupInstitute(instId);
      }
    });
  });

  group('8. Batch cannot be transferred between owners', () {
    testWidgets(
        'owner A cannot move their batch onto owner B\'s course, and '
        'owner B cannot move owner A\'s batch onto their own course',
        (tester) async {
      final instAId = 'c4a00000-0000-4000-8000-000000000001';
      final courseAId = 'c4a00000-0000-4000-8000-000000000002';
      final batchAId = 'c4a00000-0000-4000-8000-000000000003';
      final instBId = 'c4a00000-0000-4000-8000-000000000004';
      final courseBId = 'c4a00000-0000-4000-8000-000000000005';
      try {
        await adminClient.from('institutes').insert({
          'id': instAId,
          'org_id': orgAId,
          'name': 'RLS_TEST transfer inst A'
        });
        await adminClient.from('courses').insert({
          'id': courseAId,
          'institute_id': instAId,
          'title': 'RLS_TEST transfer course A',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });
        await adminClient.from('course_batches').insert({
          'id': batchAId,
          'course_id': courseAId,
          'label': 'RLS_TEST transfer batch A',
          'starts_on': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first,
          'capacity': 10,
        });
        await adminClient.from('institutes').insert({
          'id': instBId,
          'org_id': orgBId,
          'name': 'RLS_TEST transfer inst B'
        });
        await adminClient.from('courses').insert({
          'id': courseBId,
          'institute_id': instBId,
          'title': 'RLS_TEST transfer course B',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'draft',
        });

        // Owner A tries to reassign their own batch onto owner B's course.
        // USING passes (owner A owns the current row), so Postgres does not
        // silently filter the row out of the UPDATE the way it does when
        // USING fails — it evaluates the new row against WITH CHECK, which
        // fails (owner A does not own the new course_id), and that failure
        // is a hard error ("new row violates row-level security policy"),
        // not an empty result set. Both outcomes below count as "the
        // transfer was rejected": either PostgREST returns zero rows, or it
        // throws. Only a successful, non-empty update result would mean the
        // transfer went through, which is the actual failure condition.
        List<dynamic>? ownerATransferResult;
        Object? ownerATransferError;
        try {
          ownerATransferResult = await ownerAClient
              .from('course_batches')
              .update({'course_id': courseBId})
              .eq('id', batchAId)
              .select();
        } on PostgrestException catch (e) {
          ownerATransferError = e;
        }
        final ownerATransferRejected = ownerATransferError != null ||
            (ownerATransferResult?.isEmpty ?? true);
        expect(ownerATransferRejected, isTrue,
            reason: 'owner A must not be able to move their batch onto a '
                'course they do not own (expected either a thrown '
                'PostgrestException from a WITH CHECK violation, or an '
                'empty update result) — got result=$ownerATransferResult '
                'error=$ownerATransferError');

        // Owner B tries to grab owner A's batch by reassigning it onto
        // their own course. USING must fail (owner B does not own the
        // batch's current course), so PostgREST silently excludes the row
        // and returns an empty result rather than throwing.
        final ownerBTransferResult = await ownerBClient
            .from('course_batches')
            .update({'course_id': courseBId})
            .eq('id', batchAId)
            .select();
        expect(ownerBTransferResult, isEmpty,
            reason: 'owner B must not be able to steal owner A\'s batch by '
                'reassigning it onto their own course');

        final stillOnCourseA = await adminClient
            .from('course_batches')
            .select()
            .eq('id', batchAId)
            .single();
        expect(stillOnCourseA['course_id'], courseAId,
            reason: 'the batch must still belong to its original course');
      } finally {
        await adminCleanupBatch(batchAId);
        await adminCleanupCourse(courseAId);
        await adminCleanupInstitute(instAId);
        await adminCleanupCourse(courseBId);
        await adminCleanupInstitute(instBId);
      }
    });
  });

  group('9. Public reads still work', () {
    testWidgets('anon can read a public institute and published courses',
        (tester) async {
      final instId = 'c5a00000-0000-4000-8000-000000000001';
      final courseId = 'c5a00000-0000-4000-8000-000000000002';
      try {
        await adminClient.from('institutes').insert({
          'id': instId,
          'org_id': orgAId,
          'name': 'RLS_TEST public read institute'
        });
        await adminClient.from('courses').insert({
          'id': courseId,
          'institute_id': instId,
          'title': 'RLS_TEST public read course',
          'mode': 'online',
          'duration_weeks': 4,
          'fee_amount': 100,
          'status': 'published',
        });

        final institute = await anonClient
            .from('institutes')
            .select()
            .eq('id', instId)
            .maybeSingle();
        expect(institute, isNotNull,
            reason: 'institutes_public_read must still allow anon reads');

        final course = await anonClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .maybeSingle();
        expect(course, isNotNull,
            reason: 'courses_public_read must still allow anon reads of '
                'published courses');

        await adminClient
            .from('courses')
            .update({'status': 'draft'}).eq('id', courseId);
        final draftAsAnon = await anonClient
            .from('courses')
            .select()
            .eq('id', courseId)
            .maybeSingle();
        expect(draftAsAnon, isNull,
            reason: 'courses_public_read must still hide draft courses '
                'from anon');
      } finally {
        await adminCleanupCourse(courseId);
        await adminCleanupInstitute(instId);
      }
    });
  });
}
