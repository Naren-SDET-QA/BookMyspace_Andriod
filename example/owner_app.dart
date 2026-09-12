import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:bookmyspace/features/owner/presentation/owner_providers.dart';
import 'package:bookmyspace/features/owner/presentation/screens/owner_registration_screen.dart';

class _FakeOwnerRepository implements OwnerRepository {
  Owner get _demoOwner => const Owner(
        id: '1',
        userId: '00000000-0000-0000-0000-000000000002',
        email: 'owner@demo.com',
        name: 'Demo Owner',
      );

  @override
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    if (email == 'owner@demo.com' && password == 'password') {
      return _demoOwner;
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
    String? legalName,
    String? gstin,
    String? pan,
    String? city,
    String? state,
  }) async =>
      Owner(
        id: '1',
        userId: '00000000-0000-0000-0000-000000000002',
        email: email,
        name: name,
      );

  @override
  Future<Owner?> currentOwner() async => _demoOwner;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteOwner() async {}
}

Widget _ownerApp() {
  return ProviderScope(
    overrides: [
      ownerRepositoryProvider.overrideWithValue(_FakeOwnerRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const OwnerRegistrationScreen(),
          ),
        ],
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  runApp(_ownerApp());
}

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner Dashboard')),
      body: const Center(child: Text('Owner Dashboard - Coming Soon')),
    );
  }
}
