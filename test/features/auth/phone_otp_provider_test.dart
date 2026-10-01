import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/features/auth/infrastructure/development_phone_otp_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemporaryDevelopmentPhoneOtpProvider', () {
    test('accepts 123456 without creating a Supabase session', () async {
      final provider = TemporaryDevelopmentPhoneOtpProvider();

      await provider.sendOtp('+919876543210');
      final result = await provider.verifyOtp('+919876543210', '123456');

      expect(provider.isDevelopmentOnly, isTrue);
      expect(provider.developmentOtpHint, '123456');
      expect(result.sessionCreated, isFalse);
      expect(result.user, isNull);
    });

    test('rejects an incorrect OTP', () async {
      final provider = TemporaryDevelopmentPhoneOtpProvider();
      await provider.sendOtp('+919876543210');

      expect(
        provider.verifyOtp('+919876543210', '111111'),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('Invalid OTP'),
          ),
        ),
      );
    });

    test('rejects empty, short, and non-numeric OTPs', () async {
      final provider = TemporaryDevelopmentPhoneOtpProvider();
      await provider.sendOtp('+919876543210');

      for (final token in ['', '12345', 'abcdef']) {
        expect(
          provider.verifyOtp('+919876543210', token),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains('6-digit OTP'),
            ),
          ),
        );
      }
    });

    test('rejects invalid phone numbers before sending', () {
      final provider = TemporaryDevelopmentPhoneOtpProvider();

      expect(
        provider.sendOtp('123'),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('valid phone number'),
          ),
        ),
      );
    });

    test('cannot be enabled outside debug development mode', () {
      expect(
        AppConfig.isTemporaryDevelopmentPhoneOtpEnabledFor(
          debugMode: false,
          development: true,
          flag: 'true',
        ),
        isFalse,
      );
      expect(
        AppConfig.isTemporaryDevelopmentPhoneOtpEnabledFor(
          debugMode: true,
          development: false,
          flag: 'true',
        ),
        isFalse,
      );
      expect(
        AppConfig.isTemporaryDevelopmentPhoneOtpEnabledFor(
          debugMode: true,
          development: true,
          flag: 'false',
        ),
        isFalse,
      );
    });

    test('never enables the temporary provider when Supabase is configured',
        () {
      expect(
        AppConfig.isTemporaryDevelopmentPhoneOtpEnabledFor(
          debugMode: true,
          development: true,
          flag: '',
          supabaseConfigured: true,
        ),
        isFalse,
      );
      expect(
        AppConfig.isTemporaryDevelopmentPhoneOtpEnabledFor(
          debugMode: true,
          development: true,
          flag: 'true',
          supabaseConfigured: true,
        ),
        isFalse,
      );
    });

    test('UI test mode is enabled only by an explicit debug flag', () {
      expect(
        AppConfig.isUiTestModeFor(
          debugMode: true,
          development: true,
          flag: 'true',
        ),
        isTrue,
      );
      expect(
        AppConfig.isUiTestModeFor(
          debugMode: true,
          development: true,
          flag: 'TRUE',
        ),
        isTrue,
      );
      expect(
        AppConfig.isUiTestModeFor(
          debugMode: true,
          development: true,
          flag: 'false',
        ),
        isFalse,
      );
      expect(
        AppConfig.isUiTestModeFor(
          debugMode: false,
          development: true,
          flag: 'true',
        ),
        isFalse,
      );
      expect(
        AppConfig.isUiTestModeFor(
          debugMode: true,
          development: false,
          flag: 'true',
        ),
        isFalse,
      );
    });
  });
}
