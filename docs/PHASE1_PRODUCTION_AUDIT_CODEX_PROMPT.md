# BookMySpace — Phase 1 Read-Only Production Audit (Codex Prompt)

Continue the BookMySpace production-readiness work from the investigation above.

IMPORTANT:

* Treat the latest investigation as authoritative.
* The previous report claiming `20260915*` migrations, `get_slot_available_units()`, `list_slot_availability_for_date()`, `notification_channel_enabled()`, capacity-aware holds, and related tests was unverified and must NOT be treated as completed work.
* Do NOT implement multi-unit capacity.
* Do NOT change `bookings_no_overlap`.
* Do NOT add `slot_id` to the exclusion constraint.
* Do NOT redesign the booking inventory model.
* Do NOT modify files, database objects, migrations, or Git during the first phase.
* Do NOT commit, push, merge, deploy, or reset anything.

## PHASE 1 — READ-ONLY PRODUCTION AUDIT

First establish the real current state:

1. Verify:
   * repository path
   * branch
   * HEAD commit
   * `git status`
   * existing migrations
   * actual Supabase project/environment being inspected
2. Re-read the actual live definitions of:
   * `acquire_venue_hold()`
   * `confirm_venue_booking()`
   * `release_venue_hold()`
   * `available_time_slots()`
   * `expire_stale_holds()`
   * relevant booking/hold triggers and policies
3. Verify the booking invariant end-to-end:

CURRENT EXPECTED INVARIANT:
   * A venue is exclusive for overlapping time ranges.
   * Different `slot_id` values do NOT permit simultaneous occupancy.
   * `quantity` is currently effectively always `1`.
   * There is no active per-slot capacity/inventory model.
   * `bookings_no_overlap` is the database-level hard backstop.
   * Advisory locking is used by booking RPCs to serialize the venue/date booking path.

4. Trace EVERY booking creation/update path in:
   * Flutter/client code
   * RPCs
   * Edge Functions
   * triggers
   * admin/owner workflows
   * payment confirmation/webhook paths

   Confirm whether ANY path can bypass the intended invariant.

5. Audit `bookings_no_overlap`:
   * exact definition
   * exact status predicate
   * exact time-range semantics
   * NULL behavior
   * whether any booking status can escape the constraint
   * whether updates can accidentally bypass it

6. Audit authorization:
   * RLS on `bookings`
   * RLS on `booking_holds`
   * EXECUTE grants for all booking RPCs
   * SECURITY INVOKER vs SECURITY DEFINER
   * `search_path` safety for SECURITY DEFINER functions
   * whether client users can directly insert/update booking rows
   * whether service-role-only operations are properly protected

7. Audit payment/booking state transitions:
   * hold creation
   * Razorpay order creation
   * payment verification
   * webhook processing
   * confirmation
   * expiry
   * cancellation/refund
   * owner approval if applicable

   Identify any path that can mark a booking confirmed without the required server-side checks.

8. Audit notification delivery separately:
   * existing notification tables/functions
   * retry/backoff functions if they actually exist
   * Edge Functions
   * pg_cron jobs
   * triggers
   * all notification insertion paths

   Do NOT invent a worker or retry architecture yet.
   If retry/delivery functionality is incomplete, document exactly what exists and what is missing.

## PHASE 2 — CONCURRENCY ANALYSIS

Read-only only.
Determine whether the CURRENT implementation remains safe under:

A. Two users booking the same venue/time simultaneously.
B. One user acquiring a hold while another attempts a booking.
C. Hold expiry racing with a new booking.
D. Payment confirmation racing with another hold.
E. Two confirmations occurring concurrently.
F. Booking cancellation racing with a new hold.

Do not perform destructive tests against the shared database.
If concurrency cannot be safely tested, reason from:

* advisory locks
* exclusion constraints
* transaction boundaries
* isolation levels
* trigger behavior
* status predicates

Clearly distinguish proven behavior from inferred behavior.

## PHASE 3 — FIND REAL PRODUCTION BLOCKERS

Only identify issues supported by actual source/schema/live evidence.

Prioritize:
* P0 — security/data-integrity vulnerability
* P1 — double-booking/payment correctness issue
* P2 — production functionality gap
* P3 — documentation/test/maintainability issue

For every finding provide:
* exact object/file
* evidence
* impact
* reproduction path if safe
* recommended fix
* whether migration/code/config is required

Do NOT create fixes yet.

## PHASE 4 — CAPACITY QUESTION

Explicitly record:

"The current system does not implement per-slot multi-unit capacity."

Do NOT treat that as a bug unless there is actual product/source evidence showing that BookMySpace is supposed to support multiple independent units simultaneously.
If such evidence exists, quote/reference the exact source and stop for product confirmation before redesigning the schema.

## PHASE 5 — FINAL REPORT

Create/update a read-only audit report only if report-file creation is already part of the existing workflow; otherwise return the findings in the response.

Structure:

1. Workspace/Git state
2. Supabase environment
3. Current booking invariant
4. Booking creation/update paths
5. `bookings_no_overlap` analysis
6. RLS and RPC authorization
7. Payment/state-machine audit
8. Concurrency analysis
9. Notification delivery audit
10. Confirmed production blockers
11. Capacity/multi-unit conclusion
12. Recommended implementation order
13. Items requiring product/business confirmation

## FINAL RULE

Stop after the audit. Do not implement anything, do not create migrations, and do not touch Git/deployment.
The goal is to establish the REAL production baseline before any further code changes.

This should prevent the agent from getting pulled back into the nonexistent "units=3" work and give a trustworthy baseline before any further production changes.

---

## ADDENDUM — P1: REFUND + CANCELLATION LIFECYCLE (Mandatory)

Add REFUND + CANCELLATION as a mandatory P1 area of this architecture audit, alongside the Phase 1-5 scope above.

Do not implement anything yet.

Audit the complete cancellation/refund lifecycle in the actual BookMySpace repository and Supabase database.

Verify:

1. Customer cancellation flow.
2. Owner/admin cancellation flow.
3. Cancellation policy and where it is enforced.
4. Whether refundable amount is calculated SERVER-SIDE.
5. Whether paid bookings can be cancelled without refund processing.
6. Razorpay refund creation.
7. Razorpay refund verification/status handling.
8. Full vs partial refunds.
9. Duplicate cancellation protection.
10. Duplicate refund protection/idempotency.
11. Refund webhook/reconciliation if applicable.
12. Booking status vs payment status separation.
13. Whether cancellation releases the venue booking correctly.
14. Whether cancellation can race with:
    * payment confirmation
    * owner approval
    * another cancellation
    * refund processing
15. RLS and authorization for customer/owner/admin cancellation.
16. Whether client code can directly manipulate cancellation/payment/refund state.
17. What happens if Razorpay succeeds but the application/database update fails.
18. What happens if the application requests a refund but the Razorpay response is lost.
19. Whether failed/pending refunds are recoverable through reconciliation.
20. Whether completed/cancelled/refunded bookings can accidentally be refunded twice.

### Architectural requirement

BOOKING STATUS and PAYMENT/REFUND STATUS must be treated as separate state machines unless the existing implementation provides strong evidence otherwise.

Do not invent a new refund schema or migration during this audit.

### Classification

* P0 — security/data-integrity
* P1 — financial/refund/booking correctness
* P2 — production functionality
* P3 — maintainability/documentation

For every confirmed issue provide:

* exact source/database object
* evidence
* financial impact
* race/concurrency implications
* recommended fix
* migration/code/config requirements

Do not modify files, database, migrations, Git, or deployment.
Stop after the audit and return the findings.
