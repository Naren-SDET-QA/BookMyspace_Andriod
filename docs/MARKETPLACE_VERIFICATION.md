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
columns/functions. B5's SQL was moved byte-for-byte to the unique forward
version `20261018100000_b5_venue_payment_rules_reconciled.sql`. On a new,
disposable PostgreSQL 18 database, both B4 and re-versioned B5 applied
successfully; a check confirmed the expected B4/B5 columns and functions, and
the two unique versions inserted into a primary-key migration ledger. The
fixture intentionally models only the dependencies for these two migrations;
it is not the full Supabase stack. The full PostgreSQL 17 Supabase reset on the
updated PR head exposed a second prerequisite gap: the admin content guard
expects `course_faculty.updated_at`, while the table's earlier creation does
not define it. The connected development schema already has the column; no
hosted database was modified. The new prerequisite migration adds it before
the guard in clean-chain order. A full PostgreSQL 17 Supabase reset is pending
on the new head. Before applying to any shared environment, compare its ledger
and schema and use the forward-only repair procedure in
`supabase/migrations/README.md`; never reset a shared database.

### Phase 1 stabilization follow-up — 2026-10-18

The duplicate migration version is reconciled without editing historical SQL:
B4 remains `20260928071656`, and B5's bytes are preserved at
`20261018100000_b5_venue_payment_rules_reconciled.sql`. The additive
`20260929130000_course_faculty_updated_at_prerequisite.sql` supplies the
missing prerequisite before the existing content guard. A further additive
`20261018030126_allow_course_trial_upgrade.sql` allows only trial-to-paid
course upgrades; duplicate active enrollment remains rejected. No connected
or production database was changed by these fixes.

Pinned CI (`Flutter 3.44.0` / `Dart 3.12.0`, Supabase CLI `2.117.0`, disposable
PostgreSQL 17) successfully ran `supabase start` and
`supabase db reset --local --no-seed` through the complete migration chain.
The SQL test loop then reached `supabase/tests/phase7_cancellation_policy_test.sql`
and failed because legacy fixtures omitted required organization and venue
fields. The fixture now supplies `org_type = 'venue_owner'`, latitude and
longitude; that last correction awaits a fresh full-suite CI result. Earlier
test failures also exposed incorrect caller context in existing SQL tests and
an unreachable trial-upgrade branch. The tests now set each fixture user's JWT
subject, and the forward-only function migration fixes the upgrade behavior
without weakening authorization. No full SQL-suite pass is claimed yet.

Analyzer reconciliation was evidence-checked against the pinned CI output:
the base-main run `37103543185` reported 110 diagnostics beyond the old
baseline; branch run `39092759233` reported 95. Comparing severity, code, path
and message found all 95 branch diagnostics already present on main, zero
branch-only diagnostics, and 15 main findings absent from this branch. The
baseline was refreshed to those reviewed diagnostics (679 infos, 80 warnings,
396 records); no analyzer rules or CI checks were changed. The next CI run must
confirm the validator passes with this reviewed baseline. Whole-repository
analysis is not clean; the baseline preserves existing debt visibly.

The latest full-history Gitleaks runs still report the same 13 historical
findings (11 generic API-key and 2 GCP-key matches), attributed to commits by
repository owner Naren. The implicated short commit IDs are `52b558e`,
`aeafb7e`, `7164e96`, `c9f2d8d`, `6ea4acc`, `62783fb`, `d15e6a6` and
`ea2f1cb`. No secret values are included here or in the report.
The owner should revoke/replace any active GCP/Firebase credentials, apply
strict API/application restrictions, and classify every generic match; rotate
any private credential. Public client identifiers should be confirmed as
intentionally public and restricted. Nothing was allowlisted or disabled.

Latest local Flutter regression command remains
`flutter test --no-pub --concurrency=4 --reporter expanded`: **1,875 passed**
on Flutter 3.47.2 / Dart 3.13.2. Local
`flutter build web --release --no-pub` and the config-regenerated
`flutter build apk --release --no-pub` passed on that newer toolchain. In the
required general CI, the full Flutter tests and Android/Web/iOS builds remain
skipped while the analyzer gate fails; the dedicated marketplace Flutter,
PostgreSQL catalog/RLS, and web checks pass, with platform matrix jobs running
separately. No signed iOS build or physical-device run is claimed.

Phase 1 is not yet release-ready: the refreshed analyzer baseline needs CI
confirmation, the full SQL contract loop still needs a green run, and the
credential-owner actions are unresolved. Do not start Phase 2 inventory or
merge/deploy PR #6 until those gates are resolved.

### Phase 1 CI update — 2026-10-18

On `1afbf345`, pinned CI analyzer validation passed. The dedicated marketplace
Flutter tests, PostgreSQL catalog/RLS checks, and Android, Web, and unsigned
iOS builds all passed. The general full Flutter suite was still running when
the SQL failure was retrieved. The full disposable migration reset applied
every migration successfully; the cancellation SQL tests then exposed a
conflict between the legacy full `refunds.payment_id` unique constraint and
the later active-only partial unique index. The affected cancellation fixtures
were corrected to satisfy the actual required venue, slot, hold, and booking
columns. A new forward-only migration verifies the active-only index before
dropping the obsolete full constraint, enabling retry only after a failed
refund without changing refund rows. Its full-chain SQL validation is pending; no
shared or production database was touched.

The subsequent run on `996c4ac` successfully applied this migration, and the
full cancellation-policy SQL test passed including retry after a failed
refund. The next SQL script exposed older fixture drift in
`refund_cancellation_scenarios_test.sql`; its organization and venue fixtures
were brought up to the current schema, and bookings now use a shared helper
that provides the required booking reference and date. A further rerun found
the fixture's referenced users were not seeded in `auth.users`; those explicit
disposable users have now been added, and role setup is idempotent when the
same IDs were already created by an earlier SQL fixture. SQL validation is
still pending on this latest fixture correction. A subsequent SQL run got
past the role setup and exposed the final domain invariant: each booking must
reference a time slot or bookable resource. The fixture now provisions two
valid test slots and uses the matching slot in its shared booking helper.
The next run confirmed the JWT context and then correctly enforced the
no-overlap constraint when the test reused a venue/date/time. The helper now
assigns a distinct disposable booking date to each test booking; the
constraint remains unchanged. SQL validation is pending again.

The next SQL run passed the cancellation policy suite and all 12 refund
cancellation scenarios, then reached the security-definer RPC contract test.
That test found `mark_ticket_resolved` still executable by `anon`: a historical
function recreation revoked `PUBLIC` but did not revoke the Supabase `anon`
role explicitly. A forward-only grant reconciliation now revokes both and
grants only `authenticated` and `service_role`. Its full-chain verification is
pending; the RPC body and its authenticated authorization checks are unchanged.

The marketplace platform matrix on that head passed: Android debug APK, Web
release, and iOS release compilation with `--no-codesign`. These are build
checks, not signed distribution or physical-device verification. Gitleaks
continues to fail on the same 13 historical findings and remains an owner
credential review/rotation gate. Phase 1 is still not release-ready.

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
SQL contract fixtures, three forward-only stabilization migrations, workflow
and audit/verification documentation. The two catalog migrations were applied
to development; the stabilization migrations have only been applied in
disposable CI so far. **No Edge Functions were added or
modified**; this catalog uses a read-only database RPC and retains existing
booking/payment functions. The next milestone is movie/cinema inventory and
seat layouts, following resolution of the shared release gates.

Complete the remaining inventory/payment/ticket milestones and test the
configured staging flows on Android/iOS/Web before describing the entire app
as end-to-end production ready. Do not merge or publish this draft based on
the presence of the new catalog UI alone.
