// Login-page diagnostic: what does the a11y tree expose after enabling semantics?
const { chromium } = require('playwright-core');

const APP_URL = 'http://127.0.0.1:8099';

(async () => {
  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: [
      '--no-sandbox',
      '--disable-web-security',
      '--enable-features=AccessibilityObjectModel',
    ],
  });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 900 } });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('[pageerror]', String(e).slice(0, 250)));

  await page.evaluate(() => { try { localStorage.clear(); } catch (e) {} });
  await page.goto(APP_URL + '/#/login', { waitUntil: 'networkidle', timeout: 60000 });
  await page
    .waitForFunction(() => !document.querySelector('.loading-wrapper'), null, {
      timeout: 90000,
      polling: 1000,
    })
    .then(() => console.log('booted ✔'))
    .catch(() => console.log('boot poll timeout'));
  await page.waitForTimeout(2500);

  // Enable semantics.
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });
  await page.waitForTimeout(4000);

  const s = await page.evaluate(() => ({
    hash: location.hash,
    semNodes: document.querySelectorAll('flt-semantics').length,
    semHosts: document.querySelectorAll('flt-semantics-host, flt-glass-pane').length,
    bodyText: document.body.innerText.slice(0, 200),
  }));
  console.log('STATE:', JSON.stringify(s, null, 2));

  const labels = await page.$$eval('flt-semantics', (els) =>
    els.map((el, i) => {
      const r = el.getBoundingClientRect();
      return {
        i,
        role: el.getAttribute('role'),
        label: (el.getAttribute('aria-label') || '').slice(0, 30),
        x: Math.round(r.x),
        y: Math.round(r.y),
        w: Math.round(r.width),
        h: Math.round(r.height),
      };
    })
  );
  console.log('NODES (' + labels.length + '):');
  for (const n of labels) {
    console.log(
      `  [${n.i}] role=${n.role} label='${n.label}' rect=(${n.x},${n.y} ${n.w}x${n.h})`
    );
  }

  await page.screenshot({ path: '/tmp/probe_login.png', fullPage: true });
  await browser.close();
})();
