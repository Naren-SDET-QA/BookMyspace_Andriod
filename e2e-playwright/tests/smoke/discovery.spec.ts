import { Fixtures } from '../../support/fixtures';
import { Ids, Tab } from '../../support/ids';
import { test } from '../../support/test';

test.describe('navigation & discovery (mock)', () => {
  test('bottom navigation reaches search, bookings, profile and home', { tag: ['@smoke'] }, async ({ app }) => {
    await app.open('/home', 'signedIn');
    await app.tap(Ids.nav(Tab.search));
    await app.expectShown(Ids.searchInput);
    await app.tap(Ids.nav(Tab.bookings));
    await app.tap(Ids.nav(Tab.profile));
    await app.reveal(Ids.logout);
    await app.expectShown(Ids.logout);
    await app.tap(Ids.nav(Tab.home));
  });

  test('search finds a venue and opens its details', { tag: ['@smoke', '@critical'] }, async ({ app, page }) => {
    await app.open('/search', 'signedIn');
    await app.fill(Ids.searchInput, Fixtures.venueSearchQuery);
    await page.keyboard.press('Enter');
    await app.tap(Ids.venueCard(Fixtures.venueId));
    await app.expectShown(Ids.bookNow);
  });
});
