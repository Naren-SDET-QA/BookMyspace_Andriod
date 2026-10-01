# Phase 7 — Cancellation Policy Implementation Report

Scope: cancellation-policy lifecycle, booking-time snapshot, tiered refund calculation, customer/owner/admin cancellation, D9 staged rollout. Nothing else in the repo was touched. All work was done and verified against a **local, disposable Postgres 16 instance in this cloud sandbox** — not `bookmyspace-dev`. No migration, deploy, commit, or push was performed anywhere.

## 0. Pre-change inspection

- `git status` on the real repo showed the same unrelated dirty tree already present from prior work (Function Halls/UI files, `venue_sections` deletions, pubspec/lockfile changes) — none of it touched this session.
- Two files already existed, untracked, in the repo before this pass: `supabase/migrations/20260914180000_cancellation_policy_lifecycle.sql` and `supabase/tests/phase7_cancellation_policy_test.sql`. Both were read in full and found to already implement D1–D8, D10–D12 correctly against the approved decisions. **One material gap was found and fixed** (§2 below): the migration enforced D9's Stage 4 (block confirmation on a policy-less venue) *unconditionally*, with no staging — directly violating this task's explicit instruction that Stage 4 must be off by default and the four stages must be real, switchable mechanics. Everything else in both files was left as originally written after review.
- A stale `.git/index.lock` was encountered twice more (same as Phase 6/Implementation pass) and renamed aside (`index.lock.stale3.bak`, `index.lock.stale4.bak`) rather than deleted, per the same device-delete restriction as before.

## 1. Files changed (real repo, local working tree only — nothing committed)

**Modified:**
- `supabase/migrations/20260914180000_cancellation_policy_lifecycle.sql` — added the D9 rollout-stage switch (new table + 2 functions) and re-gated the existing D9 enforcement block behind it. Every other section (policy versioning/history, `is_valid_cancellation_policy`, `update_venue_cancellation_policy`, the tiered `calculate_refund_amount`, the booking-time snapshot in `confirm_venue_booking`, `owner_cancel_booking`) was left as found.
- `supabase/tests/phase7_cancellation_policy_test.sql` — rewrote the D9 test section: it previously assumed Stage 4 was the default and asserted a policy-less venue's confirmation would be blocked immediately, which is exactly the "unexpectedly blocks the existing catalog" failure mode this task forbids. Replaced with: (a) an assertion that the default stage is `snapshot_only` and a policy-less-venue confirmation *succeeds* unchanged; (b) a non-admin-cannot-advance-the-stage check; (c) an admin explicitly advancing to `enforce` (audited) and the *same* scenario now correctly blocking; (d) the stage restored to the test default before the remaining, unrelated tests run. No other test in this file was weakened or removed — only this section's premise was corrected.

**Not modified:** `bookings_no_overlap`, `cancel_confirmed_booking`, `admin_cancel_booking`, `apply_refund_result`, `list_stale_refund_requests`, all three Edge Functions from the prior phase, and everything under `lib/`, `test/`, Function Halls, the 3D Glass Matrix widget, and `venue_sections` — confirmed via `git status` diffing against a filtered exclude-list before and after this pass; the only lines that changed are the two files named above.

## 2. What was implemented / fixed

### D9 rollout-stage switch (the fix)
New singleton table `public.cancellation_policy_rollout(id boolean pk, stage text check in (configure_only, snapshot_only, warn, enforce))`, seeded to **`snapshot_only`** — explicitly commented in the migration as a **TEST/LOCAL default only, not a business decision**. Two new functions:
- `get_cancellation_policy_rollout_stage()` — read, granted to `authenticated`/`service_role`.
- `set_cancellation_policy_rollout_stage(p_stage)` — admin/super-admin-only, audited (writes `audit_logs` with `from_stage`/`to_stage`), rejects invalid stage names.

`confirm_venue_booking`'s D9 gate now reads: block only `if get_cancellation_policy_rollout_stage() = 'enforce' and (policy missing/invalid)`. At every other stage the function is **byte-for-byte identical** to the version already in the untouched-until-now migration — same snapshot write, same `NULL`-on-missing-policy behavior, same everything else. This matches the architecture's Stage 1–3 requirement exactly: nothing before Stage 4 can turn a confirmation that would have succeeded into a failure.

### What was already correct and left as-is (verified, not rewritten)
- **D1/D12** — no separate hard cutoff; a missing/invalid policy still returns `NULL` from `calculate_refund_amount`, which still hard-blocks `cancel_confirmed_booking` with `CANCELLATION_POLICY_UNDEFINED` (unchanged function, from the Phase-6-era migration) — the safe historical-booking behavior.
- **D2** — `calculate_refund_amount` walks the tiers array (48h→100, 24h→50, 0h→0) highest-satisfied-threshold-wins, using `hours_before_booking = (book_date+start_time) − now()`.
- **D3** — no fee field/subtraction anywhere in the calculation.
- **D4** — `tax_refund_amount` is computed as the same percentage of `bookings.tax_amount`, reported for audit/receipt transparency; no credit-note/invoice behavior was invented, matching the instruction.
- **D5/D6** — nothing added; refund amount is the captured `payments.amount` times the tier percent, no fee deduction.
- **D7** — `owner_cancel_booking` always refunds 100% of the captured amount regardless of hours-before, verified authorization-scoped to the venue's actual owner via `organizations.owner_user_id`.
- **D8** — `admin_cancel_booking` (from the earlier migration, untouched) still requires a reason and caps only at the captured amount.
- **D10/D11** — `update_venue_cancellation_policy` writes a monotonically-versioned row to `venue_cancellation_policy_history` before updating the single live `venues.cancellation_policy` column; a booking's own snapshot (taken at confirmation) is what `calculate_refund_amount` prefers, so a later policy edit never changes an already-confirmed booking's entitlement — verified directly in the test suite (§3, "historical booking remains governed by its own snapshot").
- **D12** — `cancel_confirmed_booking`/`owner_cancel_booking` only insert a `refunds` row when the computed amount is `> 0` (the table's own `CHECK (amount > 0)` constraint would reject a $0 row outright, and both functions guard against attempting one) — matches "no $0 refund row" without needing a code change.

## 3. Tests run and results

All against a **fresh, disposable `bms_phase7` / `bms_regress` Postgres 16 database** built from `00_schema_stub.sql` (base tables/enums/`cancel_venue_booking`, reused from the Phase-6-era verification) plus a new `01_schema_extend.sql` (adds the columns/tables `confirm_venue_booking` touches: `time_slots`, `venue_blocked_dates`, `external_reservations`, `booking_receipts`, `notifications`, the missing `bookings`/`venues`/`organizations` columns, and an `auth.uid()` stand-in that accepts both this session's and the prior session's test-fixture conventions) — then both real migrations (`20260914170000_refund_cancellation_domain.sql`, `20260914180000_cancellation_policy_lifecycle.sql`) applied in order.

- **Both migrations apply cleanly**, in order, on a clean database — exit 0.
- **Phase 7 test suite** (`phase7_cancellation_policy_test.sql`, as corrected in §1): **56 assertions, all PASS**, ending `ALL PHASE 7 TESTS PASSED`. Covers: policy create/version/history (D10/D11), non-owner rejected; **D9 default-stage does NOT block** a policy-less venue's confirmation (booking confirms, snapshot is `NULL`); non-admin cannot change rollout stage; admin can, audited; **the same scenario blocks once Stage 4 is explicitly activated**; stage restored to default; snapshot taken at confirmation and 48h-tier resolved correctly; historical booking's snapshot is immune to a later venue policy edit; 0%/48h+/100% tier boundaries; no fee subtracted (D3); no $0 refund row (D12); owner cancellation = 100% refund regardless of tier, wrong-owner rejected; admin cancellation requires reason, no cap, audited, non-admin rejected; duplicate-cancel retry rejected without double refund; duplicate-refund unique-index race; stranger cannot cancel another user's booking or another owner's venue; webhook-style `apply_refund_result` success/idempotent-replay/late-failure-no-op, and failure/retry-after-failure paths.
- **Original 12-scenario refund/cancellation regression suite** (`10_scenarios.sql`, from the Phase-6-era work) re-run against a database carrying the new Phase 7 migration on top — **all still pass**, confirming the D9 rollout-stage change did not regress anything in the pre-existing refund domain.
- **True concurrency test** (real simultaneous `psql` connections, not simulated): a customer's `cancel_confirmed_booking` and the venue owner's `owner_cancel_booking` fired at the same instant against the same confirmed, paid booking. Result: exactly one succeeded (the customer's, which happened to win the row lock), the owner's call correctly got `CANNOT_CANCEL` against the now-cancelled booking, and **exactly one** `refunds` row exists afterward — no double refund.
- **TypeScript check**: the four existing Edge Function files (unchanged this pass) still compile with zero errors under the same `tsc` + Deno/Supabase-JS ambient-shim setup as the prior phase.
- **Dart/Flutter**: `git status` confirms this pass touched nothing under `lib/` or `test/` — the only diffs there are the same pre-existing, unrelated dirty state noted in the Phase 6 report (Function Halls/UI, `venue_sections`, pubspec). Since the Phase 7 change surface is entirely server-side (new migration + new RPCs, both consumed by direct `supabase.rpc(...)` calls that don't yet exist in any Dart file), there is no Dart diff to analyze and no test to add on the client side yet — running `flutter analyze`/`flutter test` here would only reproduce that pre-existing unrelated state, not anything from this work.

## 4. Remaining issues / known limitations

1. **No Flutter/UI wiring exists yet** for `owner_cancel_booking`, `update_venue_cancellation_policy`, or `set_cancellation_policy_rollout_stage` — out of scope per this task's explicit instruction not to touch UI. A venue owner today has no in-app way to set a cancellation policy; it would need to be called via `supabase.rpc('update_venue_cancellation_policy', {...})` from an owner screen, which is a client-side task, not implemented here.
2. **The `refundable_amount`/`tax_refund_amount` returned by `calculate_refund_amount` are informational for `cancel_confirmed_booking`/`owner_cancel_booking`'s own use** — no receipt/credit-note is generated showing the tax breakdown, consistent with "do not invent credit-note/invoice behavior." The unresolved GST remittance/credit-note legal question from `POLICY_DECISION_LOCK.md` D4 is unchanged and still open.
3. **The four D9 scheduling parameters remain unset**, by design — this pass only proves the stage *mechanics* work; it does not and must not choose the Stage 1 coverage threshold, Stage 2 observation period, Stage 3 warning duration, or the Stage 4 activation trigger.
4. **0/555 real venues still have a policy** — nothing in this pass touches `bookmyspace-dev`, so that number is unchanged. Until Stage 1 (configure-only) actually ships and owners start setting policies, `owner_cancel_booking`/`cancel_confirmed_booking` will continue to correctly return `CANCELLATION_POLICY_UNDEFINED`/refund nothing for any real booking today, exactly as before this phase.
5. **`update_venue_cancellation_policy` only ever writes the one approved standard tier table** (48h/100, 24h/50, 0h/0) with an `active` on/off flag — there is no per-venue custom tier override, matching D1/D2's approved scope. If product later wants per-venue tier customization, that is new schema/RPC work, not a bug in this pass.

## 5. Exact production deployment steps still requiring approval (none performed)

1. Apply `20260914170000_refund_cancellation_domain.sql` then `20260914180000_cancellation_policy_lifecycle.sql` to `bookmyspace-dev`, in that order (the second depends on objects from the first).
2. Confirm the rollout stage lands as `snapshot_only` in production too (the migration's `insert ... on conflict do nothing` seeds it there) — **never let it default to `enforce`**.
3. Build the owner-facing policy-editor screen/RPC call (`update_venue_cancellation_policy`) and an owner-cancellation entry point (`owner_cancel_booking`) — client work, not started.
4. Build the Stage 3 "warn" surface (owner dashboard/notification listing policy-less venues) — product/UI work, not started.
5. Only once product has set the four scheduling parameters (§4.3) should an admin ever call `set_cancellation_policy_rollout_stage('enforce')` in production — and only after Stage 1–3 have run their course, per `POLICY_DECISION_LOCK.md` D9.
6. The still-open GST remittance/credit-note legal question (D4) should be resolved before this ships as fully tax-compliant, independent of the engineering being ready.

---

**PHASE 7 STATUS: IMPLEMENTED + TESTED LOCALLY**
**PHASE 8 STATUS: PENDING — PRODUCTION DEPLOYMENT GATE**
**PHASE 9 STATUS: PENDING — PRODUCTION VERIFICATION / GO-LIVE**
