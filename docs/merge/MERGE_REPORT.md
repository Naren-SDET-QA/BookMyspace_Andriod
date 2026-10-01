# Merge report — branch `merged-all`

All branches of `Naren-SDET-QA/BookMyspace_Andriod` merged into one branch
without dropping functionality. `main` is untouched.

## What was merged

| Source | How |
|---|---|
| old `main` (now `archive/legacy-main-2026-09-25`, `358a1b0`) | Base of `merged-all` |
| `phase5-14-release` | Already fully contained in `main` |
| `fix/ios-bookmyspace-ui` | Merged (both Discovery catalogue and Theme admin links kept) |
| `fix/ios-bookmyspace-ui-buffy` | Merged (Home redesign from buffy, theme customizer from main, l10n union, `app/` and Firebase files kept) |
| `release/v1.0` (separate git history, now also GitHub `main`) | Merged up to `1f9b1f3` via a graft on the shared upstream seed commit; see "Clashing screens" |
| Local Mac copy (`/Users/aa/BookMyspace_Andriod`) | No unpushed commits. Untracked `animated_category_chip.dart` (theme-aware) and `20260921180000_education_configurable_modules.sql` added. `stash@{0}` (WIP, did not compile) saved as branch `wip/local-stash-home-2up` — not merged. |

Not merged: branches on the separate `upstream` repo
(`Naren-SDET-QA/bookmyspace`: `feature/hotel-stays-e2e`, `feature/pg-coliving-v1`, …).
They belong to a different repository and are older than `release/v1.0`.

## Clashing screens (release/v1.0 vs main)

Main's screen stays at the original route. The release version is kept as
`<screen>_v1.dart` (class `XxxV1`) under `/v1/...`:

home, search, booking, payment, venue_details, profile, login, my_bookings,
notifications, owner_registration, create_venue, settings, courses_list,
admin_dashboard, owner_venues.

Release routes that clashed with a main path were moved:

| Release screen | New path |
|---|---|
| Category controls | `/admin/category-controls` |
| Payments oversight | `/admin/payments-oversight` |
| Owner bookings manager | `/owner/bookings-manager` |
| Education institute details | `/education/institutes/:id` |
| Venue map | `/venue-map` |
| Payment receipt | `/bookings/:id/payment-receipt` |
| Owner institute listing | `/owner/institute-listing` |
| AI assistant | `/ai-assistant` |

Shell: main's configurable bottom bar by default; the release "modern" bar is
used when admin setting `bottom_nav_style == 'modern'`. Extra shell tabs
(map, saved, chat) exist but are disabled by default in nav-tab config.

Models, repositories, providers and localization tables are unions of both
lineages. Main's `/owner` and admin routes keep their in-screen `RoleGate`;
release-only owner/admin routes keep the router redirect to `/profile`.

## Backend

- **Migrations:** all kept. Renamed to avoid version collisions:
  `0019_categories_management` → `20260912132544_categories_management.sql`,
  `20260915120000_fix_phase7…` → `20260915120001_…`. Small SQL fixes so the full
  set applies from scratch (verified: 151/151 on local Postgres 16).
- **Remote ledger:** the DEV project's migration history does not match either
  lineage. Before `supabase db push`, run `supabase migration list` and use
  `supabase migration repair` to align it. Nothing was pushed to Supabase.
- **Edge functions:** main versions kept; release versions deployed under
  `<name>-release-v1` (create-booking-hold, create-payment-order,
  create-refund, razorpay-webhook). `config.toml` merged.
- Email confirmation template supports both link and OTP token.

## Other

- `pubspec.yaml`: union; `file_picker` pinned to 10.3.10, `geolocator ^14.0.2`.
- iOS: `Podfile.lock` is main's — run `cd ios && pod install`.
- Legacy native Kotlin `app/`: main versions kept; release copies under
  `docs/merge/release-v1-native-app/`.
- Clashing release tests kept as `*_release_test.dart`, test doubles as `*_release.dart`.

## Verification

- `flutter analyze`: 0 errors.
- `flutter test`: 1496 tests, all passing.
