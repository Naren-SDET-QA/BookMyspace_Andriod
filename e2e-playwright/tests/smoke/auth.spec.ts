import { Fixtures } from '../../support/fixtures';
import { Ids, Tab } from '../../support/ids';
import { test } from '../../support/test';

test.describe('auth (mock)', () => {
  test('app launch shows sign-in when signed out', { tag: ['@smoke', '@critical', '@auth'] }, async ({ app }) => {
    await app.open('/home', 'signedOut');
    await app.expectShown(Ids.loginSubmit);
    await app.expectShown(Ids.otpSend);
  });

  test('email/password sign-in lands on the home shell', { tag: ['@smoke', '@critical', '@auth'] }, async ({ app }) => {
    await app.open('/login', 'signedOut');
    await app.fill(Ids.loginEmail, Fixtures.customerEmail);
    await app.fill(Ids.loginPassword, Fixtures.mockPassword);
    await app.tap(Ids.loginSubmit);
    await app.expectShown(Ids.nav(Tab.home));
    await app.expectShown(Ids.nav(Tab.profile));
  });

  test('email OTP sign-in lands on the home shell', { tag: ['@smoke', '@auth'] }, async ({ app }) => {
    await app.open('/login', 'signedOut');
    await app.fill(Ids.otpContact, Fixtures.customerEmail);
    await app.tap(Ids.otpSend);
    await app.fill(Ids.otpCode, Fixtures.mockOtp);
    await app.tap(Ids.otpSubmit);
    await app.expectShown(Ids.nav(Tab.home));
  });

  test('sign-out returns to sign-in', { tag: ['@smoke', '@auth'] }, async ({ app }) => {
    await app.open('/profile', 'signedIn');
    await app.reveal(Ids.logout);
    await app.tap(Ids.logout);
    await app.expectShown(Ids.loginSubmit);
  });
});
