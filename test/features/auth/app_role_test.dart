import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/auth/presentation/widgets/role_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps only deployed database role values', () {
    expect(AppRole.fromDatabase('venue_owner'), AppRole.venueOwner);
    expect(AppRole.fromDatabase('ADMINISTRATOR'), AppRole.administrator);
    expect(AppRole.fromDatabase('owner'), isNull);
    expect(AppRole.fromDatabase(''), isNull);
  });

  testWidgets('role gate renders the protected child only for granted roles',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserRolesProvider.overrideWith(
            (ref) async => {AppRole.venueOwner},
          ),
        ],
        child: const MaterialApp(
          home: RoleGate(
            requiredRoles: {AppRole.venueOwner},
            child: Text('owner content'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('owner content'), findsOneWidget);
    expect(find.text('Access denied'), findsNothing);
  });

  testWidgets('role gate denies an unrelated role', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserRolesProvider.overrideWith(
            (ref) async => {AppRole.customer},
          ),
        ],
        child: const MaterialApp(
          home: RoleGate(
            requiredRoles: {AppRole.administrator},
            child: Text('admin content'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('admin content'), findsNothing);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('administrator access does not grant owner access',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserRolesProvider.overrideWith(
            (ref) async => {AppRole.administrator},
          ),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: RoleGate(
                  requiredRoles: {AppRole.administrator},
                  child: Text('admin content'),
                ),
              ),
              Expanded(
                child: RoleGate(
                  requiredRoles: {AppRole.venueOwner},
                  child: Text('owner content'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('admin content'), findsOneWidget);
    expect(find.text('owner content'), findsNothing);
    expect(find.text('Access denied'), findsOneWidget);
  });
}
