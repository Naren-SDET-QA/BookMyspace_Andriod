import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../domain/app_role.dart';
import '../role_providers.dart';

/// Protects an owner/admin screen with roles returned by Supabase.
///
/// This is a presentation guard only; the database RLS policies remain the
/// source of truth for every read and write performed by the screen.
class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.requiredRoles,
    required this.child,
  });

  final Set<AppRole> requiredRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(currentUserRolesProvider);
    return roles.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Access unavailable')),
        body: ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentUserRolesProvider),
        ),
      ),
      data: (userRoles) {
        if (requiredRoles.any(userRoles.contains)) return child;
        return Scaffold(
          appBar: AppBar(title: const Text('Access denied')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This area is available only to authorized BookMySpace staff or partners.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
