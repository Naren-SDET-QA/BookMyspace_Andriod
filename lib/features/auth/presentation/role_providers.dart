import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_role.dart';
import 'auth_providers.dart';

/// Optional debug/testing preview mode that allows UI reviewers to browse and
/// display all admin and owner screens in the app without backend role blocks.
final previewAllScreensModeProvider = StateProvider<bool>((ref) => false);

/// Available DEV roles that can be toggled on the Profile screen to test
/// Customer, Owner, or Admin functionality on any device.
enum DevRole { customer, venueOwner, admin }

/// Active DEV role override toggled from the Profile screen.
final activeDevRoleProvider = StateProvider<DevRole?>((ref) => null);

/// Active backend roles for the signed-in user.
///
/// The query is scoped by RLS to the current user (or an administrator). The
/// result is never inferred from email, user metadata, or UI preview mode
/// unless explicitly toggled in the interactive master screen directory or profile.
final currentUserRolesProvider = FutureProvider<Set<AppRole>>((ref) async {
  final previewAll = ref.watch(previewAllScreensModeProvider);
  if (previewAll) {
    return AppRole.values.toSet();
  }

  final activeDevRole = ref.watch(activeDevRoleProvider);
  if (activeDevRole != null) {
    return switch (activeDevRole) {
      DevRole.customer => const {AppRole.customer},
      DevRole.venueOwner => const {
        AppRole.customer,
        AppRole.venueOwner,
        AppRole.instituteOwner,
      },
      DevRole.admin => const {
        AppRole.customer,
        AppRole.venueOwner,
        AppRole.instituteOwner,
        AppRole.administrator,
        AppRole.superAdministrator,
      },
    };
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
