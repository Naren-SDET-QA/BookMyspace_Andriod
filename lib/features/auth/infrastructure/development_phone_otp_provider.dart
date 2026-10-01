import '../../../core/config/app_config.dart';
import '../../../core/validators/app_validators.dart';
import '../domain/phone_otp_provider.dart';

/// Temporary debug-only phone OTP provider.
///
/// This provider is deliberately not an AuthRepository and never emits an
/// AuthUser or creates a Supabase session. It exists only to exercise the
/// phone OTP UI until a real SMS provider is configured.
class TemporaryDevelopmentPhoneOtpProvider implements PhoneOtpProvider {
  TemporaryDevelopmentPhoneOtpProvider() {
    if (!AppConfig.isTemporaryDevelopmentPhoneOtpEnabled) {
      throw StateError(
        'Temporary development phone OTP is disabled outside debug development mode.',
      );
    }
  }

  static const String developmentOtp = '123456';

  String? _sentPhone;

  @override
  bool get isDevelopmentOnly => true;

  @override
  String get developmentOtpHint => developmentOtp;

  @override
  Future<void> sendOtp(String phone) async {
    final normalizedPhone = phone.trim();
    final validationError = AppValidators.phone(normalizedPhone);
    if (validationError != null) throw StateError(validationError);
    _sentPhone = normalizedPhone;
  }

  @override
  Future<PhoneOtpVerificationResult> verifyOtp(
    String phone,
    String token,
  ) async {
    final normalizedPhone = phone.trim();
    final normalizedToken = token.trim();
    if (_sentPhone != normalizedPhone) {
      throw StateError('Send the verification code first');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      throw StateError('Enter a 6-digit OTP');
    }
    if (normalizedToken != developmentOtp) {
      throw StateError('Invalid OTP');
    }
    return const PhoneOtpVerificationResult.developmentOnly();
  }
}
