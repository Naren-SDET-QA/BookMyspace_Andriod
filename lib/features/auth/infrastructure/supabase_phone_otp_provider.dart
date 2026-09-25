import '../domain/auth_repository.dart';
import '../domain/phone_otp_provider.dart';

/// Production phone OTP adapter.
///
/// It delegates to the existing Supabase-backed AuthRepository. When SMS is
/// enabled later, only the provider selection/configuration needs to change.
class SupabasePhoneOtpProvider implements PhoneOtpProvider {
  const SupabasePhoneOtpProvider(this._repository);

  final AuthRepository _repository;

  @override
  bool get isDevelopmentOnly => false;

  @override
  String? get developmentOtpHint => null;

  @override
  Future<void> sendOtp(String phone) {
    return _repository.signInWithPhoneOtp(phone);
  }

  @override
  Future<PhoneOtpVerificationResult> verifyOtp(
    String phone,
    String token,
  ) async {
    final user = await _repository.verifyPhoneOtp(phone, token);
    return PhoneOtpVerificationResult.authenticated(user);
  }
}
