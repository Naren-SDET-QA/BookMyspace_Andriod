// Owner E2E for BMS-6A4A9F60 — v7 (correct semantic mapping)
// Login form layout (from source code analysis):
//   [8]  Google Sign-In button  (234,364)
//   [9]  Apple Sign-In button   (234,428)
//   [10] "OR" divider           (234,484)
//   [11] Email tab              (129,534)
//   [12] Phone tab              (339,534)
//   [13] Email TextFormField    (234,598)  ← THIS is the email field
//   [14] Password TextFormField (234,666)  ← THIS is the password field
//   [15] Submit FilledButton    (234,744)  ← THIS is the submit button

const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const APP_URL = 'http://127.0.0.1:8099';
const OWNER_EMAIL = process.env.DEV_E2E_OWNER_EMAIL || 'owner.dev@bookmyspace.app';
const OWNER_PASSWORD = process.env.DEV_E2E_OWNER_PASSWORD || '';
const CUSTOMER_EMAIL = process.env.DEV_E2E_CUSTOMER_EMAIL || 'customer.dev@bookmyspace.app';
const CUSTOMER_PASSWORD = process.env.DEV_E2E_CUSTOMER_PASSWORD || '';
const BOOKING_REF = 'BMS-6A4A9F60';
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', `2026-09-18_${BOOKING_REF}`);
const TIMEOUT = 180_000;

(async () => {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  console.log(`[SETUP] Evidence: ${EVIDENCE_DIR}`);

  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: ['--no-sandbox', '--disable-web-security', '--enable-features=AccessibilityObjectModel'],
    timeout: TIMEOUT,
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
  const page = await context.newPage();
  page.setDefaultTimeout(30_000);

  const consoleLogs = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));

  async function snap(name, label) {
    const file = path.join(EVIDENCE_DIR, `${name}.png`);
    await page.screenshot({ path: file, fullPage: true });
    console.log(`  📸 [${label || name}] ${fs.statSync(file).size} bytes`);
  }
  async function wait(s = 5) { await page.waitForTimeout(s * 1000); }

  async function cdpClick(x, y) {
    const cdp = await context.newCDPSession(page);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
    await cdp.detach();
    await wait(1);
  }

  async function cdpInsertText(text) {
    const cdp = await context.newCDPSession(page);
    await cdp.send('Input.insertText', { text });
    await cdp.detach();
    await wait(0.5);
  }

  async function enableA11y() {
    await page.evaluate(() => {
      const ph = document.querySelector('flt-semantics-placeholder');
      if (ph) ph.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await wait(5);
  }

  async function getAllSemantics() {
    return await page.$$eval('flt-semantics', (els) =>
      els.map(el => {
        const r = el.getBoundingClientRect();
        return {
          label: el.getAttribute('aria-label') || '',
          role: el.getAttribute('role') || '',
          rect: { x: r.x, y: r.y, w: r.width, h: r.height },
          id: el.id,
        };
      })
    ) || [];
  }

  // Login with correct semantic mapping
  async function loginAs(email, password, tag) {
    console.log(`\n  [${tag}] Login as ${email}`);
    await page.evaluate(() => { try { localStorage.clear(); } catch {} });
    await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(8);
    await enableA11y();
    await wait(3);

    const sems = await getAllSemantics();
    console.log(`  Semantics: ${sems.length}`);
    sems.forEach((s, i) => {
      const cx = s.rect.x + s.rect.w/2;
      const cy = s.rect.y + s.rect.h/2;
      console.log(`    [${i}] role="${s.role}" @(${cx.toFixed(0)},${cy.toFixed(0)}) ${s.rect.w.toFixed(0)}x${s.rect.h.toFixed(0)}`);
    });

    // CORRECT mapping: [13]=email, [14]=password, [15]=submit
    // But verify by checking we have at least 16 nodes
    if (sems.length < 16) {
      console.log(`  ❌ Expected 16+ semantics, got ${sems.length}`);
      return false;
    }

    // Click EMAIL field at semantic [13] (234, 598)
    const emailCenter = { x: sems[13].rect.x + sems[13].rect.w/2, y: sems[13].rect.y + sems[13].rect.h/2 };
    console.log(`  Clicking EMAIL field [13] at (${emailCenter.x.toFixed(0)}, ${emailCenter.y.toFixed(0)})`);
    await cdpClick(emailCenter.x, emailCenter.y);
    await wait(2);

    // Type email via the hidden input that Flutter creates
    const emailInput = await page.$('input[type="text"]:not([type="hidden"])');
    if (emailInput) {
      console.log('  ✅ Email input found, filling...');
      // Use evaluate to set value and dispatch input event
      await emailInput.evaluate((el, val) => {
        el.value = val;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      }, email);
    } else {
      console.log('  No hidden input, using CDP...');
      await cdpInsertText(email);
    }
    await wait(2);
    await snap(`${tag}_01_email`, 'Email typed');

    // Click PASSWORD field at semantic [14] (234, 666)
    const pwdCenter = { x: sems[14].rect.x + sems[14].rect.w/2, y: sems[14].rect.y + sems[14].rect.h/2 };
    console.log(`  Clicking PASSWORD field [14] at (${pwdCenter.x.toFixed(0)}, ${pwdCenter.y.toFixed(0)})`);
    await cdpClick(pwdCenter.x, pwdCenter.y);
    await wait(2);

    // Type password via CDP (hidden input is 0×0, can't use fill())
    console.log('  Typing password via CDP...');
    await cdpInsertText(password);
    await wait(2);
    await snap(`${tag}_02_pwd`, 'Password typed');

    // Click SUBMIT button at semantic [15] (234, 744)
    const subCenter = { x: sems[15].rect.x + sems[15].rect.w/2, y: sems[15].rect.y + sems[15].rect.h/2 };
    console.log(`  Clicking SUBMIT [15] at (${subCenter.x.toFixed(0)}, ${subCenter.y.toFixed(0)})`);
    await cdpClick(subCenter.x, subCenter.y);
    await wait(15);
    await snap(`${tag}_03_submit`, 'After submit');

    const url = page.url();
    console.log(`  URL: ${url.substring(0, 120)}`);

    if (url.includes('accounts.google')) {
      console.log('  ❌ Google OAuth triggered — still wrong position!');
      return false;
    }
    if (url.includes('login')) {
      console.log('  ⚠️  Still on login');
      return false;
    }
    console.log('  ✅ Login successful!');
    return true;
  }

  try {
    // ═══════════════════════════════════════════════════════════════
    // STEP 0: Load
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 0] Load app');
    await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(3);
    await snap('00_landing', 'Landing');

    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Owner Login
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 1] Owner Login');
    let loginOk = await loginAs(OWNER_EMAIL, OWNER_PASSWORD, 'owner');

    if (!loginOk) {
      // Fallback: use Enter key on password field instead of clicking submit
      console.log('\n  Fallback: Enter key on password field...');
      await page.evaluate(() => { try { localStorage.clear(); } catch {} });
      await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
      await wait(8);
      await enableA11y();
      await wait(3);

      const sems = await getAllSemantics();
      if (sems.length >= 16) {
        // Click email
        await cdpClick(sems[13].rect.x + sems[13].rect.w/2, sems[13].rect.y + sems[13].rect.h/2);
        await wait(2);
        await cdpInsertText(OWNER_EMAIL);
        await wait(2);

        // Click password
        await cdpClick(sems[14].rect.x + sems[14].rect.w/2, sems[14].rect.y + sems[14].rect.h/2);
        await wait(2);
        await cdpInsertText(OWNER_PASSWORD);
        await wait(2);

        // Press Enter on password field (triggers onFieldSubmitted → _signInWithPassword)
        console.log('  Pressing Enter on password field...');
        const cdp = await context.newCDPSession(page);
        await cdp.send('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: 13, key: 'Enter', code: 'Enter' });
        await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: 13, key: 'Enter', code: 'Enter' });
        await cdp.detach();
        await wait(15);

        const url = page.url();
        console.log(`  URL after Enter: ${url.substring(0, 120)}`);
        if (!url.includes('login') && !url.includes('google')) {
          loginOk = true;
          console.log('  ✅ Login succeeded via Enter!');
        }
      }
    }

    if (!loginOk) {
      console.log('\n❌ LOGIN BLOCKED');
      fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), consoleLogs.join('\n'));
      await snap('BLOCKED', 'Login blocked');
      await browser.close();
      process.exit(1);
    }

    await snap('01_owner_home', 'Owner home');

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Owner Bookings
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 2] Owner Bookings');
    await page.goto(`${APP_URL}/#/owner/bookings`, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(10);
    await enableA11y();
    await wait(3);
    await snap('02_owner_bookings', 'Owner bookings');

    const ownerSems = await getAllSemantics();
    const refNode = ownerSems.find(s => s.label.includes(BOOKING_REF));
    console.log(`  Booking ${BOOKING_REF}: ${refNode ? '✅ FOUND' : '❌ NOT FOUND'}`);
    ownerSems.filter(s => s.label).forEach(s => console.log(`    "${s.label}" [${s.role}] @(${s.rect.x.toFixed(0)},${s.rect.y.toFixed(0)})`));

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Accept & request payment
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 3] Accept & request payment');
    const acceptNode = ownerSems.find(s => /accept/i.test(s.label));
    if (acceptNode) {
      console.log(`  Found: "${acceptNode.label}" @(${acceptNode.rect.x.toFixed(0)},${acceptNode.rect.y.toFixed(0)})`);
      await cdpClick(acceptNode.rect.x + acceptNode.rect.w/2, acceptNode.rect.y + acceptNode.rect.h/2);
      await wait(5);
      await snap('03_accept_clicked', 'Accept clicked');

      const dialogSems = await getAllSemantics();
      const confirmBtn = dialogSems.find(s => /confirm/i.test(s.label));
      if (confirmBtn) {
        console.log(`  Confirm: "${confirmBtn.label}"`);
        await cdpClick(confirmBtn.rect.x + confirmBtn.rect.w/2, confirmBtn.rect.y + confirmBtn.rect.h/2);
        await wait(5);
      }
    } else {
      console.log('  ❌ Accept not found');
      ownerSems.filter(s => s.label).forEach(s => console.log(`    "${s.label}"`));
    }
    await snap('04_after_approve', 'After approval');

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Verify status
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 4] Verify status');
    await wait(3);
    await snap('05_status', 'Status');
    const statusSems = await getAllSemantics();
    const pendingNode = statusSems.find(s => /pending/i.test(s.label));
    console.log(`  Status: ${pendingNode ? pendingNode.label : 'unknown'}`);
    statusSems.filter(s => s.label).forEach(s => console.log(`    "${s.label}" [${s.role}]`));

    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Customer login + bookings
    // ═══════════════════════════════════════════════════════════════
    console.log('\n[STEP 5] Customer login');
    const custOk = await loginAs(CUSTOMER_EMAIL, CUSTOMER_PASSWORD, 'customer');
    if (custOk) {
      await snap('06_cust_home', 'Customer home');

      console.log('\n[STEP 6] Customer bookings — Pay');
      await page.goto(`${APP_URL}/#/bookings`, { waitUntil: 'networkidle', timeout: TIMEOUT });
      await wait(10);
      await enableA11y();
      await wait(3);
      await snap('07_cust_bookings', 'Customer bookings');

      const custSems = await getAllSemantics();
      const payNode = custSems.find(s => /pay/i.test(s.label));
      console.log(`  Pay: ${payNode ? `✅ "${payNode.label}"` : '❌ NOT FOUND'}`);
      custSems.filter(s => s.label).forEach(s => console.log(`    "${s.label}" [${s.role}]`));
    }

    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), consoleLogs.join('\n'));
    console.log(`\n✅ Evidence: ${EVIDENCE_DIR}/`);

  } catch (err) {
    console.error(`\n❌ FATAL: ${err.message}`);
    await snap('ERROR', 'Error');
    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), consoleLogs.join('\n'));
  } finally {
    await browser.close();
    console.log('[DONE]');
  }
})();
