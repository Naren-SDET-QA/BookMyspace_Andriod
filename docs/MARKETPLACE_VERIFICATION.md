# Marketplace verification and rollout

This branch delivers the first marketplace integration milestone, not the
complete multi-category ticketing platform requested in the product brief.
Movies, cinema layouts, assigned-seat holds, paid event commerce and the other
remaining milestones are tracked in `MARKETPLACE_IMPLEMENTATION.md`.

## Delivered behavior

- `/marketplace` is a guest-readable Flutter section inside the existing app, reachable from
  the standard, premium, moment and life Home layouts and the screen directory.
- Discovery uses a typed repository and `marketplace_search`, with full-text
  search, selected city, category, price, dates, sort and bounded 24-item pages.
- Existing venue/event/course detail routes retain ownership of booking flows.
  Dining/experience/sports listings are classified from existing venue categories;
  this does not implement new restaurant-table or assigned-seat inventory.
- English/Telugu copy, light/dark theme support, loading/empty/retry states,
  350 ms search debounce and accessible responsive layouts are implemented.
- No catalog content or availability is invented when the backend fails.

## Database and development environment

Applied to the connected **bookmyspace-dev** project (`zykxneztahxbjduagutv`):

1. `20261017193103_marketplace_catalog_search.sql`
2. `20261017193222_marketplace_anonymous_policy_guard.sql`

Migration filenames match the versions recorded by the remote migration tool.
The first adds a security-invoker RPC, three full-text indexes and explicit
column-level SELECT/EXECUTE grants. All eight source tables retain RLS.
The second scopes existing owner/admin policies to `authenticated`, retaining
their predicates and the separate public policies. It fixes a live anonymous
read error caused by `venue_images_owner_write` calling owner-only
`can_edit_venue` under a PUBLIC `ALL` policy. No owner helper was exposed to
anonymous callers, and no booking/payment records were modified.

Verified a real anonymous query with `SET LOCAL ROLE anon`: the first page
returned 24 published venue listings. No customer, booking or payment test
fixtures were inserted into the connected development project.

Security advisor results before/after were unchanged: 10 policy-less RLS
tables (INFO), 36 mutable function search paths, 1 existing RLS-disabled object,
3 extensions in public, 32 anonymous and 169 authenticated security-definer
function findings, and leaked-password protection disabled. These are baseline
findings, not a clean security audit. See the [Supabase database linter](https://supabase.com/docs/guides/database/database-linter)
for remediation guidance before a production launch.

## Executed checks

Local toolchain: Flutter 3.47.2 / Dart 3.13.2 on Windows. Existing CI remains
pinned to Flutter 3.44.0 / Dart 3.12.0; no dependency upgrades are included.

- Focused marketplace/affected screens/registration contract suite: **62 passed**. Viewports 320, 390,
  768 and 1440 pixels, including 200% text scaling, were tested.
- Focused analyzer for new marketplace/localization/tests: **no issues**.
- `flutter build web --release --no-pub`: **passed**.
- PostgreSQL 18 disposable schema harness: catalog migration, publication,
  full-text/category/price/date filtering, stable pagination, invalid inputs,
  module platforms, explicit column grants and source RLS for anon/authenticated
  **passed**. The legacy anonymous owner-policy failure was reproduced before
  the guard and passed after the guard.
- The harness intentionally tests a narrow schema. It does not replace full
  migration-chain tests against the pinned Supabase/PostgreSQL 17 stack.
- Whole-repository initial analyzer: **780 existing diagnostics**, reduced to
  **751** after the registration repair; the repository
  already uses an analyzer baseline rather than requiring a clean global run.
- The full initial test run completed with 1,832 passes and 4 failures. Detailed
  reruns and affected-screen checks are being collected during this branch.
- `flutter build apk --debug --no-pub`: **passed**, including a development build
  using the existing dev API URL and a public publishable key. No service-role
  key is included. Physical-device installation was not performed.
- Full regression rerun: **1,868 passed, one failed** because a UI test still
  asserted the removed simulated registration form. That test now checks the
  real entry flow, and an additional test validates required schema fields in
  the actual dynamic form. Both pass in the 62-test affected-suite rerun. A
  completely green final whole-repository run is still a release gate.
- The marketplace Android, Web and unsigned iOS build jobs **passed** in GitHub
  Actions on commit `c632007`; the macOS iOS deployment-target checks also passed.
  The final guest-route change is additionally compiled locally for Android/Web
  and covered by a route test. Signing and physical-device checks remain gates.

## Reproduce

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib/features/marketplace lib/core/localization/marketplace_strings.dart test/features/marketplace
dart analyze lib/features/marketplace lib/core/localization/marketplace_strings.dart test/features/marketplace
flutter test test/features/marketplace test/features/common/master_screen_directory_screen_test.dart test/features/home/choice_home_screen_test.dart
flutter build web --release
flutter build apk --debug
```

On macOS with Xcode and CocoaPods, additionally run the existing iOS deployment
target checks and `flutter build ios --release --no-codesign`.

The `Marketplace section` workflow runs focused Flutter checks and the
PostgreSQL 17 catalog/RLS harness, plus separate Android/Web/macOS iOS compile
jobs on pull requests. The focused Flutter and PostgreSQL jobs have passed on
GitHub Actions with Flutter 3.44.0 and PostgreSQL 17. Existing CI continues to run its full tests,
full Supabase migration chain and Android/web/iOS build gates on pull requests.

## Browser verification

The rebuilt development web app was opened in the app browser at a phone-width
viewport. Guest navigation to `/marketplace` rendered the themed catalog.
Searching `Auditorium` returned actual existing development venue cards (not
client fixtures). Opening the first result loaded its existing venue detail
screen with the correct title, price, availability and booking entry controls.
The route regression test confirms that guest catalog access does not make
bookings, checkout, account or admin routes public.

### Existing release blockers found by CI

- The historical migration chain has two different SQL files with version
  `20260928071656`. Supabase rejects the second with a duplicate primary key in
  its migration history. The repository's forward-only/immutable-history policy
  means this requires a deliberate history reconciliation; this branch does
  not rename old migrations or reset any shared database.
- The full-history secret scanner reports **13 historical findings** (11
  generic API-key findings and 2 GCP API-key findings), all predating this
  branch. The redacted report contains file/line/commit identifiers only. Key
  owners must assess and rotate/revoke any real exposed credentials before
  accepting a history baseline or rewriting history. The scan is not disabled.
- The first full CI analyzer comparison found 113 diagnostics beyond the old
  baseline. After restoring the real registration routing and its contracts,
  the comparison still found 101 diagnostics beyond that baseline.
  Remaining diagnostics must be assessed without expanding the baseline to hide them.

## Phase 1 retest — 2026-10-18

At PR head `d41b956`, GitHub reported the dedicated Flutter 3.44.0 focused
checks and PostgreSQL 17 catalog/RLS checks passing. The dedicated Android,
web and unsigned iOS compile jobs also passed. In the required general CI,
`Analyze & Lint` failed with 102 diagnostics beyond the reviewed baseline;
`SQL Migration Tests` failed while applying the second file named
`20260928071656`. The general test and platform build jobs were skipped because
they depend on the failed analyzer job. Both full-history Gitleaks runs failed
on the same 13 historical findings.

Local verification used Flutter 3.47.2 / Dart 3.13.2, not the repository's
pinned CI toolchain:

- `flutter test --no-pub --concurrency=4 --reporter expanded`: **1,875 passed**.
- `flutter build web --release --no-pub`: **passed**.
- `flutter build apk --release --config-only` followed by
  `flutter build apk --release --no-pub`: **passed** (unsigned local release
  APK). The build requires Flutter to regenerate plugin configuration; an
  earlier invocation with stale dev-only plugin entries failed. No Gradle
  source change was needed.
- The focused 62-test suite passed before the complete suite.

The 13 redacted Gitleaks entries map to commits by repository owner Naren.
Two are `gcp-api-key` findings in Android application sources. The other 11
are `generic-api-key` findings across the Android repository, an E2E script,
and Flutter configuration. Redacted scanner metadata cannot establish whether
these are active credentials or intentionally public client identifiers. The
Google Cloud/Firebase key owner should revoke and replace active exposed keys,
then confirm application/API restrictions. Each generic match needs owner-side
classification, with rotation for any private credential. No fingerprint has
been allowlisted and the scanner remains enabled.

Read-only inspection of the connected development project found no
`20260928071656` entry in the remote migration ledger. The schema contains all
B4 payment-plan columns/functions but none of B5's payment-rule
columns/functions. A forward-only reconciliation can preserve the SQL
contents: assign B5 a unique migration version, verify each environment's
schema and migration ledger, mark the legacy B4 version applied only where its
effects are verified, and apply B5 only where its effects are absent. No
historical migration file or hosted database was changed. The plan still needs
full-chain disposable validation before adoption; production data/schema were
not modified.

The analyzer baseline has not been expanded. Most excess findings are in
paths unchanged by this branch; several findings in changed Home/router and
registration-test files were corrected. Remaining existing warnings still
need source-level review, and the pinned analyzer must be rerun at the updated
head.

### Registration regression repaired

The base commit replaced the working unified registration entry with a form
that delayed 600 ms and reported success without persisting anything. The
branch restores the predecessor's backend-backed routing: owners use the
dedicated OTP flow; other roles use the existing dynamic module-registration
repository. It restores `UnifiedRegistrationModule.resolve`, removes the
fabricated success path and sample personal-data defaults, and adds widget
navigation tests. Existing registered module contracts are preserved.

## API

`marketplace_search` accepts `p_query`, `p_city`, `p_category`, `p_sort`,
`p_min_price`, `p_max_price`, `p_from`, `p_until`, `p_limit`, `p_offset`,
`p_platform`. Limit is 1–48, offset 0–10,000. Date end is exclusive; scheduled
filters omit undated venues. Prices are currently INR only. Search responses
are discovery data and must never be used as authoritative checkout quotes.
Entity IDs are UUIDs; clients derive internal routes from the typed entity
kind and never execute a route supplied by the backend.

## Remaining release gates

Changed file groups: `features/marketplace`, marketplace localization, router,
Home entry cards, screen directory, real registration entry, focused tests,
workflow and audit/verification documentation. Two forward-only migrations
were added and applied to development. **No Edge Functions were added or
modified**; this catalog uses a read-only database RPC and retains existing
booking/payment functions. The next milestone is movie/cinema inventory and
seat layouts, following resolution of the shared release gates.

Complete the remaining inventory/payment/ticket milestones and test the
configured staging flows on Android/iOS/Web before describing the entire app
as end-to-end production ready. Do not merge or publish this draft based on
the presence of the new catalog UI alone.
