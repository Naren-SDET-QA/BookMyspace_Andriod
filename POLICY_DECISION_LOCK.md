# POLICY_DECISION_LOCK.md — BookMySpace Cancellation & Refund Policy

Phase 6 of the Cancellation & Refund Policy Architecture v1. This document
records decisions D1–D12 as **owner-approved on 2026-09-14** and locks them
as the authoritative basis for Phase 7 implementation.

---

### D1 — Eligibility cutoff
**Architecture question:** Should there be a separate hard eligibility cutoff (e.g. a flat "no cancellation within N hours" rule), independent of the refund-percentage tiers?
**Decision (APPROVED):** No separate hard cutoff. Eligibility to cancel and the refund percentage are both driven by the same tier table (D2). A booking can always be *cancelled*; what varies by tier is how much is refunded, down to 0%.
**Consequence:** One rule set to maintain and test, not two. A <24h cancellation is still permitted — it simply refunds 0%, functioning as the de facto cutoff without extra branching logic in the RPCs.

### D2 — Refund tier thresholds
**Architecture question:** What are the time-before-booking thresholds and refund percentages?
**Decision (APPROVED):** 48h+ before the booking start → 100%. 24–48h before → 50%. Less than 24h before → 0%.
**Consequence:** `calculate_refund_amount` must compute hours-until-booking-start from the booking's own `book_date`/`start_time` at the moment of cancellation (not at booking time), and must use the values in this exact table — no per-venue override of the percentages themselves.

### D3 — Cancellation fee
**Architecture question:** Is a separate cancellation fee charged on top of the tier reduction?
**Decision (APPROVED):** No cancellation fee. The tier percentage in D2 is the entire effect; no additional flat or percentage fee is subtracted.
**Consequence:** `calculate_refund_amount` has no fee term. `refundable_amount = captured_amount * tier_percent / 100`, full stop.

### D4 — Tax treatment on refund
**Architecture question:** Is tax refunded in full, withheld entirely, or refunded proportionally to the refundable amount?
**Decision (APPROVED):** Tax is refunded proportionally with the refundable booking amount — i.e. at the same tier percentage.
**Consequence:** Since `payments.amount` (the captured amount) already includes `bookings.tax_amount`, applying the tier percentage to the captured amount already refunds tax proportionally. No separate tax carve-out is needed in the calculation, but the tax component should be reported in the returned/audited breakdown for transparency.

### D5 — Platform-fee deduction on refund
**Architecture question:** Should a platform fee be deducted from the refund?
**Decision (APPROVED):** Refund the actual captured booking amount at the tier percentage; do not invent or deduct a platform-fee line that isn't already reflected in `payments.amount`.
**Consequence:** No new "platform_fee" column or deduction is introduced in this phase. If a real platform-fee model exists later, it must be a separate, explicitly-approved decision — not inferred here.

### D6 — Razorpay processing-fee treatment
**Architecture question:** Who absorbs the Razorpay gateway processing fee on a refunded transaction — the platform or the customer?
**Decision (APPROVED):** The platform absorbs the Razorpay processing fee. The customer's refund is not reduced by the gateway's fee.
**Consequence:** Refund amounts calculated in the DB are gross of gateway fees; any Razorpay-side fee retention is a platform cost tracked outside the customer-facing refund amount (e.g. in payout/ledger reconciliation), never subtracted from `refunds.amount`.

### D7 — Venue-owner-initiated cancellation
**Architecture question:** May a venue owner cancel a confirmed (paid) booking, and if so what does the customer receive?
**Decision (APPROVED):** Allowed. When the venue owner cancels, the customer receives a 100% refund of the eligible (captured) amount, regardless of the D2 tier that would otherwise apply, and bears no cancellation penalty.
**Consequence:** Owner-initiated cancellation is a distinct code path from customer self-cancellation — it must not call the tiered `calculate_refund_amount` percentage logic, since the customer did nothing to trigger a reduced refund. It refunds 100% of the captured payment.

### D8 — Admin-initiated cancellation
**Architecture question:** May an admin cancel a confirmed booking and override the refund amount, and is there a cap?
**Decision (APPROVED):** Allowed, with a mandatory reason and full audit trail. No artificial monetary cap beyond the captured payment amount itself (an admin cannot refund more than was captured).
**Consequence:** The existing `admin_cancel_booking` bound-check (amount ≤ captured payment) is correct and is retained unchanged; no additional cap is added.

### D9 — Confirmation without a policy
**Architecture question:** May a new booking confirm (payment capture → CONFIRMED) for a venue that has no cancellation policy set?
**Decision (APPROVED):** No. New bookings must be blocked from confirming when the venue has no valid cancellation policy.
**Consequence:** `confirm_venue_booking` must check for a valid `venues.cancellation_policy` before transitioning `pending` → `confirmed`, and fail deterministically (no state mutation, no payment loss — payment stays `captured` but unconsumed, refundable via the existing admin/reconciliation path) when absent.

### D10 — Policy editability and versioning
**Architecture question:** Can a venue owner edit their policy after it's set, and if so, does it affect past bookings?
**Decision (APPROVED):** Yes, the venue owner can edit the policy. Changes apply only to bookings confirmed *after* the change; every prior version is retained in history.
**Consequence:** `venues.cancellation_policy` stays the single live/editable pointer; every write is additionally appended to `venue_cancellation_policy_history` before being applied. A booking's snapshot in `bookings.cancellation_policy`, taken at confirmation time, is what governs that booking forever after — a later policy edit cannot retroactively change an already-confirmed booking's refund math.

### D11 — Policies per venue
**Architecture question:** Can a venue have more than one active cancellation policy (e.g. per room, per date range)?
**Decision (APPROVED):** One policy per venue.
**Consequence:** A single `jsonb` column on `venues` is sufficient; no per-slot/per-category policy table is introduced in this phase.

### D12 — Zero-amount refund rows
**Architecture question:** When a cancellation resolves to a 0% refund, should a `$0` row still be inserted into `refunds` for audit purposes?
**Decision (APPROVED):** Do not create a `$0` refund row unless the existing implementation already requires one for audit/state consistency.
**Consequence:** The existing `cancel_confirmed_booking`/`admin_cancel_booking` functions already gate the `insert into refunds` behind `coalesce(refundable_amount, 0) > 0` — this behavior is preserved as-is. The full audit trail (percent, tier, policy source) is recorded in `audit_logs` regardless of whether a `refunds` row exists, so no information is lost at 0%.

---

## Verified schema/payment assumptions (read against live `bookmyspace-dev`, read-only)

- `venues.cancellation_policy jsonb` **already exists** in the deployed schema (nullable, no default) — it is the live/editable policy column referenced by D1/D9/D10/D11.
- `bookings.cancellation_policy jsonb` **already exists** in the deployed schema (nullable) — it is the booking-time snapshot column referenced by D2/D5/D9/D10/D12.
- Neither column is currently populated on any of 555 venues or 23 bookings in `bookmyspace-dev` (confirmed via the existing migration's own header comment and schema inspection) — i.e. **no production data will be affected** by adding history/versioning around these columns.
- `payments.amount` is the captured gross amount and, per the schema, is expected to already equal `bookings.total_amount` (`amount + tax_amount - discount_amount`, effectively `total_amount`) — this is the basis for D4's "tax refunded proportionally automatically" reasoning. **This assumption must be verified against actual `create-payment-order`/`verify-payment` Edge Function code before relying on it in production**, since if `payments.amount` were ever captured net of tax or net of a fee, D4/D5's math would be wrong.
- No `platform_fee` column exists anywhere in `payments`, `bookings`, or `refunds` — confirms D5's "no fee to invent" is accurate to the current schema, not just a policy choice.
- Razorpay's own processing-fee amount is **not stored anywhere in this schema** (no `gateway_fee` column found). D6 ("platform absorbs it") is therefore a statement about who bears an off-ledger cost, not something enforced in `refunds`/`payments`; if the platform later wants to *track* that cost, a new column/table is a separate decision.
- `refunds` has a partial unique index `refunds_payment_id_active_uq` (`payment_id` unique where `status <> 'failed'`) already deployed as the idempotency backstop for duplicate/retried refund requests — reused as-is (D12, duplicate-refund test coverage).
- No `venue_cancellation_policy_history` table exists yet — created fresh in Phase 7 per D10.
- No RPC currently updates `venues.cancellation_policy` (owner-facing) or performs owner-initiated cancellation (`owner_cancel_booking` does not exist yet) — both created fresh in Phase 7 per D7/D10.
- `confirm_venue_booking` (deployed) does **not** currently snapshot `venues.cancellation_policy` into `bookings.cancellation_policy`, and does **not** block confirmation for a policy-less venue — this is the exact gap Phase 7 closes per D9.
- `calculate_refund_amount` (in the undeployed `20260914170000_refund_cancellation_domain.sql` migration) currently only recognizes a flat, already-decided `refund_percent` key and returns `NULL` otherwise — Phase 7 replaces this with the D2 tiered calculation while keeping its `NULL`-when-unresolvable fallback for bookings confirmed before this policy existed (D12/"historical booking governed by its own snapshot").

---

`PHASE 6 STATUS: OWNER-APPROVED — PROCEEDING TO PHASE 7`
