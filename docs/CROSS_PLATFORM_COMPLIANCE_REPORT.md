# BookMySpace — Cross-Platform Compliance Audit

**Specification audited:** "CROSS-PLATFORM REQUIREMENT — MANDATORY"
**Repository:** `/Users/aa/Documents/BookMyspace_Andriod`
**Branch:** `fix/ios-bookmyspace-ui` (in sync with remote — divergence `0/0`)
**Flutter:** 3.41.6 stable · **Dart:** 3.11.4
**Audit date:** 2026-09-13

---

## 0. Verdict summary

> **NOT feature-complete. NOT cross-platform complete.**
> The build gate is fully green and the architecture is correct — one Flutter
> app, one shared backend, genuine per-platform adaptation where it matters
> (payments). But **four features are missing outright**, one feature is
> **broken by a missing backend contract**, and **the responsive requirement is
> met by 2 of 41 screens**.

The single most important finding is not a missing feature — it is that
**the QR check-in feature calls a server function that does not exist**, and
the error is swallowed into a user-facing "invalid code" message. That is a
silent production failure, not a gap in polish.

> ### Update — Batch A landed
>
> Items **A1–A4** from §6 are now implemented and the full gate is green again
> (analyze clean · 359 tests pass · web + Android + iOS all build).
>
> The matrix in §3 and the findings in §4 are **deliberately left as the
> pre-Batch-A audit baseline** — an audit that silently rewrites itself is not
> an audit. **See §8 for what changed, and for what is still open.**
>
> One caveat carried forward: the new `check_in_booking` migration is
> **written but not executed**. No local PostgreSQL or Docker daemon is
> available here, so it is **BLOCKED — NOT VERIFIED**, not PASS.

> ### Update — Batch B1 landed
>
> Real camera scanning now replaces the drawn viewfinder on all three
> platforms, and the pass is a **genuine QR symbol** rather than a
> QR-shaped drawing. Gate re-run green: analyze clean · **366 tests pass**
> (7 new) · web + Android + iOS all build.
>
> Two defects were found *while implementing* B1, neither visible from the
> original audit:
>
> 1. **The pass could never have scanned.** `QrCodePassWidget` hand-drew a
>    25×25 grid with no Reed–Solomon, no format/version information and no data
>    encoding. Installing a camera decoder without fixing the encoder would
>    have produced a scanner that reads nothing.
> 2. **The payload was too large to render scannably.** The full record is
>    428 bytes, which at quartile error correction needs a 93×93 module code —
>    1.9 px per module inside the pass, below what a phone camera resolves.
>
> **See §9.** The §3 matrix and §4 findings remain the pre-Batch-A baseline.

> ### Update — Batch B3 landed
>
> Android now has a real push implementation: a `android_push` MethodChannel
> mirroring the iOS `apns_push` contract, a notification channel, runtime
> `POST_NOTIFICATIONS` handling, action buttons, and pre-booking reminders that
> survive the app being closed. Gate re-run green: analyze clean · **378 tests
> pass** (12 new — the feature's first) · web + Android + iOS all build.
>
> Two more defects surfaced in the same feature, both of the same kind as the
> drawn QR code — a surface reporting success it had not earned:
>
> 1. **Android claimed a push permission it never probed.** The final `else` in
>    both permission methods returned `granted` for anything that was not Web or
>    iOS, which hid the "Enable notifications" button on a platform with no push
>    at all.
> 2. **iOS fabricated a device token.** When APNs had not delivered one, it
>    generated an `apns_sim_…` placeholder that Dart registered with Supabase as
>    a real delivery address.
>
> **Remote push was not faked.** It needs a Firebase project file *and* a sender,
> and this repository has neither, so Android is **local-only** and says so in
> the UI. **See §10** for what was verified, and how.

> ### Update — Batch B2 landed
>
> Itemized receipts now exist end to end: a server RPC that freezes an immutable
> snapshot, a client document model, a **real PDF** with an embedded font, and a
> screen with save/share. Gate re-run green: analyze clean · **419 tests pass**
> (41 new) · web + Android + iOS all build.
>
> Three things were **not** implemented, because the data does not exist, and the
> document says so rather than inventing them:
>
> 1. **Platform fees are not printed.** `public.platform_commissions` is created
>    by the schema and **has no writer anywhere**. A "Platform fee 0.00" line on a
>    tax document asserts a fact nobody recorded.
> 2. **No tax rate is asserted.** The venue's rate is shown as a reference only.
>    Re-deriving tax from it would let a later price edit rewrite a document that
>    has already been issued.
> 3. **A booking with no captured payment gets a *statement*, not a receipt.**
>    It carries no receipt number, and the title and a note both say why.
>
> The PDF work also uncovered a silent-corruption defect: the PDF base-14 fonts
> **cannot draw `₹`** and substitute a missing-glyph box, so a receipt for ₹1,770
> would have printed as `□1,770.00`. **See §11.**

### Legend

| Verdict | Meaning |
| --- | --- |
| **PASS** | Implemented **and** verified by the evidence cited. |
| **BLOCKED — NOT VERIFIED** | Implemented, compiles and builds, but runtime behaviour could not be exercised in this environment. Per the spec, this is **not** a pass. |
| **FAIL** | Missing, or present but incorrect. |

Nothing in this report is marked PASS on the basis of "the Dart code compiles"
alone, which the specification explicitly forbids.

---

## 1. Build gate — all five stages green

Run with the mandated proxy-unset prefix. Full output: `/tmp/bms_gate.log`.

| Stage | Command | Result |
| --- | --- | --- |
| Analyze | `flutter analyze` | ✅ **No issues found!** (4.7s) |
| Test | `flutter test` | ✅ **All tests passed!** — 359 tests, 65 files |
| Build Web | `flutter build web --release` | ✅ **Built `build/web`** |
| Build Android | `flutter build apk --debug` | ✅ **Built `app-debug.apk`** |
| Build iOS | `flutter build ios --debug --no-codesign` | ✅ **Built `ios/iphoneos/Runner.app`** |

### Advisories from the gate (none block the build)

1. **WASM is not reachable.** The web build's wasm dry-run reports
   `flutter_secure_storage_web` importing `dart:html` / `dart:js_util`, which
   WASM does not support. The web target therefore ships as **JavaScript**, not
   WASM. Acceptable today; it caps future web performance work.
2. **iOS UIScene lifecycle migration is coming.** Xcode warns it "will soon be
   required". Not a defect yet — a dated obligation.
3. **`cupertino_icons` font is referenced but not declared.** The build warns it
   expected `packages/cupertino_icons/CupertinoIcons` but found only
   `MaterialIcons`. Any `CupertinoIcons.*` usage will render as a missing glyph.
4. **52 packages are pinned behind newer releases** by dependency constraints.

---

## 2. Architecture compliance — PASS

| Requirement | Status | Evidence |
| --- | --- | --- |
| **ONE Flutter application** | ✅ PASS | `android/`, `ios/`, `web/` only. `macos/`, `linux/`, `windows/` absent. |
| **No separate Kotlin/Compose app** | ✅ PASS | No second Android app module. |
| **No separate React/Web app** | ✅ PASS | Web is Flutter Web (`build/web`), not a JS app. |
| **Mandated stack** | ✅ PASS | Riverpod 2.5.1 · GoRouter 14.2 · Supabase Flutter 2.5 · intl 0.20. |
| **No rebuild / extend existing** | ✅ PASS | 204 Dart files, 45,216 lines, 41 screens — evolved, not replaced. |
| **Frozen files untouched** | ✅ PASS | `category_glass_matrix.dart` 639 lines · `home_category_catalog.dart` 401 lines. Both present, contents unmodified. |
| **Server-authoritative backend** | ✅ PASS | 8 Edge Functions + ~60 RPCs, including `acquire_venue_hold`, `release_venue_hold`, `expire_stale_holds`, `confirm_venue_booking`, `approve/reject/cancel_venue_booking`, `reconcile_stale_payments`, `register_webhook_event`. |
| **No service secrets in the client** | ✅ PASS | No service-role key or Razorpay secret in `lib/`. Checkout receives only the public `keyId`. |

> **Note on the corporate marketing site.** The `website/` directory added in the
> previous session is a *marketing site*, not a second application. It contains
> no product logic and shares no code with the app. The "do NOT create a
> separate React/Web application" rule targets the product app and is not
> violated — but it is a separate, non-Flutter deliverable and is called out
> here so the distinction is explicit rather than assumed.

---

## 3. The mandated FEATURE × PLATFORM matrix

| # | Feature | Android | iOS | Web |
| --- | --- | --- | --- | --- |
| 1 | App shell · 6-tab nav · GoRouter | **PASS** | **PASS** | **PASS** |
| 2 | Home feed · category matrix (frozen) | **PASS** | **PASS** | **PASS** |
| 3 | Authentication (OTP / Google / Apple) | BLOCKED | BLOCKED | BLOCKED |
| 4 | Payments — Razorpay checkout | BLOCKED | BLOCKED | BLOCKED |
| 5 | Payment server authority (webhook/verify) | BLOCKED | BLOCKED | BLOCKED |
| 6 | **Push notifications** | **FAIL** | BLOCKED | BLOCKED |
| 7 | Digital QR pass (display) | **PASS** | **PASS** | **PASS** |
| 8 | **QR scanner (camera capture)** | **FAIL** | **FAIL** | **FAIL** |
| 9 | **Check-in verification** | **FAIL** | **FAIL** | **FAIL** |
| 10 | **Invoicing / GST** | **FAIL** | **FAIL** | **FAIL** |
| 11 | **PDF generation / export** | **FAIL** | **FAIL** | **FAIL** |
| 12 | **Calendar / ICS export** | **FAIL** | **FAIL** | **FAIL** |
| 13 | **File share / download** | **FAIL** | **FAIL** | **FAIL** |
| 14 | **Venue map screen** | BLOCKED | BLOCKED | **FAIL** |
| 15 | Venue-details mini map | BLOCKED | BLOCKED | **PASS** |
| 16 | Geolocation / GPS | BLOCKED | BLOCKED | BLOCKED |
| 17 | Multilingual (en · te · hi · kn · ta) | **PASS** | **PASS** | **PASS** |
| 18 | **Responsive UI (320→1440+)** | **FAIL** | **FAIL** | **FAIL** |
| 19 | Accessibility (48dp, semantics) | NOT AUDITED | NOT AUDITED | NOT AUDITED |
| 20 | **Platform-parity test coverage** | **FAIL** | **FAIL** | **FAIL** |

**Score: 6 PASS · 8 BLOCKED · 12 FAIL** (of 20 feature rows × 3 platforms where
applicable).

---

## 4. Detailed findings

### 4.1 FAIL — QR scanner is a drawing, not a camera

**Severity: critical (functional misrepresentation on all three platforms).**

There is no camera package in `pubspec.yaml` — no `camera`, no
`mobile_scanner`, no `qr_code_scanner`. The scanner screen renders a
`CustomPaint` reticle with an animated laser line:

- `lib/features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart:179–271`
  — the "Camera Viewfinder Box" is a `Card` with `color: Color(0xFF121212)`
  containing `_ViewfinderReticlePainter` (defined at line 684).
- Torch and flip-camera buttons mutate local state only:
  `qr_checkin_providers.dart:54–60` (`toggleTorch`, `toggleCamera`). No hardware
  is touched.
- The "Test Scan" button calls `_performCheckIn('BMS-883921')` — **a hardcoded
  booking reference** (`qr_check_in_scanner_screen.dart:261`). This violates the
  project's own rule *"DO NOT introduce fake production data"*.

The screen's header claims **"Supabase DB Live Link"** and **"Supabase Active"**
(line 84, line 114). For the camera path that claim is not true.

**What is genuinely fine:** the *manual code entry* path is real — it reaches
the repository (see 4.2).

### 4.2 FAIL — `check_in_booking` RPC does not exist

**Severity: critical (silent runtime failure).**

`lib/features/booking/infrastructure/supabase_booking_repository.dart:295–298`
invokes:

```dart
final response = await _client.rpc(
  'check_in_booking',
  params: {'p_code': code, 'p_method': 'qr'},
);
```

**There is no `check_in_booking` function anywhere in `supabase/`.** A
case-insensitive search for `check_in|checkin|checked_in` across the whole
`supabase/` tree returns exactly one hit — an unrelated comment in
`20260912210000_booking_approval_legacy_rpc_hardening.sql`.

Cross-checking every RPC the client calls against the schema:

| RPC called from `lib/` | Exists in schema? |
| --- | --- |
| `approve_venue_booking` | ✅ yes |
| `reject_venue_booking` | ✅ yes |
| `cancel_venue_booking` | ✅ yes |
| `reorder_category_catalog` | ✅ yes |
| `reorder_category_subsections` | ✅ yes |
| **`check_in_booking`** | ❌ **MISSING** |

**Why this is worse than a plain gap:** the call is wrapped in a broad
`catch (e)` (`qr_checkin_providers.dart:97–105`) that discards the exception and
always returns *"Invalid QR code or booking reference. No active booking found."*
So a schema/contract failure is reported to the user as their own input error.
Nobody will ever see the real cause in the UI.

**Fix direction:** add the `check_in_booking` RPC in a new migration with the
project's existing conventions (signed-token verification, replay prevention,
already-used detection, venue mismatch detection, actor + timestamp audit), and
narrow the client `catch` so contract errors are distinguishable from bad input.

### 4.3 FAIL — Push notifications missing on Android

`push_notification_service.dart:82–86`:

```dart
if (kIsWeb) {
  await _initializeWeb();
} else if (!kIsWeb && Platform.isIOS) {
  await _initializeIos();
}
```

There is **no Android branch.** The class documentation itself says
"Central Push Notification Service for BookMySpace Flutter **(iOS & Web)**".

- **iOS ✅ implemented** — APNs via `MethodChannel('…/apns_push')`, handled in
  `ios/Runner/AppDelegate.swift`.
- **Web ✅ implemented** — `web/sw.js` + `web/index.html:402` (service worker
  registration), `:493` (`Notification.requestPermission`), `:502–510`
  (`PushManager` subscription).
- **Android ❌ missing** — `android/…/MainActivity.kt` implements **only** the
  Razorpay channel (`openCheckout`); every other method returns
  `notImplemented()`. No FCM, no Firebase Messaging, no Android push channel.

The domain model already reserves the value — `push_notification_types.dart:21`
documents `'ios' | 'web' | 'android'` — so the Android case is anticipated but
never wired.

### 4.4 FAIL — Invoicing and GST: nothing implemented

The word "invoice" appears exactly twice in all of `lib/`:

1. `app_localizations.dart:188` — a marketing sentence
   (*"Pay securely with instant tax invoices…"*).
2. `qr_check_in_scanner_screen.dart:511` — a SnackBar reading
   **"Invoice & QR pass ready for #…"**, triggered by a button whose only action
   is `ScaffoldMessenger.showSnackBar`. **There is no invoice.** This is a false
   claim shown to users.

No invoice model, no invoice numbering, no sequence/uniqueness guarantee, no
CGST/SGST/IGST split, no SAC classification, no credit notes.

What exists is adjacent but not invoicing:

- `gstin` is a **text field on owner registration**
  (`owner_registration_screen.dart:151–154`, persisted via
  `supabase_owner_repository.dart:166–182`) — it captures the owner's number, it
  does not compute tax.
- `payment_screen.dart:317` shows a static label `'GST & Platform Fee (18%)'` —
  a display string, not a tax engine.

### 4.5 FAIL — PDF, calendar/ICS and share/download: zero implementation

| Capability | Search result |
| --- | --- |
| PDF generation | `pdf` / `Pdf` / `PDF` → **0 hits** in `lib/` |
| Printing | `printer` / `Printing` → **0 hits** |
| Share | `share_plus` / `Share.` / `shareXFiles` → **0 hits** |
| Calendar / ICS | `.ics` / `calendar` → 4 hits, **all Material icon names** (`Icons.calendar_today` etc.), no export logic |
| Download | 1 hit — an `Icons.download` on the no-op "Pass Info" button |

Consequently the specification's per-platform file/PDF rows
(Android → download/share, iOS → share/save, Web → browser download/preview)
have **no implementation to be platform-adaptive about**.

### 4.6 FAIL — Venue map screen cannot work on Web

`lib/features/map/presentation/screens/venue_map_screen.dart:517` constructs
`GoogleMap(` unconditionally — there is no `kIsWeb` branch in the file.
`google_maps_flutter` has no Flutter Web support, so this screen cannot render
on Web.

By contrast, `venue_details_screen.dart` uses `FlutterMap`, which **is**
web-capable — so the details mini-map is fine and the failure is isolated to
the full map screen. That asymmetry is exactly the kind of platform gap the
specification's matrix is designed to catch.

### 4.7 FAIL — Responsive UI adopted by 2 of 41 screens

`lib/core/widgets/responsive_layout.dart` is genuinely good: Material 3 window
size classes at 600 / 840 / 1200 dp, per-class column counts and aspect ratios,
adaptive padding, and a 1280 px max content width.

**It is imported by 2 files:** `home_screen.dart` and `profile_screen.dart`.

Across 204 files and 45,216 lines:

| Primitive | Occurrences | Files |
| --- | --- | --- |
| `LayoutBuilder` | 8 | 6 |
| `MediaQuery` | 19 | 11 |
| `SafeArea` | 23 | 19 |
| `ConstrainedBox` | 5 | 5 |
| `SingleChildScrollView` | 20 | 14 |

Against a requirement that **every screen** support 320–430 / 600–1024 / 1024+ /
1440+, roughly 5% adoption is not close. The infrastructure exists — the gap is
application, which makes this the cheapest large win available.

### 4.8 FAIL — No platform-parity or responsive test coverage

**0 of 65 test files** mention `kIsWeb`, `TargetPlatform`, `responsive`,
`breakpoint` or `MediaQuery`. The specification requires each feature to be
*intentionally tested on each supported platform*; nothing in the suite does
this.

The one QR test is a build smoke test —
`test/features/qr_checkin/qr_check_in_scanner_screen_test.dart` asserts only
that the screen builds and that the two tabs switch labels. It passes against
the simulated scanner and would pass just as happily if the scanner were
deleted.

---

## 5. BLOCKED — NOT VERIFIED (runtime)

These are implemented in code and build cleanly, but could not be exercised.
Per the specification these are **not** passes.

| Capability | Why blocked |
| --- | --- |
| Authentication (OTP, Google, Apple) | Only `.env.*.example` templates exist. No real `.env.dev`, so `flutter run` halts at "missing hosted Supabase configuration". Credentials were **not** fabricated. |
| Payments E2E — all 3 platforms | No Razorpay key; the client throws `ConfigurationException('razorpay_not_configured')` when `keyId` is empty or contains `PLACEHOLDER`. No device, no browser session. |
| Web Push delivery | Needs VAPID keys plus a live browser. |
| iOS APNs delivery | Needs a physical device and an APNs certificate. |
| Geolocation / GPS | Needs device permission prompts. |
| Maps (all platforms) | `web/index.html:28` uses `key=default_maps_key`; no real Maps key configured. |
| Simulator screenshots | Credential-blocked by the same `.env` gap as authentication. |

**Payments deserve a specific note.** The code is the strongest part of this
repository's cross-platform work and is genuinely three-platform:

- **Android** — `android/…/MainActivity.kt:12–97`: `PaymentResultWithDataListener`,
  `Checkout().open(this, options)`, correct `PAYMENT_CANCELED` handling.
- **iOS** — `ios/Runner/AppDelegate.swift:38–176`: channel
  `com.bookmyspace.bookmyspace/razorpay_native`,
  `RazorpayCheckout.initWithKey(_:andDelegateWithData:)`, returns
  `razorpay_payment_id` / `_order_id` / `_signature`.
- **Web** — `web/index.html:31` loads `checkout.razorpay.com/v1/checkout.js`;
  `:437–483` reads the three Razorpay response fields and fails honestly with
  `errorCode: 'web_checkout_unavailable'` if the script is absent.
- **Client** — `native_razorpay_checkout_service.dart` validates input, refuses a
  `PLACEHOLDER` key, and degrades to an explicit failure on
  `MissingPluginException` rather than pretending success.

It is blocked on credentials only — which is the correct reason for a
BLOCKED verdict, not a FAIL.

---

## 6. Prioritised remediation plan

Ordered by severity, batched as the specification's checkpoint model requires
(*implement → test → analyze → build Android/iOS/Web → inspect diff → verify
frozen files → commit only own files*).

### Batch A — correctness and honesty (do first)

| # | Item | Why first |
| --- | --- | --- |
| A1 | Add the missing `check_in_booking` RPC migration + narrow the client `catch` so contract errors surface | A shipped feature is silently broken today |
| A2 | Remove the hardcoded `'BMS-883921'` test-scan path | Violates the project's own no-fake-data rule |
| A3 | Remove or implement the false "Invoice & QR pass ready" SnackBar | Actively misleading to users |
| A4 | Stop advertising "Supabase DB Live Link / Supabase Active" on the camera tab | The camera path is not live |

### Batch B — the missing features

| # | Item | Notes |
| --- | --- | --- |
| B1 | Real camera scanning via `mobile_scanner`, with a Web fallback | Unblocks items 8 across all three platforms at once |
| B2 | Invoice/GST engine + PDF + email | Largest single build; server-side tax computation, transactional numbering |
| B3 | Android push (FCM) | Closes the only platform asymmetry in notifications |
| B4 | `kIsWeb` branch on the venue map screen | Small change, one clear FAIL |
| B5 | Calendar/ICS export and file share | Needed for the per-platform file/PDF rows |

### Batch C — reach and assurance

| # | Item | Notes |
| --- | --- | --- |
| C1 | Extend `ResponsiveLayoutBuilder` across the remaining 39 screens | Infrastructure already exists — highest value per unit of effort |
| C2 | Add platform-parity and responsive widget tests | Makes the matrix above *automated* rather than manual |
| C3 | Accessibility audit — 48 dp targets, semantics, contrast | Currently unmeasured |
| C4 | Configure `.env.dev` + Razorpay/Maps/VAPID keys | Converts most BLOCKED rows into real verification |
| C5 | Plan the iOS UIScene migration | Dated obligation from Xcode |

---

## 7. Method and limits of this audit

**What was verified:** the full five-stage build gate; git state and branch
divergence; integrity of both frozen files; the complete RPC surface called from
`lib/` cross-checked against `supabase/`; per-platform implementation of
payments, push, QR and maps by reading the Dart, Kotlin, Swift and JS sources;
responsive-primitive distribution across all 204 Dart files; and test-suite
coverage for platform concerns.

**What was not verified:** anything requiring credentials, a device or a
browser. No `.env.dev` exists, and credentials were deliberately **not**
fabricated to force a run. Every such row is marked BLOCKED — NOT VERIFIED
rather than PASS, as the specification requires.

**Nothing in this report is inferred from a file name or a comment.** Each
finding cites the line that establishes it. Where a comment contradicted the
code — the scanner's "Supabase Active" badge, the "Invoice ready" SnackBar —
the code was treated as authoritative and the comment as a defect.

---

## 8. Batch A — implemented

Scope: correctness and honesty only. No new features, no camera work.

### 8.1 What changed

| Item | Change | File |
| --- | --- | --- |
| **A1a** | New `public.check_in_booking(p_code, p_method, p_venue_id)` — the missing server transition. Adds `checked_in_at` / `checked_in_by` / `check_in_method` columns, authorises guest **or** venue owner **or** platform admin, detects cancelled, refunded, replayed, wrong-venue and invalid-status passes, guards the write so a race admits exactly one scanner, writes an `audit_logs` row, and notifies the guest only when someone *else* admitted them. | `supabase/migrations/20260913170000_check_in_booking_rpc.sql` (new) |
| **A1b** | The repository now surfaces the server's own `message` / `error_code` instead of collapsing every outcome into a generic "not found", and reports a replayed pass as `booking_already_checked_in` rather than as a successful check-in. | `lib/features/booking/infrastructure/supabase_booking_repository.dart` |
| **A1c** | The provider catches `AppException` first and shows the server's reason; only genuinely unexpected failures fall through to a generic message. The blanket "Invalid QR code or booking reference" is gone. | `lib/features/qr_checkin/presentation/qr_checkin_providers.dart` |
| **A2** | The hardcoded `'BMS-883921'` test-scan path is gone. The action now checks in the guest's **own** confirmed booking by reference, and does nothing when there is nothing to check in. The fabricated example in the manual-input hint is gone too. | `qr_check_in_scanner_screen.dart` |
| **A3** | The false *"Invoice & QR pass ready"* SnackBar is replaced by the one true statement — the pass reference — and the button is relabelled **Pass Ref** with an info icon. No download icon remains on a button that downloads nothing. | `qr_check_in_scanner_screen.dart` |
| **A4** | The **"Supabase Active"** badge and the **"Supabase DB Live Link"** subtitle are removed. The viewfinder overlay no longer instructs the guest to frame a code that cannot be read; it states that camera scanning is not available yet and points at manual entry. The simulated Torch / Flip controls are removed rather than left as dead affordances. | `qr_check_in_scanner_screen.dart` |

### 8.2 Gate re-run — all five stages green

| Stage | Result |
| --- | --- |
| `flutter analyze` | ✅ **No issues found!** (4.0s) |
| `flutter test` | ✅ **All tests passed!** — 359 tests |
| `flutter build web --release` | ✅ Built `build/web` |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` |
| `flutter build ios --debug --no-codesign` | ✅ Built `ios/iphoneos/Runner.app` |

Full log: `/tmp/bms_gate_batchA.log`.

### 8.3 Guardrails verified

- **Frozen files byte-identical** — `category_glass_matrix.dart`
  `91a9246eca233e16` and `home_category_catalog.dart` `5388c0be3fe4f72e`,
  matching the hashes taken before any change.
- **Diff reviewed, not just reported:** 3 files modified, **66 insertions / 85
  deletions** — the change is net-negative in size because simulated UI was
  removed rather than added.
- **No commit made.** Per the repository rule, commits require explicit
  instruction.

### 8.4 Still open after Batch A

1. **The migration is unexecuted.** No local PostgreSQL (`psql` absent) and the
   Docker daemon is not running, so the SQL was reviewed and structurally
   checked (balanced dollar-quotes, parens, one function, grants matching
   convention) but **never run**. Until it is applied and exercised against a
   real database, check-in remains **BLOCKED — NOT VERIFIED**. The client is now
   *correct* either way: if the function is missing, the guest sees the real
   error instead of a fabricated "invalid code".
2. ~~**The viewfinder is still a preview, not a camera.**~~ **Resolved by B1** —
   see §9. The preview is now a live camera on all three platforms.
3. ~~**Dead scanner state remains.**~~ **Resolved by B1.** `toggleTorch`,
   `toggleCamera`, `isTorchOn` and `isFrontCamera` were deleted along with
   `_ViewfinderReticlePainter`. Torch and camera-flip are now driven by the
   real controller's state, and only appear for capabilities the running camera
   actually reports.
4. **The QR test is still a smoke test.** It asserts the screen builds and the
   tabs switch. Now that a real server contract exists, a test that drives
   `check_inWithCode` against the mock repository — including the
   already-used and cancelled paths — is worth adding (**C2**).
5. **Batches B and C are otherwise untouched:** Android FCM push, the `kIsWeb`
   branch on the venue map screen, the invoice/PDF/ICS/share features,
   responsive adoption across the remaining 39 screens, and the accessibility
   audit. (Real camera scanning, listed here originally, is now done — §9.)

---

## 9. Batch B1 — real camera scanning and a real QR pass

**Status: implemented and gate-verified. Check-in remains `BLOCKED — NOT
VERIFIED` end-to-end**, because the camera and the migration cannot be
exercised in this environment. Details in §9.5.

### 9.1 What changed

| File | Change |
| --- | --- |
| `pubspec.yaml` | Added `mobile_scanner: ^7.4.1` (camera decoding) and `qr: ^4.0.0` (pass encoding). `pub get` reported *"Changed 1 dependency"* for `qr` — the deliberate `intl: ^0.20.2` pin was untouched. |
| `lib/features/qr_checkin/presentation/widgets/qr_camera_scanner.dart` | **New.** Owns the `MobileScannerController`, starts it under a guard, renders the preview with an honest fallback, and exposes torch/flip only for capabilities the running camera reports. |
| `.../screens/qr_check_in_scanner_screen.dart` | The `CustomPaint` reticle block and `_ScannerCircleButton` are gone; a live `QrCameraScanner` takes their place. `_ViewfinderReticlePainter` deleted. |
| `.../widgets/qr_code_pass_widget.dart` | The hand-drawn matrix is replaced by a real `QrImage` from the `qr` package, with a four-module quiet zone and a correctly centred brand badge. |
| `.../domain/qr_check_in.dart` | Added `toQrPayloadString()` — the compact payload actually encoded. `issuedAt` now comes from `booking.createdAt` instead of `DateTime.now()`, so a pass is stable across rebuilds. |
| `.../presentation/qr_checkin_providers.dart` | Deleted `isTorchOn`, `isFrontCamera`, `toggleTorch`, `toggleCamera`. They drove nothing real. |

No Android or iOS build configuration needed changing: Flutter 3.41.6's defaults
are `compileSdk 36` / `minSdk 24` / `targetSdk 36`, and `mobile_scanner` requires
`compileSdk 36` / `minSdk 23`; the iOS deployment target is already 14.0 against
a podspec asking for 12.0.

### 9.2 Defect found — the pass was never scannable

`QrCodePassWidget` did not encode a QR code. It painted a 25×25 grid with
plausible-looking finder patterns, timing strips and an alignment pattern, then
filled the "data modules" from a hash:

```dart
final bit = ((byte ^ (hash >> (r % 16))) + (r * 7) + (c * 13)) % 3 == 0;
```

No Reed–Solomon parity, no format information, no version information, no data
encoding. It was a picture of a QR code. Adding a camera decoder without fixing
the encoder would have produced a scanner that reads nothing — the two halves
had to land together.

### 9.3 Defect found — the payload was too large to render scannably

Measured with the real encoder before choosing a format:

| Payload | Bytes | @ ECC L | @ ECC M | @ ECC Q | @ ECC H |
| --- | --- | --- | --- | --- | --- |
| Full record (previous) | 428 | v14 (73) 2.4px | v16 (81) 2.2px | v19 (93) 1.9px | v22 (105) 1.7px |
| **Compact (chosen)** | **76** | v4 (33) 5.3px | v5 (37) 4.8px | **v7 (45) 3.9px** | v8 (49) 3.6px |

*(px per module inside the 200 px pass. `v` = QR version, `(n)` = modules per
side.)*

At 105 modules the pass is 1.7 px per module — physically smaller than a phone
camera can resolve. So the pass now encodes `toQrPayloadString()`:
`{"t":"BOOKING_CHECK_IN","booking_id":"…"}`, at quartile error correction. That
is 45×45 modules at 3.9 px per module, and quartile's ~25% recovery budget pays
for the brand badge (25 of 2025 modules) plus real-world glare.

Nothing is lost. `check_in_booking` resolves the booking server-side and returns
the venue, slot and times, so a self-describing pass would only carry data that
can go stale between issue and scan. `SupabaseBookingRepository._bookingCode`
already reads `booking_id` out of exactly this map.

### 9.4 Verification

**Gate — all five stages green.**

| Stage | Result |
| --- | --- |
| `flutter analyze` | ✅ No issues found! (4.7s) |
| `flutter test` | ✅ **All tests passed! — 366 tests** (was 359; 7 new) |
| `flutter build web --release` | ✅ Built `build/web` |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` |
| `flutter build ios --debug --no-codesign` | ✅ Built `ios/iphoneos/Runner.app` |

**The strongest new test rasterises the pass and compares it module for module
against an independently encoded symbol** — 2001 of 2025 modules sampled (the
badge area is excluded), zero mismatches. It reads the painter's real geometry
from the render objects rather than assuming it, and that is how it caught a
genuine bug: `_paintBrandBadge` omitted the quiet-zone offset and drew the badge
four modules up and to the left of centre. Fixed in the same batch.

The other tests cover payload stability and size, the presence of the mandatory
finder patterns, that two bookings produce different symbols, that a host with
no camera explains itself and keeps manual entry reachable, and that manual
submission still runs.

**A trap worth recording.** `MobileScannerController.start()` does not fail
usefully on a host without the plugin: it **never completes and never throws**.
Measured directly — still pending after four seconds, with `value.error` null and
no exception raised. `MobileScanner`'s own `autoStart` calls it from `initState`
with no `try`/`catch` and no deadline, so the viewfinder would sit dark forever.
The widget therefore owns the start call and applies a six-second deadline, which
turns a wedged camera service into an explanation instead of a black rectangle.

### 9.5 Still BLOCKED after B1

1. **No camera has ever run.** The widget tests exercise the failure path
   because no camera plugin exists in the test host. Decoding a real pass with a
   real lens is **BLOCKED — NOT VERIFIED** until it is tried on a device.
2. **The `check_in_booking` migration is still unexecuted** (§8.4) — no local
   PostgreSQL and no Docker daemon.
3. **Web scanning has a runtime CDN dependency.** `mobile_scanner`'s web
   implementation fetches `zxing-wasm` 3.1.3 from a CDN at scan time, and
   browsers only grant camera access in a secure context (HTTPS or localhost).
   A strict CSP or an offline deployment would break Web scanning while Android
   and iOS keep working — an asymmetry the platform matrix should show once it
   is next revised.
4. **The §3 matrix is not yet updated.** It still reads FAIL for rows 8 and 9 as
   the pre-Batch-A baseline. The honest new value for *QR scanner (camera
   capture)* is **BLOCKED — NOT VERIFIED on all three platforms**, not PASS.

## 10. Batch B3 — Android push, and an honest capability report

Android was the one platform with **no push implementation at all**: every
`show*Push` call fell through both platform branches and did nothing, while iOS
and Web raised real system notifications. B3 closes that — and closes a second
defect found inside the same feature.

### 10.1 What changed

| File | Change |
| --- | --- |
| `android/app/src/main/kotlin/.../AndroidPushChannel.kt` | **New.** MethodChannel handler mirroring the iOS `apns_push` contract. |
| `android/app/src/main/kotlin/.../PushNotifications.kt` | **New.** Channel creation, notification building, payload serialisation. |
| `android/app/src/main/kotlin/.../PushAlarmReceiver.kt` | **New.** `BroadcastReceiver` that posts a scheduled reminder. |
| `android/app/src/main/res/drawable/ic_notification.xml` | **New.** Monochrome small icon. |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Attaches the channel; forwards `onNewIntent` and `onRequestPermissionsResult`. |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS`; the alarm receiver. |
| `android/app/build.gradle.kts` | `androidx.core:core-ktx`, explicit — this build has no version catalog. |
| `lib/features/notifications/infrastructure/push_notification_service.dart` | Android branch; one shared `_presentSystemNotification`; honest permission fallback; `transportLabel`; `isLocalNotificationsOnly`. |
| `lib/features/notifications/presentation/screens/notifications_screen.dart` | Transport label now comes from the service; explains a local-only build. |
| `ios/Runner/AppDelegate.swift` | `getApnsToken` no longer fabricates a token. |
| `test/features/notifications/push_notification_service_test.dart` | **New.** 12 tests — the feature's first. |
| `pubspec.yaml` | `flutter_secure_storage_platform_interface` in `dev_dependencies`. |

The four `show*Push` methods and the reminder path each carried their own
`if (kIsWeb) … else if (Platform.isIOS) …` block. Those are now a single
`_presentSystemNotification` helper, so Android was added in **one** place and
the diff is net-simpler rather than more repetitive.

### 10.2 Defect found — Android claimed a capability it did not have

`requestPermission()` and `getPermissionStatus()` both ended in:

```dart
} else {
  _permissionStatus = PushPermissionStatus.granted;
  return _permissionStatus;
}
```

That `else` catches Android — and anything else that is neither Web nor iOS. So
Android reported **granted** without ever probing anything, and the notifications
screen consequently hid its "Enable System Push Notifications" button on a
platform where push did not exist at all. The fallback now returns the unprobed
status, so the UI can no longer be misled.

This is the same class of defect as the QR pass being a drawing: a surface
reporting a success it has not earned.

### 10.3 Defect found — iOS fabricated a device token

```swift
let token = self.apnsDeviceToken ?? "apns_sim_\(UUID().uuidString.prefix(12).lowercased())"
```

When APNs had not delivered a token, iOS invented one, and Dart registered it
with Supabase as a real delivery address. Any server sending to that token would
fail, so "device registered" meant nothing. It now returns an empty string, which
Dart already treats as "not registered yet".

### 10.4 The line this batch did not cross

Android **local** notifications need nothing but the Android SDK, so they are
implemented for real: permission handling, notification channel, immediate
display, action buttons, and reminders that survive the app being closed
(`AlarmManager`, deliberately inexact — a "starts in an hour" reminder tolerates
drift, and `setExact*` would require `SCHEDULE_EXACT_ALARM`, which Play restricts
to alarm-clock apps).

**Remote push was deliberately not faked.** A server-delivered message needs two
things this repository does not have:

1. a Firebase project file (`android/app/google-services.json`), and
2. a sender — there is **no** server-side push sender; `supabase/functions/`
   holds only the eight functions listed in §7.

Adding the `com.google.gms.google-services` plugin without (1) hard-fails the
Gradle build, and adding `firebase-messaging` without it yields a dependency that
can never initialise. Neither is verifiable here, so the channel instead reports
`remotePushConfigured: false` — and that value is *checked* (the `google_app_id`
resource the plugin generates, plus the messaging classes on the classpath)
rather than hardcoded, so dropping in the file and the dependency flips it
automatically.

### 10.5 Verification

**Gate — all five stages green.**

| Stage | Result |
| --- | --- |
| `flutter analyze` | ✅ No issues found! (7.0s) |
| `flutter test` | ✅ **All tests passed! — 378 tests** (was 366; 12 new) |
| `flutter build web --release` | ✅ Built `build/web` (46.8s) |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` (16.8s) |
| `flutter build ios --debug --no-codesign` | ✅ Built `ios/iphoneos/Runner.app` (19.5s) |

The APK builds **without** `google-services.json`, which is the specific trap
this batch had to avoid.

**The Kotlin is verifiably in the shipped artifact.** "It compiled" is not
enough, so the APK itself was inspected:

| Checked | Where | Result |
| --- | --- | --- |
| `POST_NOTIFICATIONS` | binary `AndroidManifest.xml` | present |
| `PushAlarmReceiver` | binary `AndroidManifest.xml` | present |
| `com.bookmyspace.bookmyspace/android_push` | DEX | present |
| `bookmyspace_push` (channel id) | DEX | present |
| `getInitialNotification`, `onNotificationClicked` | DEX | present |
| `setAndAllowWhileIdle` | DEX | present |
| `ic_notification` | `resources.arsc` | present |

Channel names, channel ids and method names live in the DEX rather than the
manifest, so a manifest-only check reports false negatives for exactly those.

**The permission guard is proven, not assumed.** Restoring the old `granted`
fallback makes exactly two of the twelve new tests fail and leaves the other ten
passing — so the guard genuinely catches the defect instead of merely describing
it.

### 10.6 Still BLOCKED after B3

1. **No Android notification has ever been displayed.** No device or emulator is
   attached, so the Kotlin runs only as far as compilation and artifact
   inspection. Android push remains **BLOCKED — NOT VERIFIED** at runtime.
2. **Remote push is unwired on all three platforms.** No FCM project file and no
   sender. Android is local-only by design, and the UI now says so rather than
   showing an unexplained "Not registered".
3. **The `check_in_booking` migration is still unexecuted** (§8.4) — unchanged.
4. **iOS carries two pre-existing build warnings** — the UIScene lifecycle
   obligation and `rootViewController` access during launch. Both are the C5 item
   in §6, not introduced here.
5. **The §3 matrix is still the pre-Batch-A baseline.** The honest value for
   *push notifications* has moved from FAIL on Android to **partial**: local
   notifications real, remote delivery BLOCKED everywhere.

### 10.7 What would turn these BLOCKED rows into PASS

In rough order of cost:

1. Run the app on a device or emulator and watch a notification arrive, once with
   `POST_NOTIFICATIONS` granted and once denied — converts 10.6.1.
2. Execute the migrations against a real PostgreSQL and call `check_in_booking` —
   converts §8.4 and part of §9.5.
3. Create the Firebase project, drop in `google-services.json`, add
   `firebase-messaging`, and write a sender (an Edge Function calling FCM HTTP
   v1) — converts 10.6.2.
4. Configure `.env.dev` plus the Razorpay/Maps/VAPID keys — converts the §5
   runtime rows.

---

## 11. Batch B2 — itemized receipts and a real PDF

Closes §4.4 and the PDF half of §4.5.

### 11.1 What changed

| Layer | File | What it does |
| --- | --- | --- |
| SQL | `supabase/migrations/20260913190000_itemized_receipt_document.sql` | `issue_booking_receipt(p_booking_id)` — authorization, status gate, itemization, reconciliation flag, immutable snapshot |
| Domain | `lib/features/receipts/domain/receipt.dart` | Document model, line items, reconciliation recomputed client-side |
| Domain | `lib/features/receipts/domain/receipt_statement.dart` | **The words the document may say** — title, number line, caveats |
| Domain | `lib/features/receipts/domain/receipt_repository.dart` | Repository contract |
| Infra | `lib/features/receipts/infrastructure/supabase_receipt_repository.dart` | RPC call, server-owned verdict |
| App | `lib/features/receipts/application/receipt_pdf.dart` | PDF layout only; all wording comes from `ReceiptStatement` |
| UI | `lib/features/receipts/presentation/screens/receipt_screen.dart` | On-screen document + save/share/print |
| Asset | `assets/fonts/NotoSans-Receipt{,-Bold}.ttf` + `OFL.txt` | Embedded font, ~49 KB each |
| Route | `AppRoutes.receipt` = `/bookings/:id/receipt` | Entered from *My Bookings* via `Booking.canViewReceipt` |

`ReceiptStatement` exists so the screen and the PDF cannot disagree. Both render
from it, so "is this a receipt or a statement" is decided once.

### 11.2 Defect found — the PDF would have printed `□1,770.00`

The PDF base-14 fonts use WinAnsi encoding and have no Unicode support. Asking
`pdf` for `₹` does not fail loudly — it prints a warning and draws a
**missing-glyph box**:

```
Helvetica has no Unicode support
Unable to find a font to draw "₹" (U+20b9) try to provide a TextStyle.fontFallback
```

On a document whose entire purpose is to state an amount, `□1,770.00` is a
correctness bug, not a cosmetic one. `Café` would have printed as `Cafe□`.

**Fix:** embed a font with real coverage. `NotoSans-Regular.ttf` is subset with
`pyftsubset` to Basic Latin, Latin-1 Supplement, Latin Extended-A/B, General
Punctuation and Currency Symbols — **49 KB instead of 569 KB**, a deliberate
choice to keep a binary asset in the repository small. Provenance, licence and
the exact regeneration command are in `assets/fonts/README.md`.

**Not fixed, and stated as such:** `pdf` performs no OpenType shaping, so
Devanagari would render as isolated, wrongly-ordered glyphs *even with a font
bundled*. The subset is Latin-only on purpose — a visible missing-glyph box is
more honest than plausible-but-wrong text.

### 11.3 Defect found — the receipt number vanished on the second view

`issue_booking_receipt` returned `receipt_number` when it issued a receipt, but
the **already-issued** branch returned only the frozen snapshot:

```sql
if found and v_receipt.metadata ? 'snapshot' then
  return jsonb_build_object('success', true, 'receipt_issued', true,
    'document', v_receipt.metadata -> 'snapshot');   -- no receipt_number
end if;
```

The snapshot is built *before* the `booking_receipts` row exists, so it cannot
carry a number. The result: the number appeared on the first view and was
**null on every subsequent view**. Fixed by returning it alongside the snapshot.

### 11.4 Defect found — a legacy receipt would have claimed the wrong issue date

A `booking_receipts` row written before snapshots existed gets frozen on first
read, and the snapshot stamped `issued_at = now()` — the time it was *frozen*,
not the time it was *issued*. A receipt issued in June and first opened in
September would have claimed September on a financial document.

Fixed to `coalesce(v_receipt.issued_at, now())`, which is correct for both the
legacy path (real issue time) and the fresh-insert path (no row yet).

### 11.5 Defect found — a field that could only ever read null

`ReceiptDocument` declared `receiptNumber`, but `fromJson` never populated it
because the server returns the number *beside* `document`, not inside it. A
screen reading `document.receiptNumber` would print "no receipt number" for a
booking that has one. The field was removed rather than wired up twice; the
number lives on `ReceiptResult`, where it can actually be populated.

### 11.6 The `pdf` ⇄ `qr` conflict, and why `qr` was pinned down

`pdf` depends on `barcode`, which depends on `qr ^3.0.0` — incompatible with the
`qr ^4.0.0` added in B1. This was **not** resolvable by bumping `pdf`: 3.13.0
(latest) still requires `barcode >=2.2.3 <3.0.0`, and every `barcode` from 2.2.0
to 2.2.9 requires `qr ^3.0.0`.

A `dependency_overrides` shortcut was rejected: `qr` 4.0.0 turned
`QrErrorCorrectLevel` into an enum and removed `QrCode.fromData`, so `barcode`
would not *compile* — the failure would simply move from version solving to
compilation. Syncfusion was rejected too: a commercial licence this project
cannot verify, plus no standard share/print surface (`printing` requires `pdf`).

**`qr` was pinned to `^3.0.2`, and the equivalence was proven rather than
assumed.** For the real check-in payload, 3.0.2 and 4.0.0 produce a
**module-for-module identical** 45×45 symbol (version 7, mask 2), and both raise
`InputTooLongException` at the same 13328-bit limit. The symbol was then decoded
by **OpenCV's QR detector (Quirc)**, which shares no code with either Dart
package, in four configurations including with the brand badge occluding 25
modules and at the production 3 px-per-module size. A frozen-fingerprint test
now fails if the symbol ever changes.

### 11.7 Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | **419 pass** (was 378; +41) |
| `flutter build web --release` | ✓ 60 s |
| `flutter build apk --debug` | ✓ 43 s |
| `flutter build ios --debug --no-codesign` | ✓ 52 s |
| `issue_booking_receipt` column references | Every column verified against the real schema |
| Migration syntax (all 38 files, 63 plpgsql bodies) | 0 real failures (pglast) |
| QR symbol cross-validated 3.0.2 vs 4.0.0 | Matrices identical |
| QR symbol decoded by OpenCV/Quirc | 8/8 cases decoded the exact payload |
| PDF text extraction (MuPDF) | `₹1,500.00`, `₹270.00`, `₹1,770.00` present; **0** replacement/box characters |
| PDF font resources | `/FontFile2` embedded, `NotoSans-Regular` + `NotoSans-Bold`; **no** `/WinAnsiEncoding`, **no** `/Helvetica` |
| Font shipped in artifacts | Web `assets/fonts/`, APK `flutter_assets/assets/fonts/`, iOS `App.framework/flutter_assets/assets/fonts/` |
| OFL licence shipped | Present in all three artifacts |

### 11.8 Still BLOCKED after B2

1. **`issue_booking_receipt` has never been executed.** Syntax and column
   references are verified; behaviour against a live database is not. No local
   PostgreSQL or Docker daemon is available here.
2. **No receipt has ever been opened on a device.** The PDF is verified by
   rendering and text extraction on this machine, and by three platform builds —
   not by running the app.
3. **`Printing.sharePdf` / `layoutPdf` are unexercised at runtime.** The plugin
   is linked on iOS and Android; on Web it loads pdf.js from a CDN, which is a
   runtime network dependency this audit did not exercise.
4. **`Booking.receiptNumber` and the new `canViewReceipt` gate are untested**
   against a real booking row.

### 11.9 What would convert these BLOCKED rows into PASS

1. Execute the migrations against a real PostgreSQL, call
   `issue_booking_receipt` twice for one booking, and assert the second call
   returns the same document **and** the same receipt number — that is the exact
   shape of §11.3.
2. Install the app on a device, open a confirmed booking's receipt, and
   save/share the PDF.
3. Serve the web build and open a receipt with the network offline, to establish
   what `printing` does without pdf.js.

