import 'dart:async';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/domain/phone_otp_provider.dart';
import 'package:bookmyspace/features/auth/infrastructure/development_phone_otp_provider.dart';
import 'package:bookmyspace/features/auth/infrastructure/supabase_phone_otp_provider.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

Widget _wrap(MockAuthRepository repo, {PhoneOtpProvider? otpProvider}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      phoneOtpProvider.overrideWithValue(
        otpProvider ?? SupabasePhoneOtpProvider(repo),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(),
    ),
  );
}

Future<void> _pumpLogin(
  WidgetTester tester,
  MockAuthRepository repo, {
  PhoneOtpProvider? otpProvider,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(repo, otpProvider: otpProvider));
  await tester.pumpAndSettle();
}

Future<void> _tapOtpSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('otp-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
}

void main() {
  testWidgets('sends email OTP then verifies and shows success path', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await _pumpLogin(tester, repo);

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.signInCount, 1);
    expect(find.textContaining('verification code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '123456');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.verifyCount, 1);
    expect(repo.currentUser?.email, 'a@b.com');
    repo.dispose();
  });

  testWidgets('toggles between email and phone channels', (tester) async {
    final repo = MockAuthRepository();
    await _pumpLogin(tester, repo);

    await tester.tap(find.text('Phone'));

    await tester.enterText(find.byType(TextFormField).first, '9999999999');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();
    expect(repo.signInCount, 1);
    repo.dispose();
  });

  testWidgets('shows an error when OTP send fails', (tester) async {
    final repo = MockAuthRepository()..failSignIn = true;
    await _pumpLogin(tester, repo);

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('OTP send failed'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('development phone OTP verifies without creating a session', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await _pumpLogin(
      tester,
      repo,
      otpProvider: TemporaryDevelopmentPhoneOtpProvider(),
    );

    await tester.tap(find.text('Phone'));
    await tester.enterText(
      find.byType(TextFormField).first,
      '+919876543210',
    );
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Development OTP: 123456'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No Supabase session was created'),
      findsOneWidget,
    );
    expect(repo.currentUser, isNull);
    repo.dispose();
  });

  testWidgets('phone validation rejects an invalid number', (tester) async {
    final repo = MockAuthRepository();
    await _pumpLogin(
      tester,
      repo,
      otpProvider: TemporaryDevelopmentPhoneOtpProvider(),
    );

    await tester.tap(find.text('Phone'));
    await tester.enterText(find.byType(TextFormField).first, '123');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(repo.signInCount, 0);
    repo.dispose();
  });

  testWidgets('phone verification rejects an incorrect OTP', (tester) async {
    final repo = MockAuthRepository();
    await _pumpLogin(
      tester,
      repo,
      otpProvider: TemporaryDevelopmentPhoneOtpProvider(),
    );

    await tester.tap(find.text('Phone'));
    await tester.enterText(
      find.byType(TextFormField).first,
      '+919876543210',
    );
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '111111');
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Invalid OTP'), findsOneWidget);
    expect(repo.currentUser, isNull);
    repo.dispose();
  });

  testWidgets('prevents duplicate phone OTP sends while loading', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    final otpProvider = _DelayedPhoneOtpProvider();
    await _pumpLogin(tester, repo, otpProvider: otpProvider);

    await tester.tap(find.text('Phone'));
    await tester.enterText(
      find.byType(TextFormField).first,
      '+919876543210',
    );
    await _tapOtpSubmit(tester);
    await tester.pump();
    await _tapOtpSubmit(tester);
    await tester.pump();

    expect(otpProvider.sendCount, 1);
    otpProvider.completeSend();
    await tester.pumpAndSettle();
    repo.dispose();
  });

  testWidgets('prevents duplicate phone OTP verification while loading', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    final otpProvider = _DelayedVerificationPhoneOtpProvider();
    await _pumpLogin(tester, repo, otpProvider: otpProvider);

    await tester.tap(find.text('Phone'));
    await tester.enterText(
      find.byType(TextFormField).first,
      '+919876543210',
    );
    await _tapOtpSubmit(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await _tapOtpSubmit(tester);
    await tester.pump();
    await _tapOtpSubmit(tester);
    await tester.pump();

    expect(otpProvider.verifyCount, 1);
    otpProvider.completeVerify();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No Supabase session was created'),
      findsOneWidget,
    );
    repo.dispose();
  });

  testWidgets('renders Google and Apple sign-in buttons', (tester) async {
    final repo = MockAuthRepository();
    await _pumpLogin(tester, repo);

    expect(find.byKey(const Key('google-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('apple-sign-in')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Phone'), findsWidgets);
    repo.dispose();
  });

  testWidgets('shows Google loading state and ignores duplicate taps', (
    tester,
  ) async {
    final repo = MockAuthRepository()..delayedGoogle = Completer<AuthUser>();
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pump();

    expect(find.text('Connecting to Google...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.tap(find.byKey(const Key('apple-sign-in')));
    await tester.tap(find.byKey(const Key('otp-submit')));
    await tester.pump();

    expect(repo.googleCount, 1);
    expect(repo.appleCount, 0);
    expect(repo.signInCount, 0);

    repo.delayedGoogle!.complete(
      const AuthUser(id: 'mock-user', email: 'mock@test.com'),
    );
    await tester.pumpAndSettle();
    expect(repo.currentUser?.email, 'mock@test.com');
    repo.dispose();
  });

  testWidgets('shows Apple loading state and ignores duplicate taps', (
    tester,
  ) async {
    final repo = MockAuthRepository()..delayedApple = Completer<AuthUser>();
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('apple-sign-in')));
    await tester.pump();

    expect(find.text('Connecting to Apple...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.tap(find.byKey(const Key('apple-sign-in')));
    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pump();

    expect(repo.appleCount, 1);
    expect(repo.googleCount, 0);

    repo.delayedApple!.complete(
      const AuthUser(id: 'mock-user', email: 'mock@test.com'),
    );
    await tester.pumpAndSettle();
    expect(repo.currentUser?.email, 'mock@test.com');
    repo.dispose();
  });

  testWidgets('shows a muted message when Google sign-in is cancelled', (
    tester,
  ) async {
    final repo = MockAuthRepository()..cancelGoogle = true;
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
    expect(repo.currentUser, isNull);
    repo.dispose();
  });

  testWidgets('shows a muted message when Apple sign-in is cancelled', (
    tester,
  ) async {
    final repo = MockAuthRepository()..cancelApple = true;
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('apple-sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('Apple sign-in was cancelled.'), findsOneWidget);
    expect(repo.currentUser, isNull);
    repo.dispose();
  });

  testWidgets('surfaces Google sign-in errors', (tester) async {
    final repo = MockAuthRepository()..failGoogle = true;
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('google-sign-in')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google sign-in failed'), findsOneWidget);
    expect(repo.currentUser, isNull);
    repo.dispose();
  });

  testWidgets('surfaces Apple sign-in errors', (tester) async {
    final repo = MockAuthRepository()..failApple = true;
    await _pumpLogin(tester, repo);

    await tester.tap(find.byKey(const Key('apple-sign-in')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Apple sign-in failed'), findsOneWidget);
    expect(repo.currentUser, isNull);
    repo.dispose();
  });
}

class _DelayedPhoneOtpProvider implements PhoneOtpProvider {
  final Completer<void> _sendCompleter = Completer<void>();
  int sendCount = 0;

  @override
  bool get isDevelopmentOnly => true;

  @override
  String? get developmentOtpHint => '123456';

  @override
  Future<void> sendOtp(String phone) async {
    sendCount++;
    await _sendCompleter.future;
  }

  @override
  Future<PhoneOtpVerificationResult> verifyOtp(
    String phone,
    String token,
  ) async {
    return const PhoneOtpVerificationResult.developmentOnly();
  }

  void completeSend() {
    if (!_sendCompleter.isCompleted) _sendCompleter.complete();
  }
}

class _DelayedVerificationPhoneOtpProvider implements PhoneOtpProvider {
  final Completer<PhoneOtpVerificationResult> _verifyCompleter =
      Completer<PhoneOtpVerificationResult>();
  int verifyCount = 0;

  @override
  bool get isDevelopmentOnly => true;

  @override
  String? get developmentOtpHint => '123456';

  @override
  Future<void> sendOtp(String phone) async {}

  @override
  Future<PhoneOtpVerificationResult> verifyOtp(
    String phone,
    String token,
  ) async {
    verifyCount++;
    return _verifyCompleter.future;
  }

  void completeVerify() {
    if (!_verifyCompleter.isCompleted) {
      _verifyCompleter.complete(
        const PhoneOtpVerificationResult.developmentOnly(),
      );
    }
  }
}
