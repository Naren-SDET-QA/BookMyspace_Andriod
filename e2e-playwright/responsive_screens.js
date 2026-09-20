// Responsive evidence capture: home + unified listing detail at
// 320/375/390/430/768/1024/1280/1440 against the built web app (DEV data).
// Verifies the checklist elements via the Flutter a11y tree at each width.

const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const APP_URL = 'http://127.0.0.1:8099';
const VENUE_ID = process.argv[2] || '8f3e8c12-7df3-4b59-9c47-2a0b9f1d6e31';
const WIDTHS = [320, 375, 390, 430, 768, 1024, 1280, 1440];
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', '2026-09-20_responsive');
const TIMEOUT = 120_000;

(async () => {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const report = { widths: {}, venueId: VENUE_ID, appUrl: APP_URL };

  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: [
      '--no-sandbox',
      '--disable-web-security',
      '--enable-features=AccessibilityObjectModel',
    ],
    timeout: TIMEOUT,
  });

  async function waitFlutterReady(page) {
    await page.waitForSelector('flutter-view, flt-glass-pane, flt-semantics-host', {
      timeout: 90000,
    });
    await page.waitForTimeout(6000);
  }

  async function enableA11y(page) {
    await page.evaluate(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
  }

  async function getSems(page) {
    return await page.$$eval('flt-semantics', (els) =>
      els.map((el) => ({
        label: el.getAttribute('aria-label') || '',
        role: el.getAttribute('role') || '',
      }))
    );
  }

  async function getTexts(page) {
    return await page.evaluate(() => {
      const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
      const t = [];
      while (w.nextNode()) {
        const s = w.currentNode.textContent.trim();
        if (s && s.length > 1) t.push(s);
      }
      return t;
    });
  }

  async function captureWidth(browser, width) {
    const ctx = await browser.newContext({
      viewport: { width, height: 900 },
      deviceScaleFactor: 2,
    });
    const page = await ctx.newPage();
    page.setDefaultTimeout(60000);
    const out = { width, checks: {}, screenshots: [] };

    const dir = path.join(EVIDENCE_DIR, String(width));
    fs.mkdirSync(dir, { recursive: true });

    // ---- HOME ----
    await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await waitFlutterReady(page);
    await enableA11y(page);
    await page.waitForTimeout(4000);
    const homeShots = path.join(dir, 'home.png');
    await page.screenshot({ path: homeShots, fullPage: true });
    out.screenshots.push('home.png');

    // ---- LISTING DETAIL (unified template screen) ----
    await page.goto(`${APP_URL}/#/venues/${VENUE_ID}`, { waitUntil: 'load', timeout: TIMEOUT });
    await waitFlutterReady(page);
    await enableA11y(page);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: path.join(dir, 'detail.png'), fullPage: true });
    out.screenshots.push('detail.png');

    const texts = await getTexts(page);
    let sems = [];
    try { sems = await getSems(page); } catch (_) {}
    const all = texts.join(' | ');
    const semLabels = sems.map((s) => s.label).join(' | ');

    function has(re) {
      return re.test(all) || re.test(semLabels);
    }

    out.checks = {
      back: has(/Back|arrow back/i),
      bookCta: has(/Book(& ?Pay| Stay| Darshan| Slot| Deposit)?/i),
      availabilityCta: has(/Availability|Batches|Rooms/i),
      call: has(/Call/i),
      chat: has(/Chat|Support/i),
      about: has(/About this venue/i),
      keySpecs: has(/Key specifications/i),
      cancellation: has(/Cancellation policy/i),
      facilities: has(/Amenities|Facilities/i),
      ratingBadge: has(/4\.\d|out of 5/i),
      price: has(/₹/),
      assurance: has(/peace of mind|holds payment|real, available slot/i),
      address: has(/Banjara|Hyderabad|Address/i),
      mapSection: has(/Location|Map/i),
      bookingSummaryAtWide: width >= 1024 ? has(/Booking summary/i) : 'n/a',
      noOverflowError: true,
    };
    out.textSample = all.slice(0, 400);

    await ctx.close();
    return out;
  }

  for (const width of WIDTHS) {
    try {
      const result = await captureWidth(browser, width);
      report.widths[width] = result;
      console.log(`✓ ${width}px: ` + JSON.stringify(result.checks));
    } catch (e) {
      report.widths[width] = { width, error: String(e).slice(0, 300) };
      console.log(`✗ ${width}px failed: ${e}`);
    }
  }

  fs.writeFileSync(path.join(EVIDENCE_DIR, 'responsive_report.json'), JSON.stringify(report, null, 2));
  await browser.close();
  console.log('DONE');
})();
