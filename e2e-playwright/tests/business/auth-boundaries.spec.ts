import { Fixtures } from '../../support/fixtures';
import { Ids, Tab } from '../../support/ids';
import { test } from '../../support/test';

test.describe('auth & role boundaries (mock)', () => {
  test('invalid password shows an error and stays signed out', { tag: ['@auth', '@negative'] }, async ({ app }) => {
    await app.open('/login', 'invalidLogin');
    await app.fill(Ids.loginEmail, Fixtures.customerEmail);
    await app.fill(Ids.loginPassword, Fixtures.mockPassword);
    await app.tap(Ids.loginSubmit);
    await app.expectShown(Ids.loginError);
    await app.expectShown(Ids.loginSubmit);
    await app.expectNotShown(Ids.nav(Tab.home));
  });

  test('invalid OTP shows an error and does not sign in', { tag: ['@auth', '@negative'] }, async ({ app }) => {
    await app.open('/login', 'invalidOtp');
    await app.fill(Ids.otpContact, Fixtures.customerEmail);
    await app.tap(Ids.otpSend);
    await app.fill(Ids.otpCode, Fixtures.mockOtp);
    await app.tap(Ids.otpSubmit);
    await app.expectShown(Ids.loginError);
    await app.expectNotShown(Ids.nav(Tab.home));
  });

  test('signed-out deep link to the owner area requires sign-in', { tag: ['@auth', '@owner', '@negative'] }, async ({ app }) => {
    await app.open('/owner/bookings', 'signedOut');
    await app.expectShown(Ids.loginSubmit);
    await app.expectLocation('/login');
    await app.expectNotShown(Ids.ownerDashboard);
  });

  for (const route of ['/owner', '/admin']) {
    test(`customer is redirected away from ${route}`, { tag: ['@auth', '@owner', '@admin', '@negative'] }, async ({ app }) => {
      await app.open(route, 'signedIn');
      await app.reveal(Ids.logout);
      await app.expectLocation('/profile');
      await app.expectNotShown(Ids.ownerDashboard);
      await app.expectNotShown(Ids.adminDashboard);
      await app.expectNotShown(Ids.profileOwnerDashboard);
      await app.expectNotShown(Ids.profileAdminDashboard);
    });
  }

  test('owner signs in and reaches the owner dashboard', { tag: ['@critical', '@auth', '@owner'] }, async ({ app }) => {
    await app.open('/login', 'signedOut');
    await app.fill(Ids.loginEmail, Fixtures.ownerEmail);
    await app.fill(Ids.loginPassword, Fixtures.mockPassword);
    await app.tap(Ids.loginSubmit);
    await app.tap(Ids.nav(Tab.profile));
    await app.reveal(Ids.profileOwnerDashboard);
    await app.expectNotShown(Ids.profileAdminDashboard);
    await app.tap(Ids.profileOwnerDashboard);
    await app.expectShown(Ids.ownerDashboard);
    await app.expectShown(Ids.ownerActionBookings);
    // Pushed over the profile tab: go_router `push` does not change the URL.
    await app.expectNotShown(Ids.logout);
  });

  test('owner is redirected away from the admin area', { tag: ['@auth', '@owner', '@admin', '@negative'] }, async ({ app }) => {
    await app.open('/admin', 'ownerSignedIn');
    await app.reveal(Ids.logout);
    await app.expectLocation('/profile');
    await app.expectNotShown(Ids.adminDashboard);
    await app.expectNotShown(Ids.profileAdminDashboard);
  });

  test('admin reaches the admin dashboard from profile', { tag: ['@auth', '@admin'] }, async ({ app }) => {
    await app.open('/profile', 'adminSignedIn');
    await app.reveal(Ids.profileAdminDashboard);
    await app.tap(Ids.profileAdminDashboard);
    await app.expectShown(Ids.adminDashboard);
    // Pushed over the profile tab: go_router `push` does not change the URL.
    await app.expectNotShown(Ids.logout);
  });
});
