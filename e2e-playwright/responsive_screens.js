// Responsive evidence capture — v2.
// Boots the static web build, logs in with the DEV E2E customer account,
// captures home + unified listing detail at 320/375/390/430/768/1024/1280/1440,
// and asserts the checklist via the Flutter accessibility tree + DOM text.
//
// Usage: node responsive_screens.js [venueId]
// Requires: DEV_E2E_CUSTOMER_EMAIL / DEV_E2E_CUSTOMER_PASSWORD in .env.dev,
// a static server on :8099 serving build/web, and built web assets.
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const APP_URL = 'http://127.0.0.1:8099';
const VENUE_ID = process.argv[2] || '8f3e8c12-7df3-4b59-9c47-2a0b9f1d6e31';
const WIDTHS = process.env.WIDTHS
  ? JSON.parse(process.env.WIDTHS)
  : [320, 375, 390, 430, 768, 1024, 1280, 1440];
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', '2026-09-20_responsive');
const TIMEOUT = 120000;

function readEnv(file) {
  const out = {};
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return out;
}
const env = readEnv(path.resolve(__dirname, '..', '.env.dev'));
const CUSTOMER_EMAIL = env.DEV_E2E_CUSTOMER_EMAIL;
const CUSTOMER_PASSWORD = env.DEV_E2E_CUSTOMER_PASSWORD;
if (!CUSTOMER_EMAIL || !CUSTOMER_PASSWORD) {
  console.error('Missing DEV_E2E_CUSTOMER_* in .env.dev');
  process.exit(1);
}

(async () => {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const report = { appUrl: APP_URL, venueId: VENUE_ID, widths: {}, startedAt: new Date().toISOString() };
  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: [
      '--no-sandbox',
      '--disable-web-security',
      '--enable-features=AccessibilityObjectModel',
    ],
  });

  async function newPage(width) {
    const ctx = await browser.newContext({
      viewport: { width, height: 900 },
      deviceScaleFactor: 2,
    });
    const page = await ctx.newPage();
    page.setDefaultTimeout(90000);
    return { ctx, page };
  }

  async function waitBoot(page) {
    await page.waitForFunction(
      () => !document.querySelector('.loading-wrapper'),
      null,
      { timeout: 90000, polling: 1000 }
    );
    await page.waitForTimeout(2500);
  }

  async function enableA11y(page) {
    await page.evaluate(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await page.waitForTimeout(3500);
  }

  async function cdpClick(page, ctx, x, y) {
    const c = await ctx.newCDPSession(page);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await c.send('Input.dispatchMouseEvent', {
        type, x, y, button: 'left', clickCount: 1,
      });
    }
    await c.detach();
  }

  async function getSems(page) {
    return await page.$$eval('flt-semantics', (els) =>
      els.map((el) => {
        const r = el.getBoundingClientRect();
        return {
          label: el.getAttribute('aria-label') || '',
          role: el.getAttribute('role') || '',
          rect: { x: r.x, y: r.y, w: r.width, h: r.height },
        };
      })
    );
  }

  async function login(page, ctx, viewportWidth) {
    await page.evaluate(() => { try { localStorage.clear(); } catch (e) {} });
    await page.goto(APP_URL + '/#/login', { waitUntil: 'networkidle', timeout: TIMEOUT });
    await waitBoot(page);
    await enableA11y(page);
    const sems = await getSems(page);
    // The login form exposes no a11y labels; identify fields geometrically:
    // two stacked wide input-height nodes, then the submit button below them.
    const wide = viewportWidth * 0.6;
    const inputs = sems
      .filter(
        (s) =>
          s.role !== 'button' &&
          s.rect.w >= wide &&
          s.rect.h >= 40 && s.rect.h <= 80 &&
          s.rect.y > 300
      )
      .sort((a, b) => a.rect.y - b.rect.y);
    const buttons = sems
      .filter((s) => s.role === 'button' && s.rect.w > wide && s.rect.y > 300)
      .sort((a, b) => a.rect.y - b.rect.y);
    const belowLast = inputs.length ? inputs[inputs.length - 1].rect.y : 0;
    const submit =
      buttons.find((b) => b.rect.y > belowLast) ||
      buttons[buttons.length - 1];
    if (inputs.length < 2 || !submit) {
      throw new Error(
        'login: mapped inputs=' + inputs.length + ' buttons=' + buttons.length
      );
    }
    const email = inputs[0];
    const password = inputs[1];
    await cdpClick(page, ctx, email.rect.x + email.rect.w / 2, email.rect.y + email.rect.h / 2);
    await page.keyboard.type(CUSTOMER_EMAIL, { delay: 20 });
    await page.waitForTimeout(300);
    await cdpClick(page, ctx, password.rect.x + password.rect.w / 2, password.rect.y + password.rect.h / 2);
    await page.keyboard.type(CUSTOMER_PASSWORD, { delay: 20 });
    await page.waitForTimeout(300);
    await cdpClick(page, ctx, submit.rect.x + submit.rect.w / 2, submit.rect.y + submit.rect.h / 2);
    await page.waitForTimeout(7000);
    return await page.evaluate(() => location.hash);
  }

  async function captureWidth(width) {
    const dir = path.join(EVIDENCE_DIR, String(width));
    fs.mkdirSync(dir, { recursive: true });
    const out = { width, checks: {}, screenshots: [], error: null };
    const { ctx, page } = await newPage(width);
    try {
      const hash = await login(page, ctx, width);
      out.loginHash = hash;
      if (/login/.test(hash)) throw new Error('login failed, still at: ' + hash);

      // Home evidence.
      await page.goto(APP_URL + '/#/', { waitUntil: 'load', timeout: TIMEOUT });
      await waitBoot(page);
      await enableA11y(page);
      await page.screenshot({ path: path.join(dir, 'home.png'), fullPage: true });
      out.screenshots.push('home.png');

      // Detail evidence (unified listing template screen).
      await page.evaluate((id) => {
        window.location.hash = '#/venues/' + id;
        window.dispatchEvent(new HashChangeEvent('hashchange'));
      }, VENUE_ID);
      await page.waitForTimeout(9000);
      await enableA11y(page);
      await page.screenshot({ path: path.join(dir, 'detail.png'), fullPage: true });
      out.screenshots.push('detail.png');

      const texts = await page.evaluate(() => document.body.innerText);
      const sems = await getSems(page);
      const semLabels = sems.map((s) => s.label).join(' | ');
      const all = texts + ' | ' + semLabels;
      const has = (re) => re.test(all);
      const detailHash = await page.evaluate(() => location.hash);

      out.checks = {
        onDetailRoute: /venues/.test(detailHash),
        back: has(/Back|Go back/),
        bookCta: has(/Book(& ?Pay| Stay| Darshan| Slot| Deposit)?/),
        availabilityCta: has(/Availability|Batches|Rooms/),
        call: has(/\bCall\b/),
        chat: has(/\bChat\b|Support/),
        about: has(/About this venue/),
        keySpecs: has(/Key specifications/),
        cancellation: has(/Cancellation policy/),
        facilities: has(/Amenities|Facilities/),
        rating: has(/out of 5|4\.\d/),
        price: has(/[₹]\s?\d/),
        assurance: has(/holds payment|real, available slot|peace of mind/i),
        addressOrMap: has(/Hyderabad|Location|Map/),
        reviews: has(/Ratings & reviews|Reviews/),
        bookingSummary: width >= 1024 ? has(/Booking summary/) : 'n/a',
      };
      out.textSample = texts.replace(/\s+/g, ' ').slice(0, 350);
    } catch (e) {
      out.error = String(e).slice(0, 300);
    } finally {
      await ctx.close();
    }
    return out;
  }

  for (const width of WIDTHS) {
    const out = await captureWidth(width);
    report.widths[width] = out;
    console.log(
      out.error
        ? 'X ' + width + 'px failed: ' + out.error
        : 'OK ' + width + 'px: ' + JSON.stringify(out.checks)
    );
  }

  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(
    path.join(EVIDENCE_DIR, 'responsive_report.json'),
    JSON.stringify(report, null, 2)
  );
  await browser.close();
  console.log('DONE');
})();
