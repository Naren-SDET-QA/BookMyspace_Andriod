// Full Owner E2E for fresh booking BMS-553715B3
// Uses proven Playwright+CDP approach with correct semantic mapping.

const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const APP_URL = 'http://127.0.0.1:8099';
const OWNER_EMAIL = process.env.DEV_E2E_OWNER_EMAIL;
const OWNER_PASSWORD = process.env.DEV_E2E_OWNER_PASSWORD;
const CUSTOMER_EMAIL = process.env.DEV_E2E_CUSTOMER_EMAIL;
const CUSTOMER_PASSWORD = process.env.DEV_E2E_CUSTOMER_PASSWORD;
const BOOKING_REF = 'BMS-553715B3';
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', `2026-09-18_${BOOKING_REF}`);
const TIMEOUT = 180_000;

(async () => {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const logs = [];
  function log(msg) { console.log(msg); logs.push(msg); }

  const browser = await chromium.launch({
    headless: false, channel: 'chrome',
    args: ['--no-sandbox', '--disable-web-security', '--enable-features=AccessibilityObjectModel'],
    timeout: TIMEOUT,
  });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  page.setDefaultTimeout(30000);
  page.on('console', msg => logs.push(`[browser] ${msg.text()}`));

  async function snap(n, label) {
    const f = path.join(EVIDENCE_DIR, `${n}.png`);
    await page.screenshot({ path: f, fullPage: true });
    log(`  📸 [${label||n}] ${fs.statSync(f).size} bytes`);
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
    await page.evaluate(() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) p.dispatchEvent(new MouseEvent('click',{bubbles:true}));
    });
    await wait(5);
  }
  async function getSems() {
    return await page.$$eval('flt-semantics', els => els.map(el => {
      const r = el.getBoundingClientRect();
      return { label: el.getAttribute('aria-label')||'', role: el.getAttribute('role')||'',
        rect:{x:r.x,y:r.y,w:r.width,h:r.height}, id:el.id };
    })) || [];
  }
  async function getTexts() {
    return await page.evaluate(() => {
      const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
      const t = [];
      while(w.nextNode()) { const s = w.currentNode.textContent.trim(); if(s && s.length>1) t.push(s); }
      return t;
    });
  }

  // Login helper (semantic [13]=email, [14]=password, [15]=submit)
  async function login(email, password, tag) {
    log(`\n  [${tag}] Login...`);
    await page.evaluate(() => { try{localStorage.clear();}catch{} });
    await page.goto(APP_URL, {waitUntil:'networkidle', timeout:TIMEOUT});
    await wait(8);
    await enableA11y(); await wait(3);
    const sems = await getSems();
    if (sems.length < 16) { log(`  ❌ Only ${sems.length} semantics`); return false; }
    await cdpClick(sems[13].rect.x+sems[13].rect.w/2, sems[13].rect.y+sems[13].rect.h/2);
    await wait(2);
    const ei = await page.$('input[type="text"]:not([type="hidden"])');
    if (ei) await ei.evaluate((el,v)=>{el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}, email);
    await wait(2);
    await cdpClick(sems[14].rect.x+sems[14].rect.w/2, sems[14].rect.y+sems[14].rect.h/2);
    await wait(2);
    await cdpInsert(password);
    await wait(2);
    await cdpClick(sems[15].rect.x+sems[15].rect.w/2, sems[15].rect.y+sems[15].rect.h/2);
    await wait(15);
    const ok = !page.url().includes('login');
    log(`  ${ok ? '✅' : '❌'} URL: ${page.url().substring(0,80)}`);
    return ok;
  }

  try {
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Owner Login
    // ═══════════════════════════════════════════════════════════════
    log(`\n[STEP 1] Owner Login — ${OWNER_EMAIL}`);
    const loginOk = await login(OWNER_EMAIL, OWNER_PASSWORD, 'owner');
    if (!loginOk) { log('❌ Owner login failed'); await browser.close(); process.exit(1); }
    await snap('01_owner_home', 'Owner home');

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Owner Bookings — verify BMS-553715B3 visible
    // ═══════════════════════════════════════════════════════════════
    log('\n[STEP 2] Owner Bookings...');
    await page.goto(`${APP_URL}/#/owner/bookings`, {waitUntil:'networkidle', timeout:TIMEOUT});
    await wait(12);
    await enableA11y(); await wait(3);
    await snap('02_owner_bookings', 'Owner bookings');

    const texts = await getTexts();
    const refText = texts.find(t => t.includes(BOOKING_REF));
    if (refText) {
      log(`  ✅ Found: ${refText.substring(0, 200)}`);
      const hasAwaiting = texts.some(t => t.includes('awaiting_owner_approval'));
      log(`  Status awaiting_owner_approval: ${hasAwaiting ? '✅' : '❌'}`);
    } else {
      log(`  ❌ ${BOOKING_REF} NOT FOUND in text`);
      log('  Relevant texts:');
      texts.filter(t => /BMS|approval|pending|awaiting|dev data/i.test(t)).forEach(t => log(`    "${t.substring(0,150)}"`));
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Accept & request payment
    // ═══════════════════════════════════════════════════════════════
    log('\n[STEP 3] Accept & request payment...');
    const sems = await getSems();
    
    // Print ALL semantics for debugging
    log(`  All ${sems.length} semantics:`);
    sems.forEach((s,i) => {
      const cx = s.rect.x+s.rect.w/2, cy = s.rect.y+s.rect.h/2;
      log(`    [${i}] role="${s.role}" label="${s.label}" @(${cx.toFixed(0)},${cy.toFixed(0)}) ${s.rect.w.toFixed(0)}x${s.rect.h.toFixed(0)}`);
    });
    
    // Try labeled accept button first
    let acceptNode = sems.find(s => /accept/i.test(s.label));
    if (!acceptNode) {
      // The accept button might not have a label. Look for buttons near the booking tile.
      // The booking tile text was found at a [group] node. Find all unlabeled buttons.
      const unlabeledButtons = sems.filter(s => s.role === 'button' && !s.label);
      log(`  Unlabeled buttons: ${unlabeledButtons.length}`);
      
      // The accept button is typically at the bottom of a booking tile.
      // Find the booking tile group and look for buttons below it.
      const groupNode = sems.find(s => /awaiting/i.test(s.label));
      if (groupNode) {
        log(`  Booking tile at y=${groupNode.rect.y.toFixed(0)}, h=${groupNode.rect.h.toFixed(0)}`);
        // Accept button should be below or inside the tile
        const tileBottom = groupNode.rect.y + groupNode.rect.h;
        // Look for unlabeled buttons near the tile bottom
        const nearButtons = unlabeledButtons.filter(b => 
          Math.abs(b.rect.y + b.rect.h/2 - tileBottom) < 60 ||
          (b.rect.y >= groupNode.rect.y && b.rect.y <= tileBottom + 40)
        );
        log(`  Buttons near tile: ${nearButtons.length}`);
        if (nearButtons.length > 0) acceptNode = nearButtons[nearButtons.length - 1];
      }
      
      if (!acceptNode && unlabeledButtons.length > 0) {
        // Last resort: try the last unlabeled button (likely the accept)
        acceptNode = unlabeledButtons[unlabeledButtons.length - 1];
        log(`  Using last unlabeled button as fallback`);
      }
    }
    
    if (acceptNode) {
      const ax = acceptNode.rect.x+acceptNode.rect.w/2;
      const ay = acceptNode.rect.y+acceptNode.rect.h/2;
      log(`  Clicking accept at (${ax.toFixed(0)}, ${ay.toFixed(0)}) role=${acceptNode.role} label="${acceptNode.label}"`);
      await cdpClick(ax, ay);
      await wait(5);
      await snap('03_accept_clicked', 'Accept clicked');

      // Check for confirmation dialog
      const dialogSems = await getSems();
      log(`  Post-click semantics: ${dialogSems.length}`);
      const confirmBtn = dialogSems.find(s => /confirm/i.test(s.label));
      if (confirmBtn) {
        log(`  Confirm: "${confirmBtn.label}"`);
        await cdpClick(confirmBtn.rect.x+confirmBtn.rect.w/2, confirmBtn.rect.y+confirmBtn.rect.h/2);
        await wait(5);
      } else {
        // Check if a dialog appeared with unlabeled buttons
        const dialogBtns = dialogSems.filter(s => s.role === 'button' && s.rect.w > 50);
        log(`  Dialog buttons: ${dialogBtns.length}`);
        if (dialogBtns.length > 0) {
          // Click the last/largest button (likely confirm)
          const confirm = dialogBtns[dialogBtns.length - 1];
          log(`  Clicking dialog button at (${(confirm.rect.x+confirm.rect.w/2).toFixed(0)}, ${(confirm.rect.y+confirm.rect.h/2).toFixed(0)})`);
          await cdpClick(confirm.rect.x+confirm.rect.w/2, confirm.rect.y+confirm.rect.h/2);
          await wait(5);
        }
      }
    } else {
      log('  ❌ Accept button NOT FOUND');
    }
    await snap('04_after_approve', 'After approval');

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Verify status transition
    // ═══════════════════════════════════════════════════════════════
    log('\n[STEP 4] Verify status...');
    await page.goto(`${APP_URL}/#/owner/bookings`, {waitUntil:'networkidle', timeout:TIMEOUT});
    await wait(10);
    await enableA11y(); await wait(3);
    await snap('05_status_check', 'Status check');

    const postTexts = await getTexts();
    const refPost = postTexts.find(t => t.includes(BOOKING_REF));
    if (refPost) {
      log(`  Booking: ${refPost.substring(0, 200)}`);
      const hasPending = postTexts.some(t => /pending/i.test(t) && !t.includes('awaiting'));
      log(`  Status pending: ${hasPending ? '✅' : '❌'}`);
      const hasAcceptGone = !postTexts.some(t => t.includes('Accept & request payment'));
      log(`  Accept button gone: ${hasAcceptGone ? '✅' : '❌'}`);
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Customer Login
    // ═══════════════════════════════════════════════════════════════
    log('\n[STEP 5] Customer Login...');
    const custOk = await login(CUSTOMER_EMAIL, CUSTOMER_PASSWORD, 'customer');
    if (!custOk) { log('❌ Customer login failed'); await browser.close(); process.exit(1); }
    await snap('06_cust_home', 'Customer home');

    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Customer Bookings — verify Pay action
    // ═══════════════════════════════════════════════════════════════
    log('\n[STEP 6] Customer bookings — Pay...');
    await page.goto(`${APP_URL}/#/bookings`, {waitUntil:'networkidle', timeout:TIMEOUT});
    await wait(12);
    await enableA11y(); await wait(3);
    await snap('07_cust_bookings', 'Customer bookings');

    const custTexts = await getTexts();
    const custRef = custTexts.find(t => t.includes(BOOKING_REF));
    if (custRef) {
      log(`  ✅ Booking visible: ${custRef.substring(0, 200)}`);
    } else {
      log(`  ❌ ${BOOKING_REF} not in customer bookings`);
    }

    // Look for Pay button/text
    const payVisible = custTexts.some(t => /pay securely|pay now|pay ₹/i.test(t));
    log(`  Pay action: ${payVisible ? '✅' : '❌'}`);

    // Print all relevant texts
    log('\n  Relevant customer texts:');
    custTexts.filter(t => /BMS|pay|pending|dev data|hall/i.test(t)).forEach(t => log(`    "${t.substring(0,150)}"`));

    // ═══════════════════════════════════════════════════════════════
    // SAVE
    // ═══════════════════════════════════════════════════════════════
    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), logs.join('\n'));
    log(`\n✅ Evidence: ${EVIDENCE_DIR}/`);

  } catch (err) {
    log(`\n❌ FATAL: ${err.message}`);
    await snap('ERROR', 'Error');
    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), logs.join('\n'));
  } finally {
    await browser.close();
    log('[DONE]');
  }
})();
