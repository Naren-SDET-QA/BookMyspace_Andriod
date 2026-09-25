import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';

void main() {
  test('appRouterProvider reuses the same GoRouter instance', () {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final first = container.read(appRouterProvider(AppRoutes.home));
    final second = container.read(appRouterProvider(AppRoutes.home));
    expect(identical(first, second), isTrue);
  });
}
