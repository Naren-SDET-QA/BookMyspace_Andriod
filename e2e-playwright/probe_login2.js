// Login trace: what happens after submit? Did the session persist?
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const APP_URL = 'http://127.0.0.1:8099';
const VENUE_ID = '8f3e8c12-7df3-4b59-9c47-2a0b9f1d6e31';

function readEnv(file) {
  const out = {};
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return out;
}
const env = readEnv(path.resolve(__dirname, '..', '.env.dev'));

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

  await page.evaluate(() => { try { localStorage.clear(); } catch (e) {} });
  await page.goto(APP_URL + '/#/login', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForFunction(
    () => !document.querySelector('.loading-wrapper'), null, { timeout: 90000, polling: 1000 }
  );
  await page.waitForTimeout(2500);
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  });
  await page.waitForTimeout(3500);

  const sems = await page.$$eval('flt-semantics', (els) =>
    els.map((el) => {
      const r = el.getBoundingClientRect();
      return { role: el.getAttribute('role'), x: r.x, y: r.y, w: r.width, h: r.height };
    })
  );
  console.log('nodes:', JSON.stringify(sems.filter((s) => s.w > 0)));

  const inputs = sems
    .filter((s) => s.w >= 234 && s.h >= 40 && s.h <= 80 && s.y > 300)
    .sort((a, b) => a.y - b.y);
  const buttons = sems
    .filter((s) => s.role === 'button' && s.w > 234 && s.y > 300)
    .sort((a, b) => a.y - b.y);

  async function cdpClick(x, y) {
    const c = await ctx.newCDPSession(page);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await c.send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    }
    await c.detach();
  }

  console.log('typing email into input@y=' + inputs[0].y);
  await cdpClick(inputs[0].x + inputs[0].w / 2, inputs[0].y + inputs[0].h / 2);
  await page.keyboard.type(env.DEV_E2E_CUSTOMER_EMAIL, { delay: 15 });
  await page.waitForTimeout(300);
  console.log('text after email:', JSON.stringify(await page.evaluate(() => document.body.innerText.slice(0, 300))));

  console.log('typing password into input@y=' + inputs[1].y);
  await cdpClick(inputs[1].x + inputs[1].w / 2, inputs[1].y + inputs[1].h / 2);
  await page.keyboard.type(env.DEV_E2E_CUSTOMER_PASSWORD, { delay: 15 });
  await page.waitForTimeout(300);

  const btnY = buttons.map((b) => b.y);
  console.log('buttons at y:', JSON.stringify(btnY));
  const last = inputs[inputs.length - 1].y;
  const submit = buttons.find((b) => b.y > last) || buttons[buttons.length - 1];
  console.log('clicking submit@y=' + submit.y);
  await cdpClick(submit.x + submit.w / 2, submit.y + submit.h / 2);

  for (let i = 0; i < 8; i++) {
    await page.waitForTimeout(2000);
    const s = await page.evaluate(() => ({
      hash: location.hash,
      keys: Object.keys(localStorage).filter((k) => /sb-|auth|supabase/i.test(k)).map((k) => k.slice(0, 40)),
      err: document.body.innerText.match(/(incorrect|invalid|error|Enter your)[^|]*/i)?.[0] || '',
    }));
    console.log('t+' + (i + 1) * 2 + 's', JSON.stringify(s));
  }

  // Now try the detail route in the same session.
  await page.evaluate((id) => {
    window.location.hash = '#/venues/' + id;
    window.dispatchEvent(new HashChangeEvent('hashchange'));
  }, VENUE_ID);
  await page.waitForTimeout(9000);
  const fin = await page.evaluate(() => ({
    hash: location.hash,
    text: document.body.innerText.replace(/\s+/g, ' ').slice(0, 250),
  }));
  console.log('DETAIL:', JSON.stringify(fin));

  await page.screenshot({ path: '/tmp/probe2.png', fullPage: true });
  await browser.close();
})();
