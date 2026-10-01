// Boot diagnostic: which state does the app reach on the static build?
// States: loading screen -> flutter canvas paints (wrapper removed) | timeout card.
const { chromium } = require('playwright-core');

const APP_URL = process.env.APP_URL || 'http://127.0.0.1:8099';

(async () => {
  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: ['--no-sandbox', '--disable-web-security'],
  });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 900 } });
  const page = await ctx.newPage();

  page.on('console', (m) => {
    const t = m.text();
    if (m.type() === 'error' || m.type() === 'warning' || /flutter|dart|error/i.test(t)) {
      console.log('[console]', m.type(), t.slice(0, 220));
    }
  });
  page.on('pageerror', (e) => console.log('[pageerror]', String(e).slice(0, 300)));
  page.on('requestfailed', (r) =>
    console.log('[reqfail]', r.url().slice(0, 120), '→', r.failure()?.errorText)
  );

  await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: 60000 });

  // Poll boot state every 2s for up to 90s.
  for (let i = 0; i < 45; i++) {
    const s = await page.evaluate(() => ({
      wrapperGone: !document.querySelector('.loading-wrapper'),
      canvas: document.querySelectorAll('canvas').length,
      flutterView: document.querySelectorAll('flutter-view').length,
      glassPane: document.querySelectorAll('flt-glass-pane').length,
      timeoutCard:
        document.getElementById('loading-timeout-view')?.style.display === 'block',
      statusText: document.getElementById('loading-status-text')?.textContent || '',
      progress:
        document.getElementById('loading-progress-text')?.textContent || '',
      diagBox:
        document.getElementById('diagnostic-details-box')?.innerText?.slice(0, 400) ||
        '',
    }));
    if (i % 3 === 0 || s.wrapperGone || s.timeoutCard) {
      console.log(`t=${i * 2}s`, JSON.stringify(s));
    }
    if (s.wrapperGone) { console.log('BOOTED ✔'); break; }
    if (s.timeoutCard) { console.log('BOOT TIMEOUT CARD SHOWN ✘'); break; }
    await page.waitForTimeout(2000);
  }

  await page.screenshot({ path: '/tmp/probe_home.png', fullPage: true });
  await browser.close();
})();
