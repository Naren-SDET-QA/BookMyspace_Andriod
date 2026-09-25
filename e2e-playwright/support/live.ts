import { createHash } from 'node:crypto';
import { expect, type APIRequestContext, type Page } from '@playwright/test';
import type { FlutterApp } from './flutter';
import { Ids, Tab } from './ids';

/**
 * Live DEV mode (E2E_MODE=live). The only backend it may reach is the DEV
 * Supabase project the DEV seed guards on (supabase/seed_dev_e2e.sql).
 * Mirrors `E2eLiveGuard` in integration_test/support/e2e_env.dart.
 */
export const DEV_PROJECT_REF = 'zykxneztahxbjduagutv';
export const DEV_SUPABASE_HOST = `${DEV_PROJECT_REF}.supabase.co`;

type Env = Record<string, string | undefined>;

export interface LiveConfig {
  supabaseUrl: string;
  anonKey: string;
  email: string;
  password: string;
}

/** Why live mode must not run, or null. Names settings, never values. */
export function liveProblem(env: Env): string | null {
  if (!env.E2E_WEB_BASE_URL) {
    return 'E2E_WEB_BASE_URL is required (a web build configured for DEV).';
  }
  const raw = env.E2E_SUPABASE_URL ?? '';
  if (!raw) return 'E2E_SUPABASE_URL is required (the DEV project URL).';
  let url: URL | null = null;
  try {
    url = new URL(raw);
  } catch {
    url = null;
  }
  if (
    !url ||
    url.protocol !== 'https:' ||
    url.hostname.toLowerCase() !== DEV_SUPABASE_HOST ||
    url.port !== '' ||
    url.username !== '' ||
    url.password !== '' ||
    url.search !== '' ||
    url.hash !== '' ||
    (url.pathname !== '' && url.pathname !== '/')
  ) {
    const host = url?.hostname ?? '';
    return `E2E_SUPABASE_URL host "${host}" is refused: only https://${DEV_SUPABASE_HOST} (DEV) is allowed.`;
  }
  if (!env.E2E_SUPABASE_ANON_KEY) return 'E2E_SUPABASE_ANON_KEY is required (the DEV publishable key).';
  if (!env.E2E_USER_EMAIL || !env.E2E_USER_PASSWORD) {
    return 'E2E_USER_EMAIL and E2E_USER_PASSWORD are required (the DEV customer).';
  }
  return null;
}

/** The validated live settings. Throws (without values) when refused. */
export function liveConfig(env: Env = process.env): LiveConfig {
  const problem = liveProblem(env);
  if (problem) throw new Error(`E2E_MODE=live refused: ${problem}`);
  return {
    supabaseUrl: `https://${DEV_SUPABASE_HOST}`,
    anonKey: env.E2E_SUPABASE_ANON_KEY as string,
    email: env.E2E_USER_EMAIL as string,
    password: env.E2E_USER_PASSWORD as string,
  };
}

const isSupabaseHost = (host: string) => /(^|\.)supabase\.(co|in|net)$/i.test(host);

/**
 * Aborts every browser request to a Supabase host other than DEV. Returns a
 * check to call at the end: nothing was blocked, and the page really talked
 * to the DEV project (so a build pointed elsewhere cannot pass).
 */
export async function guardBackend(page: Page): Promise<() => void> {
  const blocked = new Set<string>();
  let devRequests = 0;
  await page.route('**/*', async (route) => {
    let host = '';
    try {
      host = new URL(route.request().url()).hostname.toLowerCase();
    } catch {
      host = '';
    }
    if (isSupabaseHost(host) && host !== DEV_SUPABASE_HOST) {
      blocked.add(host);
      await route.abort('blockedbyclient');
      return;
    }
    if (host === DEV_SUPABASE_HOST) devRequests++;
    await route.continue();
  });
  return () => {
    expect([...blocked], 'requests to non-DEV Supabase hosts were blocked').toEqual([]);
    expect(devRequests, 'the web build never called the DEV Supabase project').toBeGreaterThan(0);
  };
}

/** A deterministic DEV seed function hall (marker e2e_v1). */
export interface SeedVenue {
  number: number;
  name: string;
  id: string;
  slotId: string;
}

/** Postgres `md5(text)::uuid`, as the DEV seed derives its ids. */
const md5Uuid = (text: string): string => {
  const h = createHash('md5').update(text).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
};

export function seedFunctionHall(n: number): SeedVenue {
  const nn = String(n).padStart(2, '0');
  return {
    number: n,
    name: `Function Hall DEV ${n}`,
    id: md5Uuid(`bms-dev-e2e:venue:function_hall:${n}`),
    slotId: md5Uuid(`bms-dev-e2e-function_hall-${nn}:slot:1`),
  };
}

/**
 * Playwright's own venues. Disjoint from the Flutter pools (Android 2-4,
 * iOS 5-7, Flutter web 8; venue 1 holds the seed's history bookings), so
 * parallel runs never race for the same slot.
 */
export const WEB_POOL: readonly number[] = [9, 10];

/** Function halls require an event type before a hold can be taken. */
export const LIVE_EVENT_TYPE = 'Wedding';

/** `yyyy-MM-dd` in local time, as used by `Ids.bookingDate`. */
export function isoDate(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export interface LiveTarget {
  venue: SeedVenue;
  isoDate: string;
}

/**
 * First free (venue, Tuesday) pair of WEB_POOL, in a fixed order, via the
 * public read-only `available_time_slots` RPC. Seeded venues only open on
 * Tuesdays, and a slot stays taken while a hold is active (about 11 min).
 */
export async function pickLiveTarget(request: APIRequestContext, cfg: LiveConfig): Promise<LiveTarget> {
  const today = new Date();
  const tuesdays: Date[] = [];
  for (let i = 1; i < 14; i++) {
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
    if (date.getDay() === 2) tuesdays.push(date);
  }
  const tried: string[] = [];
  for (const venue of WEB_POOL.map(seedFunctionHall)) {
    for (const date of tuesdays) {
      const day = isoDate(date);
      const res = await request.post(`${cfg.supabaseUrl}/rest/v1/rpc/available_time_slots`, {
        headers: { apikey: cfg.anonKey, 'Content-Type': 'application/json' },
        data: { p_venue_id: venue.id, p_book_date: day },
      });
      if (!res.ok()) throw new Error(`available_time_slots failed with HTTP ${res.status()}.`);
      const rows = (await res.json()) as Array<{ slot_id: string; is_available: boolean; reason: string }>;
      const slot = rows.find((row) => row.slot_id === venue.slotId);
      if (slot?.is_available) return { venue, isoDate: day };
      tried.push(`${venue.name} ${day}: ${slot?.reason ?? 'no seeded slot'}`);
    }
  }
  throw new Error(
    `No free DEV seed slot for the web suite. Tried: ${tried.join('; ')}. ` +
      'Holds from an earlier run expire in about 11 minutes; "no seeded slot" means the DEV seed (e2e_v1) is not applied.',
  );
}

/**
 * Types a credential like `FlutterApp.fill`, but the value never appears in
 * a step title, assertion message, error or report.
 */
export async function typeSecret(app: FlutterApp, id: string, value: string): Promise<void> {
  const field = await app.waitFor(id);
  const input = field.locator('input, textarea').first();
  for (let attempt = 1; attempt <= 3; attempt++) {
    await field.click();
    await expect(input).toBeFocused();
    await app.page.waitForTimeout(150);
    await app.page.keyboard.press('ControlOrMeta+A');
    await app.page.keyboard.type(value, { delay: 25 });
    await app.page.waitForTimeout(250);
    const typed = await input.inputValue().catch(() => '');
    if (typed === value) return;
  }
  throw new Error(`Flutter did not accept the credential typed into "${id}".`);
}

/** The booking id of the checkout route (`#/bookings/<id>/pay`). */
export function bookingIdFromUrl(url: string): string {
  const match = /#\/bookings\/([^/?#]+)\/pay$/.exec(url);
  if (!match) throw new Error(`Expected the checkout route, got "${new URL(url).hash}".`);
  return match[1];
}

/** Whether the seeded slot of [target] is bookable again (public read-only RPC). */
export async function isSlotAvailable(request: APIRequestContext, cfg: LiveConfig, target: LiveTarget): Promise<boolean> {
  const res = await request.post(`${cfg.supabaseUrl}/rest/v1/rpc/available_time_slots`, {
    headers: { apikey: cfg.anonKey, 'Content-Type': 'application/json' },
    data: { p_venue_id: target.venue.id, p_book_date: target.isoDate },
  });
  if (!res.ok()) throw new Error(`available_time_slots failed with HTTP ${res.status()}.`);
  const rows = (await res.json()) as Array<{ slot_id: string; is_available: boolean }>;
  return rows.find((row) => row.slot_id === target.venue.slotId)?.is_available === true;
}

/**
 * Signs in as the DEV customer and takes one hold on [target], the same
 * journey as the Phase 3 smoke. Returns the booking id once checkout shows it.
 */
export async function signInAndHold(app: FlutterApp, page: Page, cfg: LiveConfig, target: LiveTarget): Promise<string> {
  await app.open('/login');
  await typeSecret(app, Ids.loginEmail, cfg.email);
  await typeSecret(app, Ids.loginPassword, cfg.password);
  await app.tap(Ids.loginSubmit);
  await app.waitFor(Ids.nav(Tab.home));

  await app.tap(Ids.nav(Tab.search));
  await app.fill(Ids.searchInput, target.venue.name);
  await page.keyboard.press('Enter');
  await app.tap(Ids.venueCard(target.venue.id));
  await app.waitFor(Ids.bookNow);
  await app.tap(Ids.bookNow);

  await app.waitFor(Ids.bookingDate(isoDate(new Date())));
  await app.tap(Ids.bookingDate(target.isoDate));
  await app.waitFor(Ids.slot(target.venue.slotId));
  await app.fill(Ids.bookingEventType, LIVE_EVENT_TYPE);
  await app.tap(Ids.slot(target.venue.slotId));
  await app.tap(Ids.bookingConfirm);
  await app.tapIfShown(Ids.bookingConfirmDialog);
  await app.waitFor(Ids.checkoutSummary);
  return bookingIdFromUrl(page.url());
}

/** Pops pushed routes (venue, booking, checkout) until the bottom navigation is back. */
export async function backToShell(app: FlutterApp): Promise<void> {
  for (let i = 0; i < 5 && !(await app.byId(Ids.nav(Tab.bookings)).first().isVisible()); i++) {
    await app.back();
  }
  await app.waitFor(Ids.nav(Tab.bookings));
}

/** Signs out from the profile tab and waits for the sign-in screen. */
export async function signOut(app: FlutterApp): Promise<void> {
  await app.tap(Ids.nav(Tab.profile));
  await app.reveal(Ids.logout);
  await app.tap(Ids.logout);
  await app.waitFor(Ids.loginSubmit);
}
