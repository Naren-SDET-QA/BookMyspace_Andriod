# BookMySpace — Final Merge & Parity Report (Flutter = Authoritative)

Date: 2026-09-21 · Branch: `fix/ios-bookmyspace-ui`
Scope: merge **functionality only** from `bookmyspace_andriod_new.zip` into the
existing Flutter/Supabase app. No second backend was introduced.

---

## 1. Feature parity table

| # | Feature (priority order) | Flutter before | Android reference | Supabase/RPC support | Status after this pass |
|---|--------------------------|----------------|-------------------|----------------------|------------------------|
| 1 | Booking required fields | COMPLETE (server hold/approval RPCs) | demo-only | `request_venue_booking`, `create-booking-hold` fn | COMPLETE |
| 2 | Home date/guest prefill | COMPLETE (`discovery_booking_prefs` untracked but wired) | partial | n/a (client-side only) | COMPLETE |
| 3 | AI/voice booking flow | COMPLETE (`ai_booking` feature + `ai-booking-assistant` edge fn + speech channels on Android/iOS/Web) | demo | `available_time_slots` RPC re-used server-side | COMPLETE |
| 4 | Real coupon handling | PARTIAL → hardened | hardcoded fake coupons | `booking_coupons` table; totals settled by server | COMPLETE (client gates min-amount/expiry; server prices stay authoritative) |
| 5 | Contact masking + Call/Chat | PARTIAL (raw number) | masking rule | RLS-owned `contact_phone` | COMPLETE (masked until owner-approved booking; WhatsApp added) |
| 6 | Book Again | MISSING | present (demo data) | same hold RPCs re-used | COMPLETE (prefills booking flow; server-authoritative) |
| 7 | Admin Home customization | COMPLETE (`admin_home_appearance_screen`, CMS banners/flags) | partial | CMS tables + RLS | COMPLETE |
| 8 | QR check-in | COMPLETE (`qr_checkin` feature, `check_in_booking` RPC migration) | demo | `20260913170000_check_in_booking_rpc.sql` | COMPLETE |
| 9 | Receipts/invoices | COMPLETE (`receipts` feature, `booking_receipts` table, PDF) | demo | RPC-backed | COMPLETE |
| 10 | Owner/admin genuinely-missing features | owner registration, orgs, RLS bookings, section builder, cancellations | various | `complete_owner_registration`, owner RPCs | COMPLETE (no second backend ported) |
| 11 | Reports/analytics | PARTIAL (totals only) | daily/weekly reports | derived from existing `bookings` (RLS) | COMPLETE (daily/weekly summary card) |
| 12 | Other proven missing features | OSM/CORS-safe maps, push channels, web bridges | n/a | n/a | COMPLETE |

Legend: COMPLETE = production-ready on existing backend; PARTIAL = was incomplete.

## 2. Ported features (this pass)

1. **Book Again** — `my_bookings_screen.dart` + `canBookAgain` on completed/cancelled
   bookings; navigates into the normal booking flow with the venue refetched.
   No client-side booking insertion.
2. **Coupon validation hardening** — `booking_screen.dart` rejects expired coupons
   and below-minimum carts client-side; the confirm dialog states totals are
   settled server-side. Server remains the pricing authority.
3. **Masked contact + WhatsApp** — `venue_details_screen.dart` masks
   `contact_phone` until the signed-in customer has an owner-approved booking at
   that venue (`hasApprovedBookingForVenueProvider`); WhatsApp deep link
   (`wa.me`, external launch) added next to Call in both CTA bars.
4. **Owner daily/weekly reports** — `ownerReportSummaryProvider` derives
   today/this-week bookings + revenue from the same RLS-scoped `bookings` the
   dashboard already reads (revenue counts confirmed+completed only); rendered by
   a responsive `_ReportsCard` on the owner dashboard. No new backend required.

## 3. Backend-blocked features

- **Server-side coupon redemption audit trail per application** —
  `booking_coupons` exists and the server settles totals, but there is no RPC
  exposing per-customer coupon usage history; not simulated.
- **Owner-level payout/settlement reports** — no RPC/table exists for payouts;
  the dashboard uses real bookings instead. Not simulated.
- **Cross-platform push for iOS via Supabase** — FCM/APNs wiring exists natively;
  delivery to APNs requires server credentials outside this repo.

## 4. Unsafe/demo features excluded (never ported)

- Firebase/Firestore as a second production backend — excluded.
- Room/JSON local database as booking authority — excluded.
- Demo venues, fake prices, fake availability from the Android repo — excluded.
- Prototype payment confirmation / direct client booking insertion — excluded;
  the hold → approval → Razorpay webhook flow remains the only path.
- Hardcoded Android coupon list (`SAVE100` etc. against fake prices) — excluded.

## 5. Platform results (Android + iOS + Web)

| Check | Result |
|-------|--------|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ 730 passed (+1 skipped), 0 failed |
| `flutter build apk --release` | ✅ `app-release.apk` (94.8MB) |
| `flutter build web --release` | ✅ `build/web` |
| `flutter build ios --release --no-codesign` | ✅ `Runner.app` (52.4MB) |

Android: release build succeeds (fixed invalid `SpeechRecognizer` constants
`ERROR_AUDIO_ENCODING_FORMAT`/`ERROR_CREDENTIALS` → `ERROR_AUDIO`; permissions
and push/speech/Razorpay channels verified).
iOS: release build succeeds; all usage descriptions present in `Info.plist`
(location, camera, photos, microphone, speech, tracking); APNs/speech/Razorpay
channels verified.
Web: release build succeeds; Razorpay checkout.js, web-push, and speech bridges
present in `web/index.html`; maps use CORS-enabled CARTO tiles on web.
All devices: Material 3 breakpoint system (`ResponsiveLayoutBuilder`) verified
by layout tests from 320px phones through 1440px+ desktop/web windows; a
flutter_map attribution overflow at 320px was found and fixed (bounded,
ellipsizing attribution).

## 6. Remaining blockers

1. Coupon usage-history and payout RPCs (server-side work, see §3).
2. iOS push delivery needs APNs key/credentials configured server-side.
3. Live runtime verification on physical devices/emulators/simulator/Chrome
   should follow (this pass verified compilation, unit/widget tests, and
   platform configs; interactive runtime checks are a manual step).

## 7. Test policy note

No test was modified to hide a failure. `owner_dashboard_test` was updated to
scroll to below-the-fold content (the new reports card lengthened the page), and
`osm_tile_layer_test` was aligned with the current `OsmMapTiles` API after its
untracked version referenced removed getters. Both tests still assert real
behavior.
