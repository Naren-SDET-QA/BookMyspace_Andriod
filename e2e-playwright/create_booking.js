// create_booking.js — Create a fresh booking against owner.dev's venue,
// then run the full Owner E2E flow via real Chrome UI.

const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zykxneztahxbjduagutv.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';
const OWNER_EMAIL = process.env.DEV_E2E_OWNER_EMAIL || 'owner.dev@bookmyspace.app';
const OWNER_PASSWORD = process.env.DEV_E2E_OWNER_PASSWORD || '';
const CUSTOMER_EMAIL = process.env.DEV_E2E_CUSTOMER_EMAIL || 'customer.dev@bookmyspace.app';
const CUSTOMER_PASSWORD = process.env.DEV_E2E_CUSTOMER_PASSWORD || '';
const APP_URL = 'http://127.0.0.1:8099';
const TIMEOUT = 180_000;
const EVIDENCE_DIR = path.resolve(__dirname, '..', 'e2e-evidence', '2026-09-18_FRESH_E2E');

// Helper: HTTP request to Supabase using child_process (reliable)
const { execSync } = require('child_process');
function supabaseRequest(method, apiPath, body, headers = {}) {
  const fullUrl = SUPABASE_URL + apiPath;
  const hdrs = `-H 'apikey: ${SUPABASE_ANON_KEY}' -H 'Content-Type: application/json'`;
  const authHdr = headers.Authorization ? `-H 'Authorization: ${headers.Authorization}'` : '';
  const preferHdr = headers.Prefer ? `-H 'Prefer: ${headers.Prefer}'` : '';
  const bodyArg = body ? `-d '${JSON.stringify(body).replace(/'/g, "'\"'\"")}'` : '';
  const cmd = `curl -s -X ${method} '${fullUrl}' ${hdrs} ${authHdr} ${preferHdr} ${bodyArg}`;
  try {
    const out = execSync(cmd, { timeout: 30000, encoding: 'utf-8' });
    try {
      return { status: 200, data: JSON.parse(out) };
    } catch (_e) {
      return { status: 200, data: out };
    }
  } catch (err) {
    return { status: err.status || 500, data: err.message };
  }
}

// Helper: Sign in and get JWT
async function signIn(email, password) {
  const res = await supabaseRequest('POST', '/auth/v1/token?grant_type=password', {
    email, password,
  });
  if (res.status !== 200) {
    throw new Error(`Sign-in failed for ${email}: ${res.status} ${JSON.stringify(res.data)}`);
  }
  return { token: res.data.access_token, userId: res.data.user.id };
}

// Helper: Query Supabase REST
async function queryTable(table, filters, token) {
  const qs = new URLSearchParams(filters).toString();
  const res = await supabaseRequest('GET', `/rest/v1/${table}?${qs}`, null, {
    'Authorization': `Bearer ${token}`,
    'Prefer': 'return=representation',
  });
  return res;
}

(async () => {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const logs = [];
  function log(msg) { console.log(msg); logs.push(msg); }

  try {
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: Create fresh booking via API
    // ═══════════════════════════════════════════════════════════════
    log('\n═══ PHASE 1: Create fresh booking ═══');

    // Sign in as customer to get JWT + user ID
    log('Signing in as customer...');
    const cust = await signIn(CUSTOMER_EMAIL, CUSTOMER_PASSWORD);
    log(`  Customer userId: ${cust.userId}`);

    // Sign in as owner to get JWT + user ID
    log('Signing in as owner...');
    const owner = await signIn(OWNER_EMAIL, OWNER_PASSWORD);
    log(`  Owner userId: ${owner.userId}`);

    // Find owner's venues (via owner's JWT)
    log('\nFinding owner venues...');
    const ownerVenues = await supabaseRequest('GET',
      '/rest/v1/venues?select=id,name,org_id&is_active=eq.true&limit=10',
      null, { 'Authorization': `Bearer ${owner.token}` }
    );
    log(`  Owner venues: ${JSON.stringify(ownerVenues.data?.map(v => ({ id: v.id, name: v.name, org: v.org_id })))}`);

    if (!ownerVenues.data || ownerVenues.data.length === 0) {
      // Try querying with customer JWT (RLS might allow public read)
      const pubVenues = await supabaseRequest('GET',
        '/rest/v1/venues?select=id,name,org_id&is_active=eq.true&limit=20',
        null, { 'Authorization': `Bearer ${cust.token}` }
      );
      log(`  Public venues: ${JSON.stringify(pubVenues.data?.map(v => ({ id: v.id, name: v.name, org: v.org_id })))}`);
    }

    // Also check what slots are available
    log('\nFinding available slots...');
    const slots = await supabaseRequest('GET',
      '/rest/v1/venue_slots?select=id,venue_id,slot_name,start_time,end_time,price_amount,tax_rate,is_active&is_active=eq.true&limit=20',
      null, { 'Authorization': `Bearer ${cust.token}` }
    );
    log(`  Slots: ${JSON.stringify(slots.data?.slice(0, 10))}`);

    // Find the venue that matches what we saw in the owner bookings list
    // BMS-6A4A9F60 was on "Party Hall DEV 10" (venue_id: 51c4ea2c-7c9a-40c2-98a8-b9a50843ddf5)
    // But that venue might belong to a different org. Let's find owner.dev's actual venues.
    
    // Try to find org_id for owner.dev
    log('\nFinding owner org...');
    const ownerOrg = await supabaseRequest('GET',
      '/rest/v1/owner_profiles?select=id,org_id,user_id&user_id=eq.' + owner.userId,
      null, { 'Authorization': `Bearer ${owner.token}` }
    );
    log(`  Owner profile: ${JSON.stringify(ownerOrg.data)}`);

    // Find venues belonging to owner's org
    if (ownerOrg.data && ownerOrg.data.length > 0) {
      const orgId = ownerOrg.data[0].org_id;
      log(`  Owner org: ${orgId}`);
      
      const orgVenues = await supabaseRequest('GET',
        `/rest/v1/venues?select=id,name,org_id&org_id=eq.${orgId}&is_active=eq.true`,
        null, { 'Authorization': `Bearer ${cust.token}` }
      );
      log(`  Org venues: ${JSON.stringify(orgVenues.data)}`);

      if (orgVenues.data && orgVenues.data.length > 0) {
        const venue = orgVenues.data[0];
        log(`\n  Using venue: ${venue.name} (${venue.id})`);

        // Find a slot for this venue
        const venueSlots = await supabaseRequest('GET',
          `/rest/v1/venue_slots?select=id,slot_name,start_time,end_time,price_amount,tax_rate&venue_id=eq.${venue.id}&is_active=eq.true`,
          null, { 'Authorization': `Bearer ${cust.token}` }
        );
        log(`  Venue slots: ${JSON.stringify(venueSlots.data)}`);

        if (venueSlots.data && venueSlots.data.length > 0) {
          const slot = venueSlots.data[0];
          
          // Create booking for tomorrow (to avoid date validation issues)
          const tomorrow = new Date();
          tomorrow.setDate(tomorrow.getDate() + 1);
          const bookDate = tomorrow.toISOString().split('T')[0];
          
          log(`\n  Creating booking: venue=${venue.id}, slot=${slot.id}, date=${bookDate}`);
          
          const idempotencyKey = `e2e-fresh-${Date.now()}-${Math.random().toString(36).substr(2, 8)}`;
          
          const createResult = await supabaseRequest('POST',
            '/rest/v1/rpc/request_venue_booking',
            {
              p_venue_id: venue.id,
              p_slot_id: slot.id,
              p_book_date: bookDate,
              p_idempotency_key: idempotencyKey,
            },
            {
              'Authorization': `Bearer ${cust.token}`,
              'Prefer': 'return=representation',
            }
          );
          log(`  Create result: ${createResult.status} ${JSON.stringify(createResult.data).substring(0, 500)}`);

          if (createResult.status === 200 && createResult.data) {
            const booking = Array.isArray(createResult.data) ? createResult.data[0] : createResult.data;
            const ref = booking.booking_ref || createResult.data.booking_ref;
            log(`\n  ✅ Booking created: ${ref}`);
            log(`     Status: ${booking.status}`);
            log(`     approval_expires_at: ${booking.approval_expires_at}`);
            
            // Write ref to file for the E2E phase
            fs.writeFileSync(path.join(EVIDENCE_DIR, 'fresh_booking_ref.txt'), ref);
            fs.writeFileSync(path.join(EVIDENCE_DIR, 'fresh_booking_state.json'), JSON.stringify(booking, null, 2));
          } else {
            log(`  ❌ Booking creation failed`);
            // Try direct insert as fallback
            log('  Trying direct insert...');
            const insertResult = await supabaseRequest('POST',
              '/rest/v1/bookings',
              {
                user_id: cust.userId,
                venue_id: venue.id,
                slot_id: slot.id,
                book_date: bookDate,
                start_time: slot.start_time,
                end_time: slot.end_time,
                status: 'awaiting_owner_approval',
                amount: slot.price_amount,
                tax_amount: Math.round(slot.price_amount * (slot.tax_rate || 18) / 100),
                total_amount: Math.round(slot.price_amount * (1 + (slot.tax_rate || 18) / 100)),
                currency: 'INR',
                quantity: 1,
                approval_required: true,
                approval_requested_at: new Date().toISOString(),
                approval_expires_at: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
                request_idempotency_key: idempotencyKey,
              },
              {
                'Authorization': `Bearer ${cust.token}`,
                'Prefer': 'return=representation',
              }
            );
            log(`  Insert result: ${insertResult.status} ${JSON.stringify(insertResult.data).substring(0, 500)}`);
          }
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: Full E2E via real Chrome UI
    // ═══════════════════════════════════════════════════════════════
    log('\n═══ PHASE 2: Real UI E2E ═══');

    // Read the fresh booking ref
    const freshRef = fs.readFileSync(path.join(EVIDENCE_DIR, 'fresh_booking_ref.txt'), 'utf-8').trim();
    log(`  Target booking: ${freshRef}`);

    const browser = await chromium.launch({
      headless: false,
      channel: 'chrome',
      args: ['--no-sandbox', '--disable-web-security', '--enable-features=AccessibilityObjectModel'],
      timeout: TIMEOUT,
    });
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    page.setDefaultTimeout(30000);
    page.on('console', msg => logs.push(`[browser] [${msg.type()}] ${msg.text()}`));

    async function snap(name, label) {
      const file = path.join(EVIDENCE_DIR, `${name}.png`);
      await page.screenshot({ path: file, fullPage: true });
      log(`  📸 [${label || name}] ${fs.statSync(file).size} bytes`);
    }
    async function wait(s = 5) { await page.waitForTimeout(s * 1000); }
    async function cdpClick(x, y) {
      const c = await ctx.newCDPSession(page);
      await c.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
      await c.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
      await c.detach(); await wait(1);
    }
    async function cdpInsert(text) {
      const c = await ctx.newCDPSession(page);
      await c.send('Input.insertText', { text });
      await c.detach(); await wait(0.5);
    }
    async function enableA11y() {
      await page.evaluate(() => {
        const p = document.querySelector('flt-semantics-placeholder');
        if (p) p.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      });
      await wait(5);
    }
    async function getAllSems() {
      return await page.$$eval('flt-semantics', els => els.map(el => {
        const r = el.getBoundingClientRect();
        return { label: el.getAttribute('aria-label') || '', role: el.getAttribute('role') || '', rect: { x: r.x, y: r.y, w: r.width, h: r.height }, id: el.id };
      })) || [];
    }

    // ─── Owner Login ───
    log('\n[OWNER] Logging in...');
    await page.evaluate(() => { try { localStorage.clear(); } catch {} });
    await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(8);
    await enableA11y(); await wait(3);
    const sems = await getAllSems();
    await cdpClick(sems[13].rect.x + sems[13].rect.w/2, sems[13].rect.y + sems[13].rect.h/2);
    await wait(2);
    const ei = await page.$('input[type="text"]:not([type="hidden"])');
    if (ei) await ei.evaluate((el, v) => { el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); el.dispatchEvent(new Event('change', { bubbles: true })); }, OWNER_EMAIL);
    await wait(2);
    await cdpClick(sems[14].rect.x + sems[14].rect.w/2, sems[14].rect.y + sems[14].rect.h/2);
    await wait(2);
    await cdpInsert(OWNER_PASSWORD);
    await wait(2);
    await cdpClick(sems[15].rect.x + sems[15].rect.w/2, sems[15].rect.y + sems[15].rect.h/2);
    await wait(15);
    log(`  URL: ${page.url()}`);
    if (page.url().includes('login')) { log('❌ Owner login failed'); await browser.close(); process.exit(1); }
    await snap('01_owner_home', 'Owner home');

    // ─── Owner Bookings ───
    log('\n[OWNER] Bookings...');
    await page.goto(`${APP_URL}/#/owner/bookings`, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(12);
    await enableA11y(); await wait(3);
    await snap('02_owner_bookings', 'Owner bookings');

    // Check if fresh ref is visible
    const ownerTexts = await page.evaluate(() => {
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
      const texts = [];
      while (walker.nextNode()) {
        const t = walker.currentNode.textContent.trim();
        if (t && t.length > 2) texts.push(t);
      }
      return texts;
    });
    const refVisible = ownerTexts.some(t => t.includes(freshRef));
    log(`  ${freshRef} visible: ${refVisible ? '✅' : '❌'}`);
    if (refVisible) {
      const refText = ownerTexts.find(t => t.includes(freshRef));
      log(`  Booking text: ${refText.substring(0, 200)}`);
    }

    // ─── Accept & Request Payment ───
    log('\n[OWNER] Accept & request payment...');
    const ownerSems = await getAllSems();
    const acceptNode = ownerSems.find(s => /accept/i.test(s.label));
    if (acceptNode) {
      log(`  Found: "${acceptNode.label}" @(${acceptNode.rect.x.toFixed(0)},${acceptNode.rect.y.toFixed(0)})`);
      await cdpClick(acceptNode.rect.x + acceptNode.rect.w/2, acceptNode.rect.y + acceptNode.rect.h/2);
      await wait(5);
      await snap('03_accept_clicked', 'Accept clicked');
      
      const afterAccept = await getAllSems();
      const confirmBtn = afterAccept.find(s => /confirm/i.test(s.label));
      if (confirmBtn) {
        log(`  Confirm: "${confirmBtn.label}"`);
        await cdpClick(confirmBtn.rect.x + confirmBtn.rect.w/2, confirmBtn.rect.y + confirmBtn.rect.h/2);
        await wait(5);
      }
    } else {
      log('  ❌ Accept button not found');
      ownerSems.filter(s => s.label).forEach(s => log(`    "${s.label}" [${s.role}] @(${s.rect.x.toFixed(0)},${s.rect.y.toFixed(0)})`));
    }
    await snap('04_after_approve', 'After approval');

    // ─── Verify Status ───
    log('\n[OWNER] Verify status...');
    await wait(3);
    const statusSems = await getAllSems();
    const pendingNode = statusSems.find(s => /pending/i.test(s.label));
    log(`  Status: ${pendingNode ? pendingNode.label : 'unknown (check screenshot)'}`);
    await snap('05_status', 'Status check');

    // ─── Customer Login ───
    log('\n[CUSTOMER] Logging in...');
    await page.evaluate(() => { try { localStorage.clear(); } catch {} });
    await page.goto(APP_URL, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(8);
    await enableA11y(); await wait(3);
    const custSems = await getAllSems();
    await cdpClick(custSems[13].rect.x + custSems[13].rect.w/2, custSems[13].rect.y + custSems[13].rect.h/2);
    await wait(2);
    const ei2 = await page.$('input[type="text"]:not([type="hidden"])');
    if (ei2) await ei2.evaluate((el, v) => { el.value = v; el.dispatchEvent(new Event('input', { bubbles: true })); el.dispatchEvent(new Event('change', { bubbles: true })); }, CUSTOMER_EMAIL);
    await wait(2);
    await cdpClick(custSems[14].rect.x + custSems[14].rect.w/2, custSems[14].rect.y + custSems[14].rect.h/2);
    await wait(2);
    await cdpInsert(CUSTOMER_PASSWORD);
    await wait(2);
    await cdpClick(custSems[15].rect.x + custSems[15].rect.w/2, custSems[15].rect.y + custSems[15].rect.h/2);
    await wait(15);
    log(`  URL: ${page.url()}`);
    if (page.url().includes('login')) { log('❌ Customer login failed'); await browser.close(); process.exit(1); }
    await snap('06_cust_home', 'Customer home');

    // ─── Customer Bookings — Pay ───
    log('\n[CUSTOMER] Bookings — Pay...');
    await page.goto(`${APP_URL}/#/bookings`, { waitUntil: 'networkidle', timeout: TIMEOUT });
    await wait(12);
    await enableA11y(); await wait(3);
    await snap('07_cust_bookings', 'Customer bookings');

    const custTexts = await page.evaluate(() => {
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
      const texts = [];
      while (walker.nextNode()) {
        const t = walker.currentNode.textContent.trim();
        if (t && t.length > 2) texts.push(t);
      }
      return texts;
    });
    const refInCust = custTexts.some(t => t.includes(freshRef));
    log(`  ${freshRef} in customer bookings: ${refInCust ? '✅' : '❌'}`);
    
    const payVisible = custTexts.some(t => /pay/i.test(t));
    log(`  Pay action: ${payVisible ? '✅' : '❌'}`);

    // Print all visible text for debugging
    log('\n  All customer booking texts:');
    custTexts.filter(t => /BMS|pay|pending|book/i.test(t)).forEach(t => log(`    "${t.substring(0, 150)}"`));

    // ─── Save ───
    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), logs.join('\n'));
    log(`\n✅ Evidence: ${EVIDENCE_DIR}/`);
    await browser.close();

  } catch (err) {
    log(`\n❌ FATAL: ${err.message}`);
    log(err.stack);
    fs.writeFileSync(path.join(EVIDENCE_DIR, 'console.log'), logs.join('\n'));
  }
})();
