# Google Maps Audit — BookMySpace (read-only, no code changed)

Date: 2026-09-21 · Branch: `fix/ios-bookmyspace-ui` · Backend: Supabase (untouched)

---

## 1. Did Google Maps exist previously?

**Yes — and it still exists in the current working tree.** It was never deleted; only its
API-key configuration was never completed (and the Web path was deliberately switched to OSM).

- Introduced in **`7164e96` "feat(payment): integrate Razorpay native payment"**, which added:
  - `pubspec.yaml`: `google_maps_flutter: ^2.7.0`
  - `lib/features/map/presentation/screens/venue_map_screen.dart` (593 lines, `GoogleMap`)
  - `ios/Runner/AppDelegate.swift` → `GMSServices.provideAPIKey(...)`
  - `web/index.html` → Google Maps JavaScript `<script>` tag
  - `test/features/map/venue_map_test.dart`
- Modified in **`d2bdb58` "fix(map): branch venue map on kIsWeb so Web gets FlutterMap not GoogleMap"**
  (Sep 13, 2026): the screen now branches — **FlutterMap (OSM/CARTO) on Web, GoogleMap on Android/iOS**.
  Its commit message claims "google_maps_flutter has no Web plugin" — that was inaccurate
  (an endorsed web implementation exists; see §4), but the branch is what makes Web work today.

## 2. Where it lives (branches)

`git log --all` shows the same history on every branch (`main`, `fix/ios-bookmyspace-ui`,
`final/bookmyspace-integrated`, `next-production-batch`, `reconcile-payment-ops`,
`phase5-14-release`, `fix/ios-bookmyspace-ui-buffy`, WIP backups). Nothing map-related is
unique to another branch or repo; the Android reference zip also lists
`google_maps_flutter: ^2.7.0` but its booking/maps are demo-local (already excluded per the merge rules).

**No key material was ever lost** — `git log --all -S "com.google.android.geo.API_KEY"` returns
**zero commits**. An Android manifest key never existed in this repo's history.

## 3. Current state & exact missing pieces

### Code present today (keep)
- `venue_map_screen.dart`: GoogleMap on native with markers, clustering, camera follow,
  zoom tracking, `myLocationEnabled: true`, list↔map selection sync; OSM on Web.
  Only file importing `google_maps_flutter` — contained blast radius.
- `google_maps_flutter 2.18.0` + platform impls locked: `_android 2.19.10`, `_ios 2.18.6`,
  `_web 0.6.3+1` (transitive), `flutter_map ^7` for the OSM path.

### Missing / broken configuration
| Platform | What exists | What's missing / broken |
|---|---|---|
| **Android** | Nothing | **No `com.google.android.geo.API_KEY` meta-data** in `android/app/src/main/AndroidManifest.xml` (never existed). No `manifestPlaceholders` in `build.gradle.kts`, no key property. **Result: the native map branch renders a blank grid + auth error.** |
| **iOS** | `AppDelegate.swift` calls `GMSServices.provideAPIKey(ProcessInfo.processInfo.environment["GOOGLE_MAPS_IOS_API_KEY"] ?? "default_maps_key")` | `ProcessInfo.environment` is only populated by the Xcode scheme / `flutter run` — **release/TestFlight builds fall back to the fake `default_maps_key`** → maps broken on device. No Info.plist key, no xcconfig injection. |
| **Web** | `<script src="https://maps.googleapis.com/maps/api/js?key=default_maps_key">` in `web/index.html` | Placeholder key → JS API errors in console. Mostly harmless today because the kIsWeb branch uses FlutterMap, but the script is loaded and unused; also stale for a future Web-Google option. |

## 4. Can Google Maps support Android / iOS / Web here?

- **Android — yes**, needs only the manifest key (plugin already locked and compiled into the APK).
- **iOS — yes**, needs a real key delivered to `provideAPIKey` before first map render.
- **Web — technically yes** (endorsed `google_maps_flutter_web 0.6.3+1` is already in the
  lockfile; it needs the Maps JavaScript API key in `index.html`). But the current OSM/CARTO
  Web branch works **without any key and without metered billing** — recommend keeping it
  (per your instruction) and only removing the dead/placeholder script tag later if desired.

## 5. Required API-key configuration (secure, no hardcoded secrets)

- **Android**: in `android/app/build.gradle.kts`, read a key from a **git-ignored**
  `gradle.properties` / CI env var and inject a placeholder:
  `manifestPlaceholders["googleMapsApiKey"] = System.getenv("GOOGLE_MAPS_ANDROID_API_KEY") ?: ""`
  → manifest: `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}"/>`.
  Keep the real key only in local `~/.gradle/gradle.properties` or CI secrets.
- **iOS**: stop using `ProcessInfo.environment` with a fake fallback. Add a git-ignored
  `ios/Flutter/GoogleMapsKey.xcconfig` defining `GOOGLE_MAPS_API_KEY = ...`, an Info.plist entry
  `GMSApiKey = $(GOOGLE_MAPS_API_KEY)`, and have AppDelegate read
  `Bundle.main.object(forInfoDictionaryKey:)` and call `provideAPIKey` only when set
  (release-safe; no committed secret).
- **Web (if ever switched)**: inject the key at build time in CI (template `index.html`) or via
  `--dart-define`-driven build step — never commit it. Dart `String.fromEnvironment` cannot
  reach native `GMSServices`/manifest, so dart-define alone is **not** sufficient for mobile.

## 6. Licensing / billing / restrictions

- **Mobile (Android+iOS): Google's Maps SDK mobile map loads are no-charge** — no per-load billing,
  but a Google Cloud project with the **Maps SDK for Android + iOS** APIs enabled and a billing
  account attached is still required.
- **Web (Maps JavaScript API) is metered** (free tier, then per 1,000 map loads) — a reason to keep OSM/CARTO on Web.
- Key hygiene: restrict each key — Android key by **package name + SHA-1**, iOS key by **bundle ID**,
  web key by **HTTP referrers**; restrict APIs to exactly the Maps SDKs used. Rotate the current
  placeholder strings out of the repo (`default_maps_key` is inert, but should not ship).

## 7. Recommended integration path (no implementation done yet)

1. **Keep the existing dual-engine design** (Google on native, OSM/CARTO on Web) — it already
   isolates `google_maps_flutter` to one screen and keeps Web key-free.
2. Add Android manifest meta-data + placeholder injection (§5) — the single real blocker for native.
3. Replace the iOS env-with-fallback with xcconfig/Info.plist delivery (§5).
4. Optionally drop or key-gate the placeholder Web script tag.
5. Verification afterwards: blank-grid fix on an Android emulator, iOS simulator with a debug
   scheme key, `flutter build apk/web/ios --no-codesign`, and confirm the OSM web path unchanged.
   No Supabase, booking, or DB changes are involved.

---

**Bottom line:** Google Maps was never lost — it's wired into `venue_map_screen.dart` on native.
What's missing is the API-key delivery on Android (manifest meta-data never existed) and iOS
(env-only, falls back to a fake key in release). Web intentionally uses OSM and needs no key.
No branch contains additional/lost Maps code; no keys were found or committed anywhere.
