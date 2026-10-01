import 'auth_user.dart';

sealed class AuthState {
  const AuthState();

  AuthUser? get user => null;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});
  @override
  final AuthUser user;
}
