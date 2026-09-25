# End-to-end testing

BookMySpace has two E2E suites that drive the real router and screens
through stable `TestId` identifiers (never visible text):

| Suite | Location | Platforms | Driver |
|---|---|---|---|
| Flutter | `integration_test/` | Android, iOS | `flutter test integration_test/e2e_test.dart -d <device>` |
| Web | `e2e-playwright/` | Chromium | Playwright over Flutter web semantics |

Each suite runs in one of two modes:

- **mock** (default): deterministic, no Supabase, no Razorpay, no network.
  PR-safe. This is Phase 1 (smoke) and Phase 2 (business flows).
- **live**: the production app against the **DEV** Supabase project only,
  signed in as the DEV customer. Phase 3. Never PROD.

## Identifiers

`lib/core/widgets/test_id.dart` defines `E2eIds`. `TestId(id, child: …)`
exposes an id as a `ValueKey<String>` (Flutter finders) and as a semantics
`identifier` (rendered as `flt-semantics-identifier` on web, used by
Playwright). They are test hooks only: no layout, behaviour or accessible
label changes.

`e2e-playwright/support/ids.ts` mirrors `E2eIds`;
`test/tool/e2e_ids_contract_test.dart` fails if the two drift. Change both
together.

## Tags

`smoke`, `critical`, `auth`, `booking`, `owner`, `negative`, `payment`,
`admin`, `live`. Flutter: `--dart-define=E2E_TAGS=smoke,booking` (flows
without a matching tag are not registered). Playwright: `--grep @smoke`.

## Mock mode

Flutter (Android emulator or iOS simulator):

```bash
flutter test integration_test/e2e_test.dart -d <device> --no-pub
flutter test integration_test/e2e_test.dart -d <device> --no-pub \
  --dart-define=E2E_TAGS=smoke
```

Web:

```bash
cd e2e-playwright
npm ci
npm run build:web:mock      # builds build/e2e_web_mock
npx playwright test         # smoke + business, 36 tests
npm run test:smoke
```

`integration_test/support/mock_backend.dart` holds the scenarios
(`MockScenario`); web selects one with `/?scenario=<name>#/<route>`.
Mock mode never runs `tests/live/**`.

## Live DEV mode (Phase 3)

### What it covers

One smoke journey, on Android, iOS (Flutter) and web (Playwright):

sign in → search → venue details → availability on a chosen date →
booking hold (checkout opens) → booking history shows it → sign out.

Flutter also reads the booking row back from DEV (RLS: own bookings only)
and checks its user, venue, slot, date and `held`/`pending` status.

Not covered yet: payment (no Razorpay automation), cancellation, refunds,
owner and admin flows, OTP sign-in. Flutter web is not wired to the live
suite (the repo has no `test_driver/`); web live coverage is Playwright.

### Safety guards

- **DEV only.** `E2eLiveGuard` (Flutter) and `liveProblem` (Playwright)
  refuse anything but `https://zykxneztahxbjduagutv.supabase.co`, the
  project ref the DEV seed itself guards on. PROD, staging, local, other
  refs, look-alike hosts, extra ports, paths, queries and `http` are all
  refused. `test/tool/e2e_live_guard_test.dart` covers the rules.
- Flutter additionally requires `APP_ENV=dev` and re-checks what the app
  will actually use (`AppConfig.environment` must be development and
  `AppConfig.supabaseUrl` must be the DEV host) before Supabase starts.
- Playwright aborts every browser request to a non-DEV Supabase host and
  fails the test if any was attempted, or if the page never called DEV
  (so a web build configured for another project cannot pass).
- Missing settings stop the run before anything starts, with a message
  naming the setting, never its value.
- No credential in source. No credential in reports: live Playwright runs
  have trace, video, screenshots and the HTML report turned off, and
  credentials are typed through `typeSecret`, which never puts the value
  in a step, assertion or error. Do not re-enable those on the command
  line for live runs.
- Dart-defines are compiled into the test build, so the DEV customer
  credentials also end up in the installed Android/iOS test apps and in
  gitignored build output (`build/`, `.dart_tool/`, and, on iOS,
  `ios/Flutter/Generated.xcconfig` / `flutter_export_environment.sh` as
  base64). Treat those emulators, simulators and folders as holding DEV
  test credentials; never use real or PROD credentials for live E2E.

### Test data

Live mode uses the existing DEV seed (`supabase/seed_dev_e2e.sql`, marker
`e2e_v1`) unchanged. The only DEV writes are each run's own hold and draft
booking:

- Venues: the seeded function halls `Function Hall DEV <n>`. Ids are the
  seed's own `md5(...)::uuid` values (hardcoded in
  `integration_test/support/e2e_live.dart`, derived at runtime in
  `e2e-playwright/support/live.ts`).
- Seeded venues open on **Tuesdays only** (operating hours day 1,
  Monday = 0). The date strip covers 14 days, so there are always one or
  two Tuesdays to choose from.
- Before the UI starts, the suite asks the public read-only
  `available_time_slots` RPC for the first free (venue, Tuesday) pair of
  its own pool, in a fixed order, and books that.
- Pools are disjoint so parallel runs never compete for the same slot:
  Android 2–4, iOS 5–7, Flutter web 8, Playwright 9–10. Venue 1 holds
  the seed's history bookings and is never booked.
- Each run takes one hold and never pays, cancels or deletes anything.
  The `expire_stale_holds()` job (pg_cron, every minute) expires the hold
  after 10 minutes and cancels its draft booking, so every slot frees
  itself. A rerun within about 11 minutes simply picks the next pair;
  if a whole pool is taken, the failure lists every pair tried and why.
- What persists: after expiry, each run leaves one `cancelled` booking and
  one `expired` hold as permanent history rows for the DEV customer.
  Nothing stays active or blocks a slot, and booking inserts trigger no
  notifications or emails. There is no automatic cleanup of these rows.

### Prerequisites (DEV)

- DEV migrations applied, including pg_cron hold expiry.
- DEV seed applied and verified
  (`supabase/tests/dev_e2e_seed_verify.sql`).
- The dedicated DEV customer account the seed uses exists, with a profile
  name of letters/spaces and a phone number (function-hall bookings
  require both; the form pre-fills them from the profile).

### Settings

| Setting | Flutter (dart-define) | Playwright (env var) |
|---|---|---|
| Mode | `E2E_MODE=live` | `E2E_MODE=live` |
| Environment | `APP_ENV=dev` | – |
| DEV project URL | `SUPABASE_URL` | `E2E_SUPABASE_URL` |
| DEV publishable key | `SUPABASE_ANON_KEY` | `E2E_SUPABASE_ANON_KEY` |
| DEV customer | `E2E_USER_EMAIL`, `E2E_USER_PASSWORD` | `E2E_USER_EMAIL`, `E2E_USER_PASSWORD` |
| Web build under test | – | `E2E_WEB_BASE_URL` |

Keep credentials out of the repo and out of shell history: put the Flutter
values in a JSON file **outside the repository**, for example
`~/.bms/e2e_live_dev.json`:

```json
{
  "E2E_MODE": "live",
  "APP_ENV": "dev",
  "SUPABASE_URL": "https://zykxneztahxbjduagutv.supabase.co",
  "SUPABASE_ANON_KEY": "<DEV publishable key>",
  "E2E_USER_EMAIL": "<DEV customer email>",
  "E2E_USER_PASSWORD": "<DEV customer password>"
}
```

### Run: Android / iOS

```bash
flutter test integration_test/e2e_test.dart -d <device> --no-pub \
  --dart-define-from-file=$HOME/.bms/e2e_live_dev.json
```

Without the settings, or with any non-DEV project, the run stops at once
with `E2E_MODE=live refused: …`.

### Run: web (Playwright)

Build and serve a DEV web build (under the ignored `build/` folder). It
needs only the app settings, never the customer credentials:

```bash
flutter build web --release --no-pub --output build/e2e_web_live \
  --dart-define=APP_ENV=dev \
  --dart-define=SUPABASE_URL=https://zykxneztahxbjduagutv.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="$E2E_SUPABASE_ANON_KEY"
node e2e-playwright/support/serve.mjs build/e2e_web_live 8788
```

Then, with the environment variables above exported (for example from a
file outside the repo):

```bash
cd e2e-playwright
E2E_MODE=live E2E_WEB_BASE_URL=http://127.0.0.1:8788 npx playwright test
```

Live mode runs only `tests/live/**` and writes JUnit to
`reports/junit/web-e2e-live.xml`.

## Adding flows

- Mock: add a `MockScenario` if needed, a flow in
  `integration_test/flows/`, and the mirrored spec in
  `e2e-playwright/tests/`.
- Live: add to `integration_test/flows/live_smoke_flows.dart` and
  `e2e-playwright/tests/live/`. Use seeded data only, keep writes
  self-expiring or owned by the run, and never add cleanup that touches
  shared DEV rows.
- New ids: add to `E2eIds` and `ids.ts` together; wrap the widget in
  `TestId` and change nothing else in production code.
