// Diagnostic: Check what's visible on owner bookings screen
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');
const APP_URL = 'http://127.0.0.1:8099';
const OWNER_EMAIL = process.env.DEV_E2E_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.DEV_E2E_OWNER_PASSWORD;
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', '2026-09-18_BMS-6A4A9F60');

(async () => {
  const browser = await chromium.launch({
    headless: false, channel: 'chrome',
    args: ['--no-sandbox', '--disable-web-security', '--enable-features=AccessibilityObjectModel'],
    timeout: 180000,
  });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  page.setDefaultTimeout(30000);
  const logs = [];
  page.on('console', msg => logs.push(`[${msg.type()}] ${msg.text()}`));

  async function snap(n) {
    const f = path.join(EVIDENCE_DIR, `${n}.png`);
    await page.screenshot({ path: f, fullPage: true });
    console.log(`📸 ${n} ${fs.statSync(f).size} bytes`);
  }
  async function wait(s=5) { await page.waitForTimeout(s*1000); }
  async function cdpClick(x,y) {
    const c = await ctx.newCDPSession(page);
    await c.send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});
    await c.send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});
    await c.detach(); await wait(1);
  }
  async function cdpInsert(t) {
    const c = await ctx.newCDPSession(page);
    await c.send('Input.insertText',{text:t});
    await c.detach(); await wait(0.5);
  }
  async function enableA11y() {
    await page.evaluate(() => { const p = document.querySelector('flt-semantics-placeholder'); if(p) p.dispatchEvent(new MouseEvent('click',{bubbles:true})); });
    await wait(5);
  }
  async function getAllSems() {
    return await page.$$eval('flt-semantics', els => els.map(el => {
      const r = el.getBoundingClientRect();
      return { label: el.getAttribute('aria-label')||'', role: el.getAttribute('role')||'', rect:{x:r.x,y:r.y,w:r.width,h:r.height}, id:el.id };
    })) || [];
  }

  // Login as owner
  await page.goto(APP_URL, {waitUntil:'networkidle', timeout:180000});
  await wait(3);
  await page.evaluate(() => { try{localStorage.clear();}catch{} });
  await page.goto(APP_URL, {waitUntil:'networkidle', timeout:180000});
  await wait(8);
  await enableA11y(); await wait(3);

  // Email
  const sems = await getAllSems();
  await cdpClick(sems[13].rect.x+sems[13].rect.w/2, sems[13].rect.y+sems[13].rect.h/2);
  await wait(2);
  const ei = await page.$('input[type="text"]:not([type="hidden"])');
  if(ei) await ei.evaluate((el,v)=>{el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}, OWNER_EMAIL);
  await wait(2);

  // Password
  await cdpClick(sems[14].rect.x+sems[14].rect.w/2, sems[14].rect.y+sems[14].rect.h/2);
  await wait(2);
  await cdpInsert(OWNER_PASSWORD);
  await wait(2);

  // Submit
  await cdpClick(sems[15].rect.x+sems[15].rect.w/2, sems[15].rect.y+sems[15].rect.h/2);
  await wait(15);
  console.log(`URL after login: ${page.url()}`);

  // Navigate to owner bookings
  await page.goto(`${APP_URL}/#/owner/bookings`, {waitUntil:'networkidle', timeout:180000});
  await wait(12);
  await enableA11y(); await wait(3);
  await snap('diag_owner_bookings');

  // Get ALL semantics
  const allSems = await getAllSems();
  console.log(`\nAll semantics (${allSems.length}):`);
  allSems.forEach((s,i) => {
    const cx = s.rect.x + s.rect.w/2;
    const cy = s.rect.y + s.rect.h/2;
    console.log(`  [${i}] role="${s.role}" label="${s.label}" id="${s.id}" @(${cx.toFixed(0)},${cy.toFixed(0)}) ${s.rect.w.toFixed(0)}x${s.rect.h.toFixed(0)}`);
  });

  // Check for any BMS references in the page
  const textContent = await page.evaluate(() => {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    const texts = [];
    while(walker.nextNode()) {
      const t = walker.currentNode.textContent.trim();
      if(t && t.length > 0) texts.push(t);
    }
    return texts;
  });
  console.log(`\nAll text in DOM (${textContent.length}):`);
  textContent.forEach(t => console.log(`  "${t}"`));

  // Check if there's a "No bookings" empty state or loading indicator
  const bodyHTML = await page.evaluate(() => document.body.innerHTML.substring(0, 5000));
  console.log(`\nBody HTML (first 3000):`);
  console.log(bodyHTML.substring(0, 3000));

  fs.writeFileSync(path.join(EVIDENCE_DIR, 'diag_console.log'), logs.join('\n'));
  await browser.close();
  console.log('[DONE]');
})();
