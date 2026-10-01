import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_role.dart';
import 'auth_providers.dart';

/// Optional debug/testing preview mode that allows UI reviewers to browse and
/// display all admin and owner screens in the app without backend role blocks.
final previewAllScreensModeProvider = StateProvider<bool>((ref) => false);

/// Active backend roles for the signed-in user.
///
/// The query is scoped by RLS to the current user (or an administrator). The
/// result is never inferred from email, user metadata, or UI preview mode
/// unless explicitly toggled in the interactive master screen directory for review.
final currentUserRolesProvider = FutureProvider<Set<AppRole>>((ref) async {
  final previewAll = ref.watch(previewAllScreensModeProvider);
  if (previewAll) {
    return AppRole.values.toSet();
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return const <AppRole>{};

  final rows = await ref
      .watch(supabaseProvider)
      .from('user_roles')
      .select('role, revoked_at')
      .eq('user_id', user.id);

  return rows
      .whereType<Map<String, dynamic>>()
      .where((row) {
        return row['revoked_at'] == null;
      })
      .map((row) => AppRole.fromDatabase(row['role']))
      .whereType<AppRole>()
      .toSet();
});
