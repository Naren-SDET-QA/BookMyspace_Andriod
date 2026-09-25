// Detail-route diagnostic: does /#/venues/:id render the unified listing?
const { chromium } = require('playwright-core');

const APP_URL = process.env.APP_URL || 'http://127.0.0.1:8099';
const VENUE_ID = process.argv[2] || '8f3e8c12-7df3-4b59-9c47-2a0b9f1d6e31';

(async () => {
  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: ['--no-sandbox', '--disable-web-security'],
  });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 900 } });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('[pageerror]', String(e).slice(0, 300)));

  // Boot home first, then client-side navigate to the detail route.
  await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: 60000 });
  await page
    .waitForFunction(() => !document.querySelector('.loading-wrapper'), null, {
      timeout: 90000,
      polling: 1000,
    })
    .then(() => console.log('booted ✔'))
    .catch(() => console.log('boot poll timed out'));

  await page.evaluate((id) => {
    window.location.hash = `#/venues/${id}`;
    window.dispatchEvent(new HashChangeEvent('hashchange'));
  }, VENUE_ID);
  await page.waitForTimeout(10000);

  const s = await page.evaluate(() => ({
    hash: location.hash,
    bodyText: document.body.innerText.replace(/\s+/g, ' ').slice(0, 500),
    semCount: document.querySelectorAll('flt-semantics').length,
  }));
  console.log('STATE:', JSON.stringify(s, null, 2));

  // Enable semantics and sample labels.
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });
  await page.waitForTimeout(4000);
  const labels = await page.$$eval('flt-semantics', (els) =>
    els
      .map((el) => el.getAttribute('aria-label') || '')
      .filter(Boolean)
      .slice(0, 40)
  );
  console.log('SEMANTIC LABELS:', JSON.stringify(labels, null, 1));

  await page.screenshot({ path: '/tmp/probe_detail.png', fullPage: true });
  await browser.close();
})();
