-- =============================================================================
-- Fix: Phase 6/7 RPCs unintentionally executable by anon, and a NULL-auth.uid()
-- authorization bypass in cancel_confirmed_booking.
--
-- ROOT CAUSE #1 (anon EXECUTE on Phase 6/7 RPCs):
--   The bookmyspace-dev project carries a stale
--   `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ... ON FUNCTIONS TO ...
--   anon ...` (set up at project init, executed as the `postgres` role) which
--   auto-grants EXECUTE to `anon` on every NEW function created in schema
--   `public`, regardless of any `REVOKE ALL ... FROM PUBLIC` the function's
--   own migration performs immediately afterward. `REVOKE ALL FROM PUBLIC`
--   only revokes the PUBLIC pseudo-role grant; it does NOT touch a
--   *default privilege* that separately, explicitly names `anon`. This is
--   why apply_refund_result, calculate_refund_amount,
--   cancel_confirmed_booking, admin_cancel_booking, owner_cancel_booking,
--   update_venue_cancellation_policy and
--   set_cancellation_policy_rollout_stage all show `anon = true` in
--   has_function_privilege checks despite their defining migrations doing
--   the right REVOKE/GRANT dance.
--
--   Fix (a): reset the default privilege itself, as the same role
--   (`postgres`) that Supabase's migration runner executes as, so it stops
--   auto-granting `anon` EXECUTE on functions created from this point
--   forward. This does not retroactively touch already-existing functions'
--   grants (default privileges only apply at CREATE time), which is why
--   step (b) below adds explicit per-function REVOKE/GRANT statements for
--   the 7 affected functions.
--
-- ROOT CAUSE #2 (NULL-auth.uid() bypass in cancel_confirmed_booking):
--   The authorization check
--     `if v_booking.user_id <> auth.uid() then ... NOT_AUTHORIZED ... end if;`
--   uses `<>` against `auth.uid()`. In SQL/PL-pgSQL, comparing anything to
--   NULL yields NULL, and `IF NULL THEN` is treated as false (only TRUE
--   enters the branch). When `auth.uid()` is NULL - which is exactly the
--   anon/unauthenticated case - the whole condition evaluates to NULL, the
--   "not authorized" branch is skipped, and execution falls through as if
--   the caller were authorized. Combined with root cause #1 (anon could
--   call this function at all), an anonymous caller could cancel someone
--   else's confirmed booking.
--
--   Fix (c): change the check to
--     `if auth.uid() is null or v_booking.user_id is distinct from auth.uid() then`
--   which explicitly rejects a NULL auth context first, and uses
--   `IS DISTINCT FROM` (NULL-safe inequality) for the ownership comparison.
--   No other line of the function is touched; all refund-calc calls,
--   status transitions, audit logging and refund bookkeeping are preserved
--   byte-for-byte from the version defined in
--   20260914170000_refund_cancellation_domain.sql.
--
-- Scope: this migration only changes GRANT/REVOKE privileges and the single
-- authorization-check line described above. It makes zero changes to any
-- refund-tier calculation, tax treatment, idempotency, concurrency,
-- webhook, or D9 rollout-stage logic.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- (a) Stop auto-granting anon EXECUTE on newly created functions in `public`.
--     Executed as the same role (postgres) that the original default-privilege
--     grant and Supabase's migration runner both use, so this actually reverses
--     it for future CREATE FUNCTION statements in this schema.
-- -----------------------------------------------------------------------------
alter default privileges in schema public revoke execute on functions from anon;

-- -----------------------------------------------------------------------------
-- (b) Explicit per-function grants for the 7 functions already affected by the
--     stale default privilege (default privileges are not retroactive, so each
--     needs its grants corrected directly).
-- -----------------------------------------------------------------------------

-- apply_refund_result: service_role only. Never callable by authenticated
-- clients (it is invoked internally from the payment-webhook trust boundary).
revoke all on function public.apply_refund_result(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.apply_refund_result(uuid, text, text, text) to service_role;

-- calculate_refund_amount: read-only calculation, safe for authenticated users
-- (e.g. to preview a refund before confirming cancellation) and service_role.
revoke all on function public.calculate_refund_amount(uuid) from public, anon;
grant execute on function public.calculate_refund_amount(uuid) to authenticated, service_role;

-- cancel_confirmed_booking: customer-initiated cancellation. authenticated only.
revoke all on function public.cancel_confirmed_booking(uuid, text) from public, anon;
grant execute on function public.cancel_confirmed_booking(uuid, text) to authenticated, service_role;

-- admin_cancel_booking: admin-initiated cancellation. authenticated only
-- (function body itself enforces the admin-role check).
revoke all on function public.admin_cancel_booking(uuid, numeric, text) from public, anon;
grant execute on function public.admin_cancel_booking(uuid, numeric, text) to authenticated, service_role;

-- owner_cancel_booking: venue-owner-initiated cancellation. authenticated only
-- (function body itself enforces the owner-role check).
revoke all on function public.owner_cancel_booking(uuid, text) from public, anon;
grant execute on function public.owner_cancel_booking(uuid, text) to authenticated, service_role;

-- update_venue_cancellation_policy: owner/admin policy management. authenticated only.
revoke all on function public.update_venue_cancellation_policy(uuid, boolean) from public, anon;
grant execute on function public.update_venue_cancellation_policy(uuid, boolean) to authenticated, service_role;

-- set_cancellation_policy_rollout_stage: admin-only rollout control (D9 stage
-- gate). authenticated only (function body enforces the admin-role check).
revoke all on function public.set_cancellation_policy_rollout_stage(text) from public, anon;
grant execute on function public.set_cancellation_policy_rollout_stage(text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- (c) cancel_confirmed_booking: NULL-safe authorization check.
--     Identical to the function defined in
--     20260914170000_refund_cancellation_domain.sql except for the single
--     authorization-check line (marked below). No other logic, comment,
--     variable name, or formatting is changed.
-- -----------------------------------------------------------------------------
create or replace function public.cancel_confirmed_booking(
  p_booking_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_booking record;
  v_calc record;
  v_refund_id uuid;
begin
  select b.* into v_booking
  from public.bookings b
  where b.id = p_booking_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;

  if auth.uid() is null or v_booking.user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'NOT_AUTHORIZED');
  end if;

  if v_booking.status <> 'confirmed' then
    return jsonb_build_object(
      'success', false, 'error_code', 'CANNOT_CANCEL',
      'current_status', v_booking.status
    );
  end if;

  select * into v_calc from public.calculate_refund_amount(p_booking_id);

  if v_calc.captured_payment_id is not null and v_calc.refundable_amount is null then
    return jsonb_build_object(
      'success', false, 'error_code', 'CANCELLATION_POLICY_UNDEFINED',
      'detail', 'No cancellation_policy with an explicit refund_percent is set on this booking or its venue. An admin must decide the refund via admin_cancel_booking, or product must define the policy.'
    );
  end if;

  update public.bookings
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  where id = p_booking_id;

  -- bookings_no_overlap already excludes 'cancelled' from its predicate, so
  -- the venue slot is released as a side effect of this single UPDATE,
  -- inside this same transaction. No separate release step exists.

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking_cancelled', 'booking', p_booking_id,
    jsonb_build_object(
      'venue_id', v_booking.venue_id,
      'from_status', v_booking.status,
      'to_status', 'cancelled',
      'actor_role', 'customer',
      'reason', p_reason,
      'captured_payment_id', v_calc.captured_payment_id,
      'refundable_amount', v_calc.refundable_amount,
      'policy_source', v_calc.policy_source
    )
  );

  if v_calc.captured_payment_id is not null and coalesce(v_calc.refundable_amount, 0) > 0 then
    begin
      insert into public.refunds (payment_id, booking_id, amount, reason, status)
      values (v_calc.captured_payment_id, p_booking_id, v_calc.refundable_amount, p_reason, 'requested')
      returning id into v_refund_id;
    exception when unique_violation then
      select id into v_refund_id from public.refunds
      where payment_id = v_calc.captured_payment_id and status <> 'failed'
      order by created_at desc limit 1;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'cancelled',
    'refund_id', v_refund_id,
    'refundable_amount', v_calc.refundable_amount
  );
end;
$$;

-- Re-apply the same grants as (b) above; CREATE OR REPLACE FUNCTION preserves
-- existing grants in Postgres, but this is kept explicit and idempotent.
revoke all on function public.cancel_confirmed_booking(uuid, text) from public, anon;
grant execute on function public.cancel_confirmed_booking(uuid, text) to authenticated, service_role;
