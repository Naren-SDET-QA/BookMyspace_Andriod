import 'auth_user.dart';

/// Phone OTP boundary used by the login UI.
///
/// The development implementation intentionally does not create a Supabase
/// session. The production implementation delegates to the existing
/// [AuthRepository] so it can be replaced with real SMS without changing the
/// screen.
abstract interface class PhoneOtpProvider {
  bool get isDevelopmentOnly;

  /// A non-null value is shown only by the development provider.
  String? get developmentOtpHint;

  Future<void> sendOtp(String phone);

  Future<PhoneOtpVerificationResult> verifyOtp(String phone, String token);
}

class PhoneOtpVerificationResult {
  const PhoneOtpVerificationResult._({
    required this.sessionCreated,
    this.user,
    this.message,
  });

  const PhoneOtpVerificationResult.authenticated(AuthUser user)
      : this._(sessionCreated: true, user: user);

  const PhoneOtpVerificationResult.developmentOnly()
      : this._(
          sessionCreated: false,
          message:
              'Phone OTP verified in development only. No Supabase session was created.',
        );

  final bool sessionCreated;
  final AuthUser? user;
  final String? message;
}
