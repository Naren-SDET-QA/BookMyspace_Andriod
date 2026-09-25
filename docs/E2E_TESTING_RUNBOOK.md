# BookMySpace E2E Testing Runbook (DEV)

Real-data end-to-end verification of the booking lifecycle (customer request
-> owner approval -> payment) against the DEV Supabase project. This runbook
exists so an E2E run is never blocked on missing test-account credentials.

## 0. Environment prerequisites

- DEV Supabase project reachable; `supabase/` linked
  (`supabase/.temp/linked-project.json`).
- `.env.dev` created from `.env.dev.example` (gitignored) with real DEV keys.
- Run target: **Chrome** (`flutter devices`) — no emulator is required;
  Android emulator/AVD optional.
- Test accounts exist in DEV Auth (see section 1).

Launch the app exactly as the IDE does:

```bash
flutter run -d chrome --dart-define-from-file=.env.dev
```

## 1. E2E test accounts (convention)

| Account   | Email                         | Role granted by                                            |
|-----------|-------------------------------|------------------------------------------------------------|
| Customer  | `customer.dev@bookmyspace.app` | Supabase Auth user (default authenticated role)           |
| Owner     | `owner.dev@bookmyspace.app`    | `venue_owner` + owner profile + org via `supabase/migrations/20260912180000_grant_dev_test_roles.sql` |

- Emails are created by provisioning (migration/seed references them by
  lookup); **passwords are never committed**.
- Passwords live in local `.env.dev` under:

```ini
DEV_E2E_CUSTOMER_EMAIL=customer.dev@bookmyspace.app
DEV_E2E_CUSTOMER_PASSWORD=<set locally>
DEV_E2E_OWNER_EMAIL=owner.dev@bookmyspace.app
DEV_E2E_OWNER_PASSWORD=<set locally>
```

### One-time owner password provisioning (human, before first E2E run)

The role-granting migration does not set a password. If owner login fails
with `Invalid login credentials`, provision it once outside the E2E flow:

- Supabase Dashboard (DEV project) -> Authentication -> Users ->
  `owner.dev@bookmyspace.app` -> Send password recovery / set password, **or**
- any authenticated admin path your team uses for DEV user management.

Never reset passwords or mutate booking state from the E2E session itself.

## 2. Owner flow (approve a booking)

1. Log in at `/login` with the owner account (email + password).
2. Open Owner bookings: route `/owner/bookings`
   (`AppRoutes.ownerBookings` -> `OwnerBookingsScreen`).
3. Locate the booking by its `booking_ref` (e.g. `BMS-XXXXXXXX`).
4. Verify venue, date (`book_date`), time window (`start_time`–`end_time`),
   and amount shown match the booking under test.
5. Press **Approve**. The UI calls
   `bookingRepositoryProvider.approveBooking(id)` -> Supabase RPC
   `approve_venue_booking(p_booking_id, p_idempotency_key)`.
6. Expected transition: `awaiting_owner_approval` -> `pending`
   (`docs/BOOKING_APPROVAL_AND_MODULES_SPEC.md`). Approval opens the
   payment window for the customer.

If the pending list is empty, confirm the booking's venue actually belongs
to owner.dev's organization (an earlier gate run hit a mis-targeted venue;
the request only appears for the owning org's account).

## 3. Customer flow (payment becomes available)

1. Sign out; log in with the customer account.
2. Open My Bookings (`/bookings`) and locate the same `booking_ref`.
3. Verify the status now renders `pending` and the **Pay** action is
   available (payment window opened by the approval).

## 4. Read-only state verification (optional)

Verification queries are SELECT-only and never mutate state:

```sql
SELECT booking_ref, status, book_date, start_time, end_time
FROM public.bookings WHERE booking_ref = 'BMS-XXXXXXXX';
```

## 5. Hard rules for every E2E run

- Real DEV data/session only; no production access.
- Never bypass authentication (no CLI-admin minted sessions, no seeded JWTs).
- Never force status with SQL; approvals go through the UI/RPC business flow.
- Never modify booking/payment/auth/business rules during a run.
- Never create a second booking to work around a failed one.
- Nothing is staged, committed, pushed, or deployed by the run itself.

## 6. Evidence capture (screenshots & logs)

Every gate run must produce the same artifact set so runs are comparable.

### Setup

```bash
mkdir -p "e2e-evidence/$(date -u +%Y-%m-%d)_<BOOKING_REF>"
RUN="e2e-evidence/$(date -u +%Y-%m-%d)_<BOOKING_REF>"
flutter run -d chrome --dart-define-from-file=.env.dev 2>&1 | tee "$RUN/console.log"
```

### What to capture (fixed numbering, same filenames every run)

| # | File | When | Content |
|---|------|------|---------|
| 01 | `$RUN/01_owner_login.png` | After owner sign-in succeeds | Logged-in shell / profile identity visible |
| 02 | `$RUN/02_owner_bookings_list.png` | Owner bookings screen | The `booking_ref` visible in the pending list |
| 03 | `$RUN/03_booking_detail_before.png` | Before approving | Venue, date, time window, amount, status chip readable |
| 04 | `$RUN/04_booking_detail_after.png` | Immediately after Approve succeeds | Status chip now `pending`; no error banners |
| 05 | `$RUN/05_customer_bookings.png` | Customer signed in | Same `booking_ref` rendering `pending` with **Pay** available |

- Chrome: OS screenshot (`Cmd+Shift+4`) or DevTools device toolbar capture;
  ensure the status text is legible in the shot (zoom if needed).
- Android device/emulator (when available):
  `adb exec-out screencap -p > "$RUN/NN_name.png"`.
- Network evidence: Chrome DevTools -> Network -> right-click -> *Save all as
  HAR with content* -> `$RUN/network.har`. The `approve_venue_booking` RPC
  response must be present in it (or its error body, verbatim, on failure).
- Console evidence: keep the full `console.log` from `flutter run` (includes
  Riverpod/provider errors and RPC failure messages mapped by the repository).

### Redaction rules

Never commit or paste: passwords, session tokens/JWTs, the anon or service
keys, Razorpay secrets, or customer PII beyond what the DEV test data
already contains. Scrub `$RUN/console.log` if a token ever appears.

## 7. Results report template

Copy this block verbatim into a new report file (e.g.
`Claude outputs/E2E_Report_<date>_<BOOKING_REF>.md`) and fill every cell.
A `PASS` is only valid with an artifact reference from section 6.

```markdown
# BookMySpace E2E Gate Report — <BOOKING_REF>

- **Date (UTC):** <YYYY-MM-DD HH:MM>
- **Runner:** <name/session>
- **Target:** <chrome|android> / <device or window size>
- **App commit:** `git rev-parse --short HEAD` = <hash> (branch <branch>)
- **Environment:** DEV Supabase <project-ref> (APP_ENV=development)
- **Rules acknowledged:** runbook section 5 followed; no SQL-forced status,
  no auth bypass, no second booking, no staging/commit/push/deploy.

## 1. Authentication
| Account | Result | Evidence |
|---|---|---|
| owner.dev (`owner.dev@bookmyspace.app`) | PASS/FAIL | <01_owner_login.png; role check> |
| customer.dev (`customer.dev@bookmyspace.app`) | PASS/FAIL/BLOCKED | <…> |

## 2. Owner flow — <BOOKING_REF>
| Step | Expected | Observed | Result | Evidence |
|---|---|---|---|---|
| Booking in owner pending list | Ref visible | <…> | PASS/FAIL | 02_owner_bookings_list.png |
| Detail matches test data | Venue `<venue>`, `<YYYY-MM-DD>`, `<HH:MM>–<HH:MM>`, `₹<amount>` | <…> | PASS/FAIL | 03_booking_detail_before.png |
| Approve via UI | RPC `approve_venue_booking` 200; no error banner | <…> | PASS/FAIL | network.har (RPC entry) |
| Status transition | `awaiting_owner_approval` -> `pending` | <before> -> <after> | PASS/FAIL | 04_booking_detail_after.png |

## 3. Customer flow — payment availability
| Step | Expected | Observed | Result | Evidence |
|---|---|---|---|---|
| Booking renders for customer | Status `pending`, **Pay** visible | <…> | PASS/FAIL | 05_customer_bookings.png |
| Payment window opened by approval | Pay action leads to checkout | <…> | PASS/FAIL/BLOCKED | <…> |

## 4. Booking state (read-only verification)
| Field | Before | After |
|---|---|---|
| status | `awaiting_owner_approval` | `pending` |
| approval_requested_at / expires_at | <…> | <…> |

## 5. Defects found
| ID | Severity | Description | Repro | Evidence |
|---|---|---|---|---|
| D1 | P0/P1/P2 | <…> | <…> | <…> |

## 6. Attachments manifest
- [ ] 01_owner_login.png  - [ ] 02_owner_bookings_list.png
- [ ] 03_booking_detail_before.png  - [ ] 04_booking_detail_after.png
- [ ] 05_customer_bookings.png  - [ ] network.har  - [ ] console.log

## 7. Verdict
<READY / NOT READY — <one-line reason>>
```
