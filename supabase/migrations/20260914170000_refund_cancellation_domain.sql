-- Refund/cancellation domain: idempotency backstop, cancellation RPCs for
-- CONFIRMED (paid) bookings, and DB-intent-first refund processing support.
--
-- Scope: strictly additive, refund/cancellation domain only.
--   - does NOT modify bookings_no_overlap or any exclusion-constraint logic
--   - does NOT add capacity/units/slot-parallel-booking concepts
--   - does NOT touch venue_sections, category management, or any
--     migration-reconciliation item from the preflight
--   - does NOT alter cancel_venue_booking (the existing pre-payment
--     cancellation path is untouched)
--
-- PRODUCT DECISION OUTSTANDING (read before relying on the customer path):
-- as of 2026-09-14, 0 of 555 venues and 0 of 23 bookings in bookmyspace-dev
-- have any cancellation_policy populated. calculate_refund_amount() below
-- deliberately does NOT invent a fee schedule: it recognizes only an
-- explicit, already-decided top-level numeric "refund_percent" key (0-100)
-- if one is ever present in the jsonb, and returns NULL otherwise.
-- cancel_confirmed_booking() refuses (CANCELLATION_POLICY_UNDEFINED) rather
-- than guessing when a captured payment exists but no percent can be
-- resolved. Until product defines the actual policy shape/values, paid
-- bookings can only be cancelled-with-refund via admin_cancel_booking's
-- explicit, audited override amount.

-- 1. Idempotency backstop: at most one non-failed refund row per payment.
-- Closes the double-refund race (Phase1 audit 8.9): the INSERT itself is
-- now the concurrency gate, not a prior SELECT.
create unique index if not exists refunds_payment_id_active_uq
  on public.refunds (payment_id)
  where status <> 'failed';

comment on index public.refunds_payment_id_active_uq is
  'At most one refund row per payment may be outside the failed state at a '
  'time. Prevents concurrent/retried refund requests from creating two '
  'refunds for the same payment.';

-- 2. Server-side refund-amount calculation. See product-decision note
-- above: returns NULL refundable_amount when no explicit refund_percent is
-- resolvable, rather than defaulting to 0% or 100%.
create or replace function public.calculate_refund_amount(
  p_booking_id uuid
)
returns table (
  captured_payment_id uuid,
  captured_amount numeric,
  refund_percent numeric,
  refundable_amount numeric,
  policy_source text
)
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_booking record;
  v_payment record;
  v_policy jsonb;
  v_source text;
  v_percent numeric;
begin
  select b.* into v_booking from public.bookings b where b.id = p_booking_id;
  if not found then
    return;
  end if;

  select p.* into v_payment
  from public.payments p
  where p.booking_id = p_booking_id and p.status = 'captured'
  order by p.created_at desc
  limit 1;

  if v_booking.cancellation_policy is not null then
    v_policy := v_booking.cancellation_policy;
    v_source := 'booking';
  else
    select v.cancellation_policy into v_policy
    from public.venues v
    where v.id = v_booking.venue_id;
    v_source := 'venue';
  end if;

  v_percent := null;
  if v_policy is not null and (v_policy ->> 'refund_percent') is not null then
    begin
      v_percent := (v_policy ->> 'refund_percent')::numeric;
    exception when others then
      v_percent := null;
    end;
    if v_percent is not null and (v_percent < 0 or v_percent > 100) then
      v_percent := null;
    end if;
  end if;

  captured_payment_id := v_payment.id;
  captured_amount := coalesce(v_payment.amount, 0);
  policy_source := case when v_percent is null then null else v_source end;
  refund_percent := v_percent;
  refundable_amount := case
    when v_percent is null then null
    else round(coalesce(v_payment.amount, 0) * v_percent / 100.0, 2)
  end;

  return next;
end;
$$;

revoke all on function public.calculate_refund_amount(uuid) from public;
grant execute on function public.calculate_refund_amount(uuid) to authenticated, service_role;

-- 3. Customer-initiated cancellation of a CONFIRMED (paid) booking.
-- Closes Phase1 audit finding 8.5. Narrowly scoped:
--   - caller must be the booking's own user (server-side check)
--   - only status='confirmed' is accepted; any other status is an
--     idempotent no-op error (CANNOT_CANCEL), matching cancel_venue_booking
--   - the refund amount is ALWAYS computed server-side; no amount
--     parameter exists on this function at all
--   - a captured payment with no resolvable policy percent halts before
--     any mutation (CANCELLATION_POLICY_UNDEFINED) — see product-decision
--     note above
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

  if v_booking.user_id <> auth.uid() then
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

revoke all on function public.cancel_confirmed_booking(uuid, text) from public;
grant execute on function public.cancel_confirmed_booking(uuid, text) to authenticated;

-- 4. Admin-initiated cancellation of a CONFIRMED (paid) booking, with an
-- explicit, mandatory-reason, audited refund amount. This is a human
-- override, not a policy calculation — the amount is still bound-checked
-- against the captured payment and can never exceed it.
create or replace function public.admin_cancel_booking(
  p_booking_id uuid,
  p_refund_amount numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_booking record;
  v_payment record;
  v_refund_id uuid;
begin
  if p_reason is null or length(trim(p_reason)) = 0 then
    return jsonb_build_object('success', false, 'error_code', 'REASON_REQUIRED');
  end if;

  if not (
    public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  ) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_AUTHORIZED');
  end if;

  select b.* into v_booking
  from public.bookings b
  where b.id = p_booking_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;

  if v_booking.status <> 'confirmed' then
    return jsonb_build_object(
      'success', false, 'error_code', 'CANNOT_CANCEL',
      'current_status', v_booking.status
    );
  end if;

  select p.* into v_payment
  from public.payments p
  where p.booking_id = p_booking_id and p.status = 'captured'
  order by p.created_at desc
  limit 1;

  if p_refund_amount is not null then
    if p_refund_amount < 0 then
      return jsonb_build_object('success', false, 'error_code', 'INVALID_AMOUNT');
    end if;
    if v_payment.id is null and p_refund_amount > 0 then
      return jsonb_build_object('success', false, 'error_code', 'NO_CAPTURED_PAYMENT');
    end if;
    if v_payment.id is not null and p_refund_amount > v_payment.amount + 0.01 then
      return jsonb_build_object('success', false, 'error_code', 'AMOUNT_EXCEEDS_CAPTURED');
    end if;
  end if;

  update public.bookings
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  where id = p_booking_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking_cancelled', 'booking', p_booking_id,
    jsonb_build_object(
      'venue_id', v_booking.venue_id,
      'from_status', v_booking.status,
      'to_status', 'cancelled',
      'actor_role', 'admin',
      'reason', p_reason,
      'captured_payment_id', v_payment.id,
      'override_amount', p_refund_amount
    )
  );

  if v_payment.id is not null and coalesce(p_refund_amount, 0) > 0 then
    begin
      insert into public.refunds (payment_id, booking_id, amount, reason, status)
      values (v_payment.id, p_booking_id, p_refund_amount, p_reason, 'requested')
      returning id into v_refund_id;
    exception when unique_violation then
      select id into v_refund_id from public.refunds
      where payment_id = v_payment.id and status <> 'failed'
      order by created_at desc limit 1;
    end;
  end if;

  return jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'cancelled',
    'refund_id', v_refund_id,
    'refund_amount', p_refund_amount
  );
end;
$$;

revoke all on function public.admin_cancel_booking(uuid, numeric, text) from public;
grant execute on function public.admin_cancel_booking(uuid, numeric, text) to authenticated;

-- 5. Refund-processing status advance. Called only by the create-refund
-- Edge Function and the webhook/reconciler paths (service_role) — never by
-- a client. Moves refunds.status forward and, only once the provider
-- outcome is confirmed ('processed'), updates payments.status. This is the
-- ONLY place payments.status is allowed to move to a refunded value.
create or replace function public.apply_refund_result(
  p_refund_id uuid,
  p_provider_refund_id text,
  p_status text,
  p_failure_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_refund record;
  v_payment record;
begin
  if p_status not in ('processed', 'failed') then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS');
  end if;

  select * into v_refund from public.refunds where id = p_refund_id for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'REFUND_NOT_FOUND');
  end if;

  -- Idempotent: repeat delivery of the same outcome, or a late 'failed'
  -- notification arriving after 'processed' already landed, is a no-op.
  if v_refund.status = p_status or v_refund.status = 'processed' then
    return jsonb_build_object('success', true, 'idempotent', true, 'refund_id', p_refund_id, 'status', v_refund.status);
  end if;

  update public.refunds
  set status = p_status,
      provider_refund_id = coalesce(p_provider_refund_id, provider_refund_id),
      processed_at = case when p_status = 'processed' then now() else processed_at end,
      reason = case when p_status = 'failed' and p_failure_reason is not null
                     then coalesce(reason, '') || ' [failed: ' || p_failure_reason || ']'
                     else reason end,
      updated_at = now()
  where id = p_refund_id;

  if p_status = 'processed' then
    select * into v_payment from public.payments where id = v_refund.payment_id for update;
    if found then
      update public.payments
      set status = case
            when v_refund.amount >= v_payment.amount then 'refunded'::public.payment_status
            else 'partially_refunded'::public.payment_status
          end,
          updated_at = now()
      where id = v_payment.id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'refund_id', p_refund_id, 'status', p_status);
end;
$$;

revoke all on function public.apply_refund_result(uuid, text, text, text) from public;
grant execute on function public.apply_refund_result(uuid, text, text, text) to service_role;

-- 6. Reconciliation selector: refunds stuck in 'requested' past a
-- threshold, for the scheduled reconciler Edge Function to sweep.
-- Read-only. Granted only to service_role (unlike the existing, overly
-- broad reconcile_stale_payments grant flagged in the audit — intentionally
-- not repeated here).
create or replace function public.list_stale_refund_requests(
  p_older_than_minutes integer default 10,
  p_limit integer default 50
)
returns table (
  refund_id uuid,
  payment_id uuid,
  booking_id uuid,
  amount numeric,
  created_at timestamptz
)
language sql
security definer
set search_path to 'public', 'pg_temp'
stable
as $$
  select r.id, r.payment_id, r.booking_id, r.amount, r.created_at
  from public.refunds r
  where r.status = 'requested'
    and r.created_at < now() - (p_older_than_minutes || ' minutes')::interval
  order by r.created_at asc
  limit p_limit;
$$;

revoke all on function public.list_stale_refund_requests(integer, integer) from public;
grant execute on function public.list_stale_refund_requests(integer, integer) to service_role;
