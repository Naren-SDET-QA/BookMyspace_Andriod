# BookMySpace — Phase 1 Production Audit Report (incl. P1 Refund/Cancellation)

Audit type: READ-ONLY. No files, migrations, database objects, or Git state were modified during this audit.

## Executive Summary

The core booking-exclusivity invariant (one venue-wide booking per overlapping time window, `bookings_no_overlap` as the hard backstop, advisory-lock-serialized RPCs) is **CONFIRMED intact and correctly enforced** across every booking-creation/confirmation path that was inspected. No evidence was found of any path bypassing it. This part of the system is in good shape.

The **refund/cancellation lifecycle is the real production blocker**, not booking capacity. The concrete, confirmed finding: the client app calls an Edge Function (`create-refund`) to process refunds — **that function exists in the repository but is not deployed to the live Supabase project**. Every "Request Refund" tap on a confirmed, paid booking will fail in production today. Separately, even if deployed, the function has a real double-refund race (no unique constraint backing its existence check) and no recovery path if the Razorpay call succeeds but the following database writes fail. There is also **no code path anywhere to cancel a CONFIRMED (already paid) booking** other than this same broken refund function — customer self-cancel is hard-blocked once a booking leaves `pending`, and no owner/admin cancellation RPC exists at all.

Separately, the workspace itself is in a state that undermines confidence in any "completed work" claim: the local repository has 20+ modified/staged files and a **git history of migrations being added and then deleted again in the same working tree**, and the **local migration files do not match the live database's applied-migration history** (different names, different content, items on one side missing from the other). Any status report about this codebase must be read against actual `git log`/`list_migrations` output, not file presence alone.

## 1. Workspace / Git State — CONFIRMED

- Repo path (on the linked machine): `~/BookMyspace_Andriod` (`/Users/aa/BookMyspace_Andriod`)
- Branch: `fix/ios-bookmyspace-ui`
- HEAD: `795a235 feat(admin): add payment operations health and ledger`
- Remote: `https://github.com/Naren-SDET-QA/BookMyspace_Andriod.git`
- `git status` is **dirty** with ~28 paths touched, including:
  - Untracked report file (`Claude outputs/BookMySpace_E2E_Gate_Report.md`) staged as added
  - `DA` (staged-deleted, working-tree-added / renamed pattern) on 4 migration files and a test-contract SQL file, plus 2 Dart test files and 5 venue-section feature files — i.e., files that exist on disk differ from what's staged for removal
  - Modified-and-staged (`MM`) changes across owner venue screens/repositories, the razorpay-webhook helpers + its test, `pubspec.lock`/`pubspec.yaml`
  - This state means **no single "current" version of several booking/venue/payment-adjacent files exists** — index, working tree, and HEAD disagree simultaneously on the same files.

**Recommendation:** Before any implementation work, `git status`/`git diff` must be resolved and reconciled to a single clean commit — this audit's findings below are against the **working-tree file contents as currently checked out**, not HEAD.

## 2. Supabase Environment — CONFIRMED

Two Supabase projects exist on the account:

| Project | ref | status |
|---|---|---|
| `bookmyspace-dev` | `zykxneztahxbjduagutv` | ACTIVE_HEALTHY |
| `BookMySpace` | `ehxuygrsyaknhhsaihhx` | ACTIVE_HEALTHY |

`.env.dev` (the file actually wired into the Flutter build via `--dart-define-from-file`) and `.env.flutter` both point `SUPABASE_URL` at `zykxneztahxbjduagutv` (`bookmyspace-dev`). **This audit was run against `zykxneztahxbjduagutv`.** The second project (`ehxuygrsyaknhhsaihhx`, named "BookMySpace") was not inspected — its schema/RPCs/data may or may not match what's documented here. This is worth a product/ops confirmation: which project is actually production, and is the other one stale.

## 3. Current Booking Invariant — CONFIRMED

Live constraint on `public.bookings`:

```
bookings_no_overlap: EXCLUDE USING gist (
  venue_id WITH =, book_date WITH =,
  tsrange((book_date + start_time), (book_date + end_time), '[)') WITH &&
) WHERE (status = ANY (ARRAY['held','awaiting_owner_approval','pending','confirmed','completed']))
```

- This is venue-wide exclusivity keyed on `(venue_id, book_date, time-range)` — `slot_id` is **not** part of the constraint, confirming slots are alternative time windows for the same physical venue, not independently bookable units.
- `quantity` exists as an integer column on `bookings` but every booking-creation path (`acquire_venue_hold`, `request_venue_booking`) inserts it hardcoded as `1`. No code path sets it to anything else.
- Statuses NOT covered by the exclusion constraint: `cancelled`, `refunded`, `no_show`, `owner_rejected`, `approval_expired`, `external_conflict`, `availability_reopened` — i.e., a cancelled/refunded/rejected/expired booking correctly frees the slot for the constraint's purposes. This is the intended behavior.
- Not changed, not touched, per instructions.

## 4. Booking State Machine — CONFIRMED

Live `booking_status` enum values: `held, pending, confirmed, completed, cancelled, refunded, no_show, awaiting_owner_approval, owner_rejected, approval_expired, external_conflict, availability_reopened`.

Two parallel creation flows exist in the live RPC set:
- **Legacy/instant-pay flow:** `acquire_venue_hold` -> `held` -> (client pays) -> `confirm_venue_booking`/`confirm_booking` -> `confirmed`.
- **Owner-approval flow:** `request_venue_booking` -> `awaiting_owner_approval` -> `approve_venue_booking`/`reject_venue_booking` -> `pending` (approved, awaiting payment) -> `confirm_venue_booking` -> `confirmed`.

`confirm_venue_booking` (the live, current version) **CONFIRMED** requires all of: status `pending`, `approved_at`/`approved_by` set, payment window not expired, and a matching `captured` payment row — i.e., it does **not** confirm on payment alone in the currently-deployed version (this contradicts an earlier note in project memory describing `confirm_venue_booking` as "confirms on payment alone" — that appears to describe an older revision; the live function now hard-gates on owner approval too). This is a positive finding, not a gap.

`confirm_venue_booking` also handles an `external_conflict` case: if an external-channel reservation is detected at confirmation time (after payment capture), it does **not** silently confirm — it flips the booking to `external_conflict` and returns an explicit `EXTERNALLY_BOOKED` error rather than treating payment success as booking success. Correct design.

## 5. `bookings_no_overlap` Analysis — CONFIRMED

- Semantics: half-open interval `[start, end)` per venue per date, GiST exclusion — this correctly prevents any two overlapping ranges from coexisting for the listed statuses, including a booking that starts exactly when another ends (no overlap, correctly allowed).
- NULL behavior: `venue_id`, `book_date`, `start_time`, `end_time` are all NOT part of a nullable path in the booking-creation RPCs (all populated from `time_slots` lookups) — no NULL-driven bypass found in the paths inspected.
- No status can escape the constraint via any inspected RPC: `acquire_venue_hold` inserts as `held` (covered), `request_venue_booking` presumably inserts as `awaiting_owner_approval` (covered) — not independently re-verified in this pass (**INFERRED** from enum/constraint match, not read line-by-line).
- Whether **updates** can bypass it: not verified against `request_venue_booking`/`approve_venue_booking`/`reject_venue_booking` source directly in this pass — **NOT VERIFIED**, flagged for a follow-up read.

## 6. RLS and RPC Authorization — CONFIRMED (booking/payment/refund tables), PARTIAL elsewhere

RLS policies actually found on the core tables:

| Table | Policy | Command | Predicate |
|---|---|---|---|
| `booking_holds` | `holds_owner_read` | SELECT | `auth.uid() = user_id` |
| `bookings` | `bookings_user_read` | SELECT | own bookings OR venue owner |
| `bookings` | `bookings_customer_cancel` | UPDATE | own booking AND status IN (`held`,`awaiting_owner_approval`,`pending`) -> new status must be `cancelled` |
| `payments` | `payments_user_read` | SELECT | own payments OR venue owner |
| `refunds` | `refunds_user_read` | SELECT | own booking's refunds |

**No INSERT/UPDATE/DELETE policies exist for `authenticated` on `payments` or `refunds` at all**, and no direct booking INSERT policy — CONFIRMED client code cannot directly manipulate booking/payment/refund state; all writes to these tables must go through SECURITY DEFINER RPCs or the service-role key (Edge Functions). This is correctly locked down.

EXECUTE grants (client-invocable, `authenticated` role): `acquire_booking_hold`, `acquire_venue_hold`, `approve_venue_booking`, `cancel_venue_booking`, `reject_venue_booking`, `release_venue_hold`, `request_venue_booking`. `confirm_venue_booking` and `confirm_booking` are **not** granted to `authenticated` — only `postgres`/`service_role` — meaning confirmation can only happen via the server side (webhook/edge function using the service key), not directly from the client. Correct.

**P2 finding (CONFIRMED):** `reconcile_stale_payments` is granted EXECUTE to `PUBLIC` and `anon` — i.e., **any unauthenticated caller** can invoke it. Impact is currently low because it is not `SECURITY DEFINER` and RLS on `payments` has no UPDATE policy for `anon`/`authenticated`, so its `UPDATE public.payments SET status='failed' ...` should silently affect 0 rows for a non-privileged caller — but this was not empirically verified (no write test was run, per the read-only constraint) and the grant itself is unnecessarily broad and should be revoked to `service_role`/a scheduled job only, both as defense-in-depth and to stop it being a no-op DoS/confusion vector (an anon user can trigger it in a loop).

SECURITY DEFINER + `search_path` hardening: every SECURITY DEFINER function inspected (`acquire_venue_hold`, `confirm_venue_booking`, `release_venue_hold`, `available_time_slots`, `expire_stale_holds`, `cancel_venue_booking`, `register_webhook_event`) sets `SET search_path TO 'public', 'pg_temp'` — CONFIRMED correctly hardened against search-path hijacking. `reconcile_stale_payments` is notably **not** SECURITY DEFINER and has **no search_path pin**, but since it isn't a definer function this is lower risk (it runs as caller).

## 7. Payment / State-Machine Audit — CONFIRMED (core), gap noted in refund path

- Hold creation -> `create-booking-hold`/`acquire_venue_hold` (DB-serialized via `pg_advisory_xact_lock` on `hashtextextended(venue_id||book_date)`).
- Razorpay order creation -> `create-payment-order` Edge Function (deployed, live).
- Payment verification -> `verify-payment` Edge Function (deployed, live) + `razorpay-webhook` (deployed, `verify_jwt: false` — correct, webhooks are unauthenticated by nature and must instead verify Razorpay's signature; signature verification itself was **not** independently re-read in this pass — **NOT VERIFIED**, flagged).
- `confirm_venue_booking` idempotency: explicitly idempotent — re-calling on an already-`confirmed` booking returns the existing receipt with `idempotent: true` rather than erroring or double-processing. CONFIRMED.
- `webhook_events` table + `register_webhook_event()` RPC provide provider-level idempotency (dedupe by `(provider, event_id)`) for the Razorpay webhook path. CONFIRMED as a real mechanism, not invented.

## 8. Cancellation / Refund State Machine — MANDATORY P1

Full lifecycle trace: `BOOK -> PAY -> CONFIRM -> CANCEL -> REFUND -> RECONCILE`.

### 8.1 Customer cancellation flow — CONFIRMED, and CONFIRMED incomplete

`cancel_venue_booking(p_booking_id)`:
- Guards: caller must own the booking; booking status must be in `(held, awaiting_owner_approval, pending)`; blocks if any `payments` row for the booking has `status = 'captured'`.
- Effect: sets booking `cancelled`, releases the hold, writes an audit log row.
- **A `confirmed` booking is explicitly excluded** — `status not in (...)` returns `CANNOT_CANCEL` — and the RLS policy `bookings_customer_cancel` enforces the identical restriction independently at the row level (defense in depth, good) — but the practical effect is that **there is no cancellation path for a paid/confirmed booking** anywhere in this function.

### 8.2 Owner/admin cancellation flow — CONFIRMED NOT TO EXIST

Searched every function whose name contains `cancel`, `refund`, `owner_approv`, or `booking` in the live schema. Result: the only cancellation-capable functions are `cancel_venue_booking` (customer-only, as above) and `cancel_event_registration` (unrelated — event registrations, not venue bookings). **There is no owner- or admin-initiated cancellation RPC for venue bookings at all**, confirmed or approved. Owner-side actions that exist are `approve_venue_booking` and `reject_venue_booking`, both of which only apply pre-payment (on `awaiting_owner_approval` bookings), not to already-confirmed/paid bookings.

### 8.3 Cancellation policy enforcement — CONFIRMED NOT ENFORCED ANYWHERE

`bookings.cancellation_policy` (jsonb) exists as a column but is **not referenced by any function or Edge Function found in this audit** (`acquire_venue_hold`, `confirm_venue_booking`, `cancel_venue_booking`, `create-refund` — none of them read it). Whatever cancellation-fee/window policy this column is meant to encode is currently inert.

### 8.4 Refundable amount calculated server-side? — PARTIALLY, and not policy-aware

`create-refund` (Edge Function) computes `refundAmount = amount ?? payment.amount` — i.e., it accepts a **client-supplied `amount`** and only bounds it (`0 < amount <= captured amount + 0.01`). It does not compute an amount from `cancellation_policy` or any server-side fee schedule. So: the server enforces an upper bound, but does not itself *calculate* the refundable amount per policy — the client proposes a number and the server merely doesn't let it exceed what was captured.

### 8.5 Can a paid booking be cancelled without refund processing? — NO PATH EXISTS EITHER WAY

Because `cancel_venue_booking` refuses `confirmed` bookings outright, there is no way to mark a paid booking cancelled *without* going through `create-refund` — but see 8.7, `create-refund` is not deployed. **Net effect: a paid, confirmed booking currently cannot be cancelled or refunded through any live, callable code path.** This is the single most important finding in this audit.

### 8.6 Razorpay refund creation — CONFIRMED, exists in repo

`supabase/functions/create-refund/index.ts` (211 lines) calls `POST https://api.razorpay.com/v1/payments/{payment_id}/refund` with a server-held `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET`, amount in paise, on `Authorization: Basic`. Secrets stay server-side — correct pattern.

### 8.7 P1 — CONFIRMED CRITICAL: `create-refund` is not deployed to the live project

`list_edge_functions` for `zykxneztahxbjduagutv` lists: `create-booking-hold, create-payment-order, razorpay-webhook, create-registration-payment-order, ai-chat, ai-clarification, ai-action-gate, import-venues, delete-account, lookup-pincode, verify-payment, external-inventory-webhook, external-inventory-sync`. **`create-refund` is absent.** The Flutter client (`lib/features/payments/infrastructure/supabase_payment_repository.dart:70`) calls `supabase.functions.invoke('create-refund', ...)` from the "Request Refund" button on `my_bookings_screen.dart`. Today, in production, that call will fail (function not found) for every user who taps Request Refund on a confirmed booking.

- **Impact:** Every refund request in production currently fails. No refunds can be issued through the app.
- **Evidence:** local file present at `supabase/functions/create-refund/index.ts`; absent from `list_edge_functions` output for the live project.
- **Remediation:** deploy the existing function (`supabase functions deploy create-refund`) — but see 8.9/8.10 below, it should not be deployed as-is without addressing the race and the non-atomicity first.
- **Requires:** deployment/config only for the missing-function part; code fix for 8.9/8.10.

### 8.8 Full vs partial refunds — CONFIRMED, supported but not policy-bound

`create-refund` supports both (client-specified `amount`, defaulting to full captured amount). See 8.4 — the split is accepted but not derived from any policy.

### 8.9 P1 — CONFIRMED: duplicate-refund race, no idempotency backstop at the DB level

The function's only duplicate guard is: `SELECT id FROM refunds WHERE payment_id = ? LIMIT 1` (via `.maybeSingle()`), and if empty, proceeds to call Razorpay and then INSERT. **`public.refunds` has no unique constraint on `payment_id`** (only a plain foreign key, primary key on `id`, and check constraints on `amount`/`status`) — CONFIRMED via `pg_constraint`. Two concurrent "Request Refund" calls for the same payment (e.g., a double-tap, or a retried failed request) can both pass the existence check before either inserts, both call Razorpay's refund API, and both succeed — a double refund. This is a genuine TOCTOU race, not merely theoretical, because there is no serializing lock (no advisory lock, no `SELECT ... FOR UPDATE`, no unique index) anywhere in this path.

- **Fix required:** add a unique constraint/index on `refunds.payment_id` (or `(payment_id) WHERE status <> 'failed'`) and have the insert be the actual idempotency gate (catch the unique-violation instead of pre-checking), or wrap the check+insert in an advisory-locked transaction analogous to `acquire_venue_hold`'s pattern. Migration required.

### 8.10 P1 — CONFIRMED: non-atomic sequence, no recovery if Razorpay succeeds but the app update fails

Call order inside `create-refund`: (1) call Razorpay refund API -> (2) `INSERT INTO refunds` -> (3) `UPDATE bookings SET status='refunded'` -> (4) `UPDATE payments SET status='refunded'`. Each of steps 2-4 can independently fail and returns a `5xx` to the client, but **step 1 (the actual money movement) has already happened** and is not undone or compensated. There is no outbox/reconciliation job that later reconciles Razorpay's refund records against `refunds`/`bookings`/`payments` — `reconcile_stale_payments` only touches `payments` rows with `status='pending'`, not refunds, and nothing in `razorpay-webhook` handles a `refund.processed`/`refund.failed` event type (confirmed by grep — zero matches for "refund" in the webhook source). **A failed step 2-4 after a successful Razorpay refund is currently silent and permanent**: the customer's money is gone, but the booking still shows `confirmed` and no `refunds` row exists to show it happened.

- **Fix required:** either (a) make the DB writes happen first inside a transaction and only call Razorpay after committing a `refunds` row in a `requested` state, updating to `processed`/`failed` afterward (safer, matches the `refunds_status_check` enum which already includes `requested`/`approved`/`processed`/`rejected`/`failed` — these states are defined but never used by the current code, which jumps straight to `processed`), or (b) add a webhook handler for Razorpay refund events as the source of truth and treat this function's DB writes as best-effort/reconciled-later. Code + migration required.

### 8.11 Refund webhook/reconciliation — CONFIRMED NOT IMPLEMENTED

`razorpay-webhook` handles only payment-side events (grep for "refund" in `helpers.ts`/`index.ts` returned no matches). No pg_cron job or scheduled reconciliation for refunds was found (only `reconcile_stale_payments`, which is payments-only and must be invoked externally — no evidence of a cron wiring it up was checked in this pass; **NOT VERIFIED** whether anything calls it on a schedule).

### 8.12 Booking status vs payment status separation — CONFIRMED, genuinely separate enums

`booking_status` and `payment_status` are two distinct Postgres enums with different value sets (`booking_status` has 12 values incl. `awaiting_owner_approval`/`owner_rejected`/`external_conflict`; `payment_status` has 6: `pending, authorized, captured, failed, refunded, partially_refunded`). They are updated independently by different code paths. This satisfies the audit's architectural requirement — they are already two state machines, not one conflated column.

### 8.13 Does cancellation release the venue booking correctly? — CONFIRMED, for the cases that can cancel

`cancel_venue_booking` and `expire_stale_holds` both move the booking out of the statuses covered by `bookings_no_overlap` (to `cancelled`), which correctly frees the slot for the exclusion constraint. This works correctly for the `held`/`awaiting_owner_approval`/`pending` cases it actually covers. It is untested for `confirmed`, because no path there exists.

### 8.14 Races — CONFIRMED / PARTIALLY INFERRED

- **Cancellation vs payment confirmation:** `cancel_venue_booking` and `confirm_venue_booking` both operate under row-level locking (`FOR UPDATE`) scoped to the same booking row — CONFIRMED this prevents a concurrent cancel+confirm race on the *same* booking row. Not independently load-tested (read-only audit).
- **Cancellation vs owner approval:** not directly traced — `approve_venue_booking`/`reject_venue_booking` source was not read in this pass. **NOT VERIFIED.**
- **Two concurrent cancellations:** `cancel_venue_booking`'s `FOR UPDATE` + status guard makes a second concurrent call for the same booking a no-op returning `CANNOT_CANCEL` — **INFERRED**, not empirically tested.
- **Cancellation vs refund processing:** moot today since neither can happen to a `confirmed` booking through any live path (see 8.5).
- **Refund vs refund (double-submit):** CONFIRMED racy — see 8.9.

### 8.15-8.16 RLS/authorization for cancel, and client-side manipulation — CONFIRMED locked down

Covered in Section 6: no client-writable INSERT/UPDATE policy exists on `bookings` beyond the narrow `bookings_customer_cancel` UPDATE, and none at all on `payments`/`refunds`. Client code cannot directly set a booking to `confirmed`/`refunded`, cannot directly write a `payments` or `refunds` row, and cannot bypass `create-refund`'s server-side Razorpay call to fabricate a refund.

### 8.17-8.20 Failure-mode / double-processing questions

- **Razorpay succeeds, app update fails:** CONFIRMED unrecoverable today — see 8.10.
- **App requests refund but Razorpay response is lost (network drop mid-call):** the Deno function would throw and return an internal error — but if the `fetch` to Razorpay actually reached Razorpay and it processed the refund before the response was lost on the wire, the same unrecoverable gap as 8.10 applies. No idempotency key is sent to Razorpay's refund API in the current code (no header constructed for it), so even a client retry of the same logical request could create a second real refund at Razorpay's end, independent of the DB-level race in 8.9. **CONFIRMED via source read.**
- **Failed/pending refunds recoverable via reconciliation:** CONFIRMED NO — no reconciliation mechanism exists for refunds (8.11).
- **Double refund on an already-refunded/cancelled/completed booking:** the `existing` check in `create-refund` is the only backstop, and it's racy (8.9); the function also checks `booking.status !== 'confirmed'` to reject, which correctly rejects an already-`refunded` booking in the *non-racing* case, but see 8.9 for the racing case.

## 9. Concurrency Analysis (Phase 2 scope, summarized)

Reasoned from source, not tested destructively:
- **A/B (two users booking same slot; hold vs booking race):** CONFIRMED safe — `acquire_venue_hold` takes `pg_advisory_xact_lock(hashtextextended(venue_id||book_date))` before checking hold/booking overlap and inserting, serializing all hold attempts for a given venue+date; `bookings_no_overlap` is the DB-level backstop if the advisory lock were ever bypassed.
- **C (hold expiry racing a new booking):** CONFIRMED safe in the intended flow — `acquire_venue_hold` calls `expire_stale_holds()` at its own start, and a hold that's expired-but-not-yet-swept is still excluded by the `expires_at > now()` predicate in the overlap check itself, not just by the sweep.
- **D/E (payment confirmation vs another hold / two confirmations):** CONFIRMED safe for confirm-vs-confirm via `confirm_venue_booking`'s idempotent early-return on already-`confirmed`; confirm-vs-new-hold uses the same advisory lock key pattern.
- **F (cancellation racing a new hold):** row-level lock on the booking during cancel; the freed slot only becomes bookable once status flips, which is transactional — CONFIRMED no obvious window.
- Overall: the *booking* concurrency model is solid. The *refund* concurrency model (8.9) is the one confirmed gap.

## 10. Notification Delivery Audit

Not deeply traced in this pass beyond what surfaced incidentally: `confirm_venue_booking` inserts directly into `public.notifications` synchronously as part of its transaction (no queue/retry visible at that call site). Whether there is a broader retry/backoff worker was **not independently re-verified** here. **NOT VERIFIED — recommend a dedicated follow-up pass**, per the "don't invent, document what's missing" instruction rather than guessing.

## 11-12. Confirmed Findings by Severity

**P0 — Security/Data-Integrity:** None found in the areas inspected. RLS/RPC grants on booking/payment/refund tables are correctly locked down.

**P1 — Financial/Booking Correctness (all CONFIRMED):**
1. `create-refund` Edge Function is not deployed to the live project — every refund request fails today (8.7).
2. No cancellation path exists for a `confirmed` (paid) booking, by customer, owner, or admin (8.2, 8.5).
3. Refund amount is client-proposed and bound-checked, not calculated from `cancellation_policy` (8.4, 8.3).
4. `refunds.payment_id` has no unique constraint — duplicate-refund race under concurrent/retried requests (8.9).
5. Non-atomic refund sequence with no compensation/reconciliation if Razorpay succeeds but the DB writes fail; no idempotency key sent to Razorpay itself (8.10, 8.17).
6. No webhook/reconciliation handling for Razorpay refund events at all (8.11).

**P2 — Production Functionality Gap:**
1. `reconcile_stale_payments` is EXECUTE-granted to `anon`/`PUBLIC` — should be restricted (Section 6).
2. Local migration files and the live database's applied-migration history are substantially divergent (Section 1/13) — undermines trust in "what's actually deployed."
3. Two Supabase projects exist and only one was confirmed as the active target — needs explicit product confirmation (Section 2).

**P3 — Maintainability/Documentation:**
1. `refunds.status` enum values `requested`/`approved`/`rejected` are defined but never used by current code (jumps straight to `processed`) — dead states or an unfinished approval-gated refund flow.
2. Several notification/reconciliation surfaces were not re-verified this pass and should be revisited explicitly rather than assumed.

## 13. Migration/Repo-vs-Database Divergence (supplementary, CONFIRMED)

Local `supabase/migrations/` contains 37 files; the live project's applied-migration history (`list_migrations`) contains 33 entries. These are **not the same set** — examples present in the live database but absent as local files: `external_channel_inventory`, `external_channel_functions`, `external_channel_provider_seed`, `external_channel_correctness_hardening`, `external_channel_anon_lockdown`, `feature_flag_cms_document_keys`, `feature_flag_category_catalog_key`, `booking_approval_rpc_grants_hardening`, `fix_publish_venue_sections_trigger_guard`, and others. Conversely, several local files (`gap_closure_analytics_support_storage`, `cms_banners_feature_flags`, `fix_coupon_currency_encoding`, `grant_dev_test_roles`) do not appear in the live history at all. Compounding this, `git status` shows several migration files staged as deleted (`DA`) while still present on disk. **This means neither "the migrations folder" nor "git log" alone is a reliable source of truth for what's actually live** — only direct inspection of the database (as done throughout this report) is trustworthy right now. This is very likely the root cause of the earlier unverified report's incorrect claims about capacity-aware functions/migrations that don't actually exist.

## 14. Product Decisions Required

1. Which Supabase project is actually production: `bookmyspace-dev` (`zykxneztahxbjduagutv`, used in this audit) or `BookMySpace` (`ehxuygrsyaknhhsaihhx`, not inspected)?
2. What is the intended cancellation policy (fee schedule / time windows) that `bookings.cancellation_policy` was meant to encode? It's currently inert.
3. Should owner/admin be able to cancel a confirmed booking (with refund) at all, and under what conditions? No such capability exists today in any form.
4. Should refunds require an approval step (the `requested`/`approved` states already defined in the schema suggest this was intended) before hitting Razorpay, given the double-refund race in the current instant-refund design?

## 15. Recommended Implementation Order (not authorized to build yet)

1. Reconcile git/migration state to one trustworthy source of truth (Section 13) — prerequisite for any further work.
2. Fix the refund idempotency gap at the database level (unique constraint on `refunds.payment_id` or equivalent) — small, self-contained, high-value.
3. Redesign `create-refund` to write a `requested` row and reserve the refund *before* calling Razorpay, updating to `processed`/`failed` after, with a webhook or scheduled reconciler as the authoritative status source — addresses 8.10 and 8.11 together.
4. Add a real cancellation path for confirmed bookings (customer within policy window, and/or owner/admin) that routes through the hardened refund flow — addresses 8.2/8.5.
5. Only then deploy `create-refund` to the live project.
6. Revoke the broad `reconcile_stale_payments` grant.

## 16. Explicitly Rejected Speculative Changes

- No multi-unit/capacity model was implemented, proposed as a fix, or assumed. The single-venue-wide-booking model is confirmed correct and untouched.
- `bookings_no_overlap` was not modified and no `slot_id` was added to it.
- No new refund schema/migration was created — `refunds` table already exists and was only read, not altered.
- The earlier report's claims (`20260915*` migrations, `get_slot_available_units()`, `list_slot_availability_for_date()`, `notification_channel_enabled()`, capacity-aware holds/tests) were checked against this audit's findings: **none of those objects appeared in any query run against the live database in this session**, consistent with the instruction to treat that prior report as unverified.

## 17. Final GO / NO-GO Assessment

**NO-GO on refunds/cancellation.** The refund flow is non-functional in production (missing deployment) and unsafe even once deployed (race + non-atomicity + no reconciliation). No confirmed booking can currently be cancelled by anyone through the app. This is a real, evidence-backed production blocker — independent of, and unrelated to, the capacity question that was correctly ruled out of scope.

**Booking-exclusivity invariant: GO**, with two follow-ups worth closing before calling it fully verified: independently re-read `request_venue_booking`/`approve_venue_booking`/`reject_venue_booking` for the same overlap guarantees confirmed on the other two RPCs (Section 5), and reconcile the git/migration divergence (Section 13) so future audits aren't working from a moving target.

---
*Audit executed read-only against Supabase project `zykxneztahxbjduagutv` (bookmyspace-dev) and the working tree at `~/BookMyspace_Andriod` (branch `fix/ios-bookmyspace-ui`, HEAD `795a235`) on 2026-09-14. No files, migrations, database objects, or Git state were modified.*
