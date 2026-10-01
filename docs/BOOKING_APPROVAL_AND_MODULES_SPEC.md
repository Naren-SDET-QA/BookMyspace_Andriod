# BookMySpace — Owner-Approval Booking + Plug-and-Play Modules Spec

Read alongside `BOOKMYSPACE_MASTER_PROMPT.md` (authoritative). This spec refines master
prompt §21/§28/§84 and Codex prompt Phase 14/17. Where this document and the master prompt
disagree on the booking state machine, this document wins — it inserts an owner-approval
gate that §28 does not currently have.

---

# PART A — OWNER-APPROVED BOOKING

## A0. The trap: `confirm_venue_booking` must change, or approval is cosmetic

The existing RPC `confirm_venue_booking(p_booking_id, p_user_id, p_payment_ref,
p_payment_method)` confirms a booking **on payment alone**. It is `security definer`, takes
an advisory lock, and is idempotent (re-confirming returns success) — all good — but its
only precondition is payment.

If an approval gate is added anywhere else without changing this function, a paid booking
still reaches `confirmed` with no owner involvement. The payment webhook path would quietly
bypass the entire feature. **This is the single highest-risk item in this spec.**

Required: confirmation must depend on **both** conditions, checked server-side in one
transaction — payment settled **AND** owner approval recorded. Neither alone may produce
`confirmed`, a receipt, or a success screen.

## A1. Blocking decisions — resolve before implementation

### DECISION 1 — Where does payment sit relative to approval?

You said rejection/expiry must never "show success or charge as confirmed." That phrase is
ambiguous between *never charge at all* and *never present the charge as a confirmed
booking*. The options differ materially:

- **(a) Approve first, then pay.** Customer requests → owner approves → customer gets a
  pay window (e.g. 30–60 min) → payment → confirmed. No money moves before approval, so
  rejection/expiry is trivially clean. Risk: approved customers who never pay; the owner
  held a slot for nothing. Needs a payment-window timer and slot release.
- **(b) Authorize at request, capture on approval.** Funds authorized up front, captured
  only when the owner accepts, voided on reject/expiry. Best UX and best conversion.
  **Constraint: this depends on payment method.** Razorpay supports authorize-then-capture
  for cards with a limited authorization validity window; UPI — which dominates in India —
  does not do classic auth-holds, and blocking UPI funds requires a mandate/AutoPay-style
  product, which is a separate integration with its own onboarding. So (b) is not uniformly
  available across the methods your customers actually use. Verify current Razorpay
  capability for your account before choosing this.
- **(c) Charge at request, refund on rejection.** Simplest to build, worst outcome: real
  money is taken for bookings that are then rejected, plus refund latency and support load.
  Closest to what your instruction says to avoid.

**Recommendation: (a) as the default**, with (b) available later per payment method if
Razorpay auth-capture is confirmed for your account. (a) satisfies your rule with no
payment-method caveats and no refund exposure.

### DECISION 2 — Competing requests for the same slot

Two customers request the same venue/date/slot while the first awaits approval. Either:

- **Exclusive** — the first request blocks the slot; others see it unavailable. Simple,
  fair-looking, but one slow owner freezes a slot for everyone.
- **Competing** — multiple requests may await the same slot; the owner accepts one and the
  system auto-rejects the rest atomically. Better inventory utilisation, but the UI must
  never imply a request is secured, and the auto-reject must be transactional.

This must be decided because it changes what "available" means in the availability recheck
and in search results. **Recommendation: exclusive at launch** — it is far easier to make
correct, and competing requests can be added later behind the module flag from Part B.

### DECISION 3 — Approval SLA and who may approve

Define: the approval window (owner response deadline), what happens at expiry (auto-reject),
whether an org may have multiple approvers, and whether platform admin may approve on an
owner's behalf (and if so, it must be audit-logged distinctly as an admin override, never
recorded as the owner's own decision).

## A2. Target state machine

```
                    availability check (live)
                              │
                      acquire_venue_hold
                              │
                      status: held
                              │
                    customer submits request
                              │
              status: awaiting_owner_approval        ← NEW
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   owner accepts        owner rejects         SLA expires
        │                     │                     │
        │              status: owner_rejected  status: approval_expired   ← NEW
        │                     │                     │
        │                     └──── slot released ──┘
        │                          no charge, no receipt
        │
   re-verify availability (must still hold)          ← NEW, mandatory
        │
   status: pending  ──► payment ──► Razorpay webhook
        │                                  │
        └──────────────────────────────────┤
                                           │
              confirm_venue_booking: requires payment settled
                          AND owner approval recorded
                                           │
                                  status: confirmed
                                  receipt issued
```

Statuses to add to the existing enum (`held, pending, confirmed, completed, cancelled,
refunded, no_show`): **`awaiting_owner_approval`**, **`owner_rejected`**,
**`approval_expired`**. Add them in both the DB check constraint and
`BookingStatus.fromDb` / `dbValue` in `lib/features/booking/domain/booking.dart`.

Note `BookingStatus.fromDb` currently falls through to `_ => BookingStatus.pending` for
unknown values. With new statuses in the DB and an older client, a rejected booking would
render as *pending* — misleading in exactly the wrong direction. Change the fallback to an
explicit `unknown` that renders as a neutral "status unavailable" state rather than
impersonating a live booking.

## A3. Hold semantics

`acquire_venue_hold` currently defaults to `p_hold_minutes = 10`. Ten minutes is a payment
window, not an owner-response window. Two distinct timers are needed:

| Timer | Applies to | Typical | On expiry |
|---|---|---|---|
| Checkout hold | `held` → request submitted | 10 min (existing) | release slot |
| Approval window | `awaiting_owner_approval` | hours (per Decision 3) | `approval_expired`, release slot |
| Payment window | approved → paid | 30–60 min (Decision 1a) | release slot, booking cancelled |

Expiry must be enforced **server-side** by a scheduled job — never by a client timer, and
never only on next read. A client that never reopens the app must not leave a slot frozen.
The existing `reconcile_stale_payments` function is the natural pattern to follow.

## A4. Mandatory availability recheck

Availability is verified twice: once when the request is created, and again at the moment
of owner acceptance, inside the same transaction that records the approval. Between those
two points the owner may have blocked the date, edited the slot, or another booking may
have confirmed. Acceptance against a no-longer-available slot must fail cleanly with a
distinct error the owner UI explains — never silently confirm.

## A5. Idempotency and concurrency

- `acquire_venue_hold` already takes `p_idempotency_key uuid` — extend the same discipline
  to approve/reject: a repeated approve must be a no-op returning the same result, not a
  second state transition.
- Keep the advisory-lock pattern already used in `confirm_venue_booking` for the
  approve/reject RPCs.
- `register_webhook_event` already provides webhook idempotency — reuse it; a webhook
  replay must never re-confirm or double-charge.
- Approve and reject must be a single atomic RPC each (`security definer`, `search_path`
  pinned), never a client-side multi-step update.

## A6. Authorization

Approve/reject is restricted to the owning organisation via the existing helpers
(`is_org_owner`, `owns_venue`, `get_owner_user_id`). Hiding the button in Flutter is not
authorization — RLS and the RPC must both refuse a non-owner. Platform admin override, if
allowed by Decision 3, goes through `is_platform_admin` and is audit-logged as an override.

## A7. Notifications

At minimum: owner notified on new request (with the approval deadline), customer notified
on accept / reject / expiry, customer notified when payment is due and when it is about to
expire. Notification copy must never say "confirmed" before `confirmed` is the actual
status. Use the existing notification architecture; do not build a parallel one.

## A8. Audit

Every transition writes an audit row: actor, role, action, booking id, venue id, from
status, to status, timestamp, reason where supplied, and whether it was an admin override.
Never log payment secrets.

## A9. Tests that must exist

Money- and trust-critical, so these are non-negotiable:

1. Payment settles but owner never approves → **never** `confirmed`, no receipt.
2. Owner approves but payment never completes → **never** `confirmed`, slot released.
3. Owner rejects → no charge (or voided authorization under 1b), no receipt, UI shows
   rejected, not pending.
4. Approval window expires → `approval_expired`, slot released, no charge.
5. Webhook replay after confirmation → idempotent, no double charge, no duplicate receipt.
6. Double approve (rapid double-tap) → single transition.
7. Owner accepts a slot that became unavailable → clean failure, no confirmation.
8. Two requests, same slot → per Decision 2, deterministic outcome, no double-booking.
9. Non-owner attempts approve → refused by RLS **and** by the RPC.
10. Old client receives a new status value → renders neutral, never "pending".

---

# PART B — PLUG-AND-PLAY MODULES

## B0. The boundary on "without code changes"

Admin configures **parameters of behavior that is already implemented**. Admin does not
author new behavior. If "no code changes" is read literally, the natural next step is a
system that evaluates admin-supplied code or dynamic expressions — that is a remote code
execution hole reachable from a web console, and it must not be built. State this boundary
explicitly in the implementation prompt.

Concretely: admin may enable the referrals module and set its reward amount and expiry.
Admin may not define what a referral *is*.

## B1. Registry model

Each module declares a **manifest in code** (the contract) and stores **state in the
backend** (the configuration):

Manifest, in code, per module: stable id, display name, version, description, which
platforms it can run on, whether it has backend dependencies, its config schema (typed keys
with defaults, ranges, and validation), and its safe-disabled behavior.

State, in the backend: enabled/disabled, config values, platform overrides, plus
`updated_by` / `updated_at` for audit.

The `feature_flags` table created on 2026-09-12 is the natural home for the enable/disable
state; config values need either a JSONB column on that table or a companion
`module_config` table. Do not invent a second parallel flag system.

## B2. Validation and safety

- Config is validated against the manifest schema **server-side** on write, and again on
  read before use. A value outside the declared range is rejected at write time.
- An invalid or missing config falls back to the manifest default — never to a crash, and
  never to a half-configured state.
- A disabled module must leave no broken affordance: no dead nav entry, no button that
  errors, no empty screen. Its absence is a designed state.
- Disabling a module must never destroy its data. Re-enabling restores the prior state.
- A module may not be enabled on a platform its manifest says it cannot support (master
  prompt §82).

## B3. Modules that are genuinely optional

Referrals, rewards/coupons, events, courses, reviews, favorites, analytics, support,
external integrations and MCP connectors, CMS surfaces, and — per Decision 2 above —
competing booking requests.

Core booking, payments, authentication, search, and venue management are **not** optional
modules. Do not put a kill switch on the parts of the product that must always work; a flag
that can disable payments is an outage waiting to happen.

## B4. Approval mode as configuration

The owner-approval flow in Part A should itself be configurable rather than hardcoded, per
venue or per category: `instant_confirm` versus `request_to_book`. This is the cleanest
expression of the plug-and-play goal, and it lets you pilot approval on a subset of venues
before making it universal.

Two hard rules: changing the mode must never alter bookings already in flight, and
`instant_confirm` must still satisfy every payment rule in the master prompt — it removes
the owner gate only, not the server-authoritative confirmation.

## B5. Tests

Enabled, disabled, invalid config, missing config, unsupported platform, disable-then-
re-enable preserving data, config change mid-session, and non-admin attempting a config
write (must be refused server-side).
