import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

class AuthRobot extends BaseRobot {
  AuthRobot(super.tester);

  Future<void> expectSignInScreen() async {
    await waitFor(E2eIds.loginSubmit);
    await waitFor(E2eIds.otpSend);
  }

  Future<void> signInWithPassword(String email, String password) async {
    await enterText(E2eIds.loginEmail, email);
    await enterText(E2eIds.loginPassword, password);
    await tap(E2eIds.loginSubmit);
  }

  /// Sends an email OTP (the default channel) and waits for the code field.
  Future<void> requestEmailOtp(String email) async {
    await enterText(E2eIds.otpContact, email);
    await tap(E2eIds.otpSend);
    await waitFor(E2eIds.otpCode);
  }

  Future<void> submitOtp(String code) async {
    await enterText(E2eIds.otpCode, code);
    await tap(E2eIds.otpSubmit);
  }

  Future<void> expectSignInError() => waitFor(E2eIds.loginError);

  Future<void> signOut() async {
    await reveal(E2eIds.logout);
    await tap(E2eIds.logout);
  }
}
