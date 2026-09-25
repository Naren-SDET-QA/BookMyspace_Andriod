-- Phase 7: Cancellation policy lifecycle (venue-editable live policy +
-- versioned history, booking-time snapshot enforcement, tiered refund
-- calculation, owner cancellation). Built on top of
-- 20260914170000_refund_cancellation_domain.sql per POLICY_DECISION_LOCK.md
-- (D1-D12, owner-approved 2026-09-14).
--
-- Scope: strictly additive to the cancellation/refund domain.
--   - does NOT modify bookings_no_overlap or any exclusion-constraint logic
--   - does NOT add capacity/units/slot-parallel-booking concepts
--   - does NOT touch venue_sections, category management, Function Halls,
--     or the 3D Glass Matrix UI
--   - does NOT change admin_cancel_booking (D8 is already correctly
--     implemented: mandatory reason, audit trail, capped only at the
--     captured payment amount)
--   - does NOT change cancel_confirmed_booking's control flow (it already
--     defers entirely to calculate_refund_amount() and already hard-blocks
--     with CANCELLATION_POLICY_UNDEFINED when no percent is resolvable --
--     this is exactly D1/D12's "historical booking retains safe hard-block"
--     behavior, so it needs no edits, only a smarter calculate_refund_amount)
--
-- ASSUMPTION FLAGGED FOR VERIFICATION BEFORE PRODUCTION (see
-- POLICY_DECISION_LOCK.md "verified schema/payment assumptions"):
-- book_date/start_time are treated as UTC wall-clock for the 48h/24h
-- threshold math below. If venue local time is ever not UTC-equivalent in
-- storage, this threshold math must be revisited before go-live.

-- ---------------------------------------------------------------------
-- 1. Versioning support on the live policy column (already exists).
-- ---------------------------------------------------------------------
alter table public.venues
  add column if not exists cancellation_policy_version integer not null default 0;

comment on column public.venues.cancellation_policy_version is
  'Monotonically incremented each time cancellation_policy is changed via '
  'update_venue_cancellation_policy(). Snapshotted into bookings.metadata '
  'at confirmation time for precedence/audit purposes (D10, D12).';

-- ---------------------------------------------------------------------
-- 2. Versioned policy history (D10, D11).
-- ---------------------------------------------------------------------
create table if not exists public.venue_cancellation_policy_history (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  version integer not null,
  policy jsonb,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now(),
  constraint venue_cancellation_policy_history_unique_version
    unique (venue_id, version)
);

comment on table public.venue_cancellation_policy_history is
  'Append-only version history of venues.cancellation_policy. One row per '
  'change, written by update_venue_cancellation_policy() before the live '
  'column is updated. A booking''s own bookings.cancellation_policy '
  'snapshot (taken at confirmation) is what governs that booking forever '
  'after -- this table is audit/history only, never read by refund '
  'calculation (D10).';

create index if not exists venue_cancellation_policy_history_venue_idx
  on public.venue_cancellation_policy_history (venue_id, version desc);

alter table public.venue_cancellation_policy_history enable row level security;

drop policy if exists venue_cancellation_policy_history_owner_read
  on public.venue_cancellation_policy_history;
create policy venue_cancellation_policy_history_owner_read
  on public.venue_cancellation_policy_history
  for select
  using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_cancellation_policy_history.venue_id
        and o.owner_user_id = auth.uid()
        and o.deleted_at is null
    )
    or public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  );

-- No insert/update/delete policies are granted to authenticated: all writes
-- go through update_venue_cancellation_policy() (security definer) so the
-- version sequence and live-column write happen atomically together.
revoke all on public.venue_cancellation_policy_history from authenticated, anon;
grant select on public.venue_cancellation_policy_history to authenticated;

-- ---------------------------------------------------------------------
-- 2b. D9 staged-rollout switch. A single-row config table controlling
--     which of the four documented stages (configure_only, snapshot_only,
--     warn, enforce) is currently active. This is the ONLY thing that
--     decides whether confirm_venue_booking's D9 gate below can ever
--     block a confirmation -- every stage before 'enforce' is byte-for-
--     byte identical to pre-Phase-7 confirmation behavior.
--
--     TEST/LOCAL DEFAULT ONLY -- NOT a permanent business decision:
--     seeded to 'snapshot_only' so this migration's own local test suite
--     can exercise the snapshot mechanism without blocking any
--     confirmation. Stage 4 ('enforce') is OFF by default, exactly as
--     required. The real production stage, and the four scheduling
--     parameters that gate advancing between stages, are still
--     REQUIRES OWNER APPROVAL items per POLICY_DECISION_LOCK.md D9 and
--     must be set explicitly before/at each production stage change --
--     this migration does not, and must not, choose them.
-- ---------------------------------------------------------------------
create table if not exists public.cancellation_policy_rollout (
  id boolean primary key default true,
  stage text not null default 'snapshot_only'
    check (stage in ('configure_only', 'snapshot_only', 'warn', 'enforce')),
  updated_at timestamptz not null default now(),
  constraint cancellation_policy_rollout_singleton check (id = true)
);

comment on table public.cancellation_policy_rollout is
  'Singleton D9 rollout-stage switch. TEST/LOCAL default = snapshot_only. '
  'Advancing to enforce is a deliberate, separately-approved production '
  'change (POLICY_DECISION_LOCK.md D9), never a default.';

insert into public.cancellation_policy_rollout (id, stage)
values (true, 'snapshot_only')
on conflict (id) do nothing;

alter table public.cancellation_policy_rollout enable row level security;
revoke all on public.cancellation_policy_rollout from authenticated, anon;
drop policy if exists cancellation_policy_rollout_admin_read on public.cancellation_policy_rollout;
create policy cancellation_policy_rollout_admin_read
  on public.cancellation_policy_rollout
  for select
  using (
    public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  );
grant select on public.cancellation_policy_rollout to authenticated;

create or replace function public.get_cancellation_policy_rollout_stage()
returns text
language sql
stable
as $$
  select coalesce(
    (select stage from public.cancellation_policy_rollout where id = true),
    'snapshot_only'
  );
$$;

revoke all on function public.get_cancellation_policy_rollout_stage() from public;
grant execute on function public.get_cancellation_policy_rollout_stage() to authenticated, service_role;

-- Admin/super-admin-only stage transition RPC, fully audited. Deliberately
-- does not accept an "are you sure" bypass -- every call is a real
-- production decision recorded in audit_logs.
create or replace function public.set_cancellation_policy_rollout_stage(
  p_stage text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_old_stage text;
begin
  if not (public.has_role(auth.uid(), 'administrator'::public.user_role)
          or public.has_role(auth.uid(), 'super_administrator'::public.user_role)) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_AUTHORIZED');
  end if;

  if p_stage not in ('configure_only', 'snapshot_only', 'warn', 'enforce') then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STAGE');
  end if;

  select stage into v_old_stage from public.cancellation_policy_rollout where id = true;

  update public.cancellation_policy_rollout
  set stage = p_stage, updated_at = now()
  where id = true;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'cancellation_policy_rollout_stage_changed', 'system_config', null,
    jsonb_build_object('from_stage', v_old_stage, 'to_stage', p_stage));

  return jsonb_build_object('success', true, 'from_stage', v_old_stage, 'to_stage', p_stage);
end;
$$;

revoke all on function public.set_cancellation_policy_rollout_stage(text) from public;
grant execute on function public.set_cancellation_policy_rollout_stage(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Policy validity check, shared by the confirm-time gate and refund
--    calculation. A policy is valid/eligible only once explicitly
--    activated by the owner with the standard tier table -- there is no
--    per-venue percentage override (D1, D2).
-- ---------------------------------------------------------------------
create or replace function public.is_valid_cancellation_policy(p_policy jsonb)
returns boolean
language sql
immutable
as $$
  select p_policy is not null
    and jsonb_typeof(p_policy) = 'object'
    and coalesce((p_policy ->> 'active')::boolean, false) = true
$$;

-- ---------------------------------------------------------------------
-- 4. Owner (or admin)-facing policy edit RPC. Always writes the approved
--    standard tier table (D2) -- the only editable surface is whether the
--    policy is active for this venue, matching D1 ("no per-venue tier
--    override"). Every change is versioned into history first (D10).
-- ---------------------------------------------------------------------
create or replace function public.update_venue_cancellation_policy(
  p_venue_id uuid,
  p_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_venue record;
  v_next_version integer;
  v_policy jsonb;
begin
  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid()
    and o.deleted_at is null
  for update of v;

  if not found then
    if public.has_role(auth.uid(), 'administrator'::public.user_role)
       or public.has_role(auth.uid(), 'super_administrator'::public.user_role) then
      select v.* into v_venue from public.venues v where v.id = p_venue_id for update;
    end if;
  end if;

  if v_venue.id is null then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  v_policy := jsonb_build_object(
    'active', coalesce(p_active, true),
    'policy_version', 'standard_tiered_v1',
    'tiers', jsonb_build_array(
      jsonb_build_object('hours_before', 48, 'refund_percent', 100),
      jsonb_build_object('hours_before', 24, 'refund_percent', 50),
      jsonb_build_object('hours_before', 0,  'refund_percent', 0)
    ),
    'cancellation_fee', 0,
    'tax_treatment', 'proportional'
  );

  v_next_version := v_venue.cancellation_policy_version + 1;

  insert into public.venue_cancellation_policy_history (venue_id, version, policy, changed_by)
  values (p_venue_id, v_next_version, v_policy, auth.uid());

  update public.venues
  set cancellation_policy = v_policy,
      cancellation_policy_version = v_next_version,
      updated_at = now()
  where id = p_venue_id;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'venue_cancellation_policy_updated', 'venue', p_venue_id,
    jsonb_build_object(
      'version', v_next_version,
      'active', coalesce(p_active, true),
      'applies_to', 'future_bookings_only'
    )
  );

  return jsonb_build_object(
    'success', true, 'venue_id', p_venue_id,
    'cancellation_policy', v_policy, 'version', v_next_version
  );
end;
$$;

revoke all on function public.update_venue_cancellation_policy(uuid, boolean) from public;
grant execute on function public.update_venue_cancellation_policy(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- 5. calculate_refund_amount: tiered calculation (D1-D6), still returning
--    NULL refundable_amount (and thus still triggering
--    CANCELLATION_POLICY_UNDEFINED downstream in cancel_confirmed_booking,
--    unchanged) whenever no valid, resolvable policy is found -- this is
--    the exact mechanism that keeps historical/pre-Phase7 bookings on the
--    existing safe hard-block path (D12).
-- ---------------------------------------------------------------------
drop function if exists public.calculate_refund_amount(uuid);

create or replace function public.calculate_refund_amount(
  p_booking_id uuid
)
returns table (
  captured_payment_id uuid,
  captured_amount numeric,
  refund_percent numeric,
  refundable_amount numeric,
  policy_source text,
  hours_before_booking numeric,
  tax_refund_amount numeric
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
  v_hours numeric;
  v_booking_start timestamptz;
  v_tier jsonb;
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

  -- Precedence: the booking's own snapshot (taken at confirmation) always
  -- wins over the venue's current (possibly since-edited) policy. Falling
  -- back to the live venue policy only covers bookings confirmed before
  -- this snapshot mechanism existed.
  if v_booking.cancellation_policy is not null then
    v_policy := v_booking.cancellation_policy;
    v_source := 'booking_snapshot';
  else
    select v.cancellation_policy into v_policy
    from public.venues v
    where v.id = v_booking.venue_id;
    v_source := 'venue_live_fallback';
  end if;

  v_percent := null;
  v_hours := null;

  v_booking_start := (v_booking.book_date + v_booking.start_time) at time zone 'UTC';
  v_hours := extract(epoch from (v_booking_start - now())) / 3600.0;

  if public.is_valid_cancellation_policy(v_policy) and v_policy ? 'tiers' then
    -- Standard tiered policy (D2): pick the highest hours_before threshold
    -- the booking still satisfies; tiers are stored highest-first.
    for v_tier in select * from jsonb_array_elements(v_policy -> 'tiers')
    loop
      if v_hours >= (v_tier ->> 'hours_before')::numeric then
        v_percent := (v_tier ->> 'refund_percent')::numeric;
        exit;
      end if;
    end loop;
    if v_percent is null then
      -- Fell through every tier (all hours_before thresholds > v_hours,
      -- i.e. booking already started/past) -- 0% per the lowest tier.
      v_percent := 0;
    end if;
  elsif v_policy is not null and (v_policy ->> 'refund_percent') is not null then
    -- Legacy/explicit flat percent, retained for backward compatibility
    -- with the prior calculate_refund_amount shape.
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
  hours_before_booking := v_hours;
  refundable_amount := case
    when v_percent is null then null
    else round(coalesce(v_payment.amount, 0) * v_percent / 100.0, 2)
  end;
  -- Tax is refunded proportionally by construction (D4): it is the same
  -- percentage of the tax component of the captured amount. No separate
  -- deduction exists (D3, D5); this is reported purely for audit/receipt
  -- transparency.
  tax_refund_amount := case
    when v_percent is null then null
    else round(coalesce(v_booking.tax_amount, 0) * v_percent / 100.0, 2)
  end;

  return next;
end;
$$;

revoke all on function public.calculate_refund_amount(uuid) from public;
grant execute on function public.calculate_refund_amount(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. confirm_venue_booking: add the D9 confirmation gate and the D9/D10
--    booking-time policy snapshot. Every other line is unchanged from the
--    currently-deployed function (preserving DB-intent -> webhook-verified
--    confirmation, idempotency, external-channel conflict handling, the
--    advisory lock, and the slot/hold checks).
-- ---------------------------------------------------------------------
create or replace function public.confirm_venue_booking(
  p_booking_id uuid,
  p_user_id uuid,
  p_payment_ref text,
  p_payment_method text default 'UPIRazorpay'::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_booking record;
  v_payment record;
  v_slot record;
  v_venue record;
  v_lock_key bigint;
  v_receipt_number text;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;

  select * into v_booking from public.bookings b
  where b.id = p_booking_id and b.user_id = p_user_id
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;

  if v_booking.status = 'confirmed' then
    select receipt_number into v_receipt_number
    from public.booking_receipts where booking_id = p_booking_id;
    return jsonb_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'CONFIRMED', 'receipt_number', v_receipt_number, 'idempotent', true);
  end if;

  if v_booking.status = 'external_conflict' then
    return jsonb_build_object('success', false, 'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel. Payment success is not booking success; refund/void required, booking placed in safe failure state.');
  end if;

  if v_booking.status <> 'pending'
     or v_booking.approved_at is null
     or v_booking.approved_by is null then
    return jsonb_build_object('success', false, 'error_code', 'OWNER_APPROVAL_REQUIRED',
      'message', 'Payment cannot confirm a booking before the venue owner approves it.');
  end if;
  if v_booking.payment_expires_at is not null and v_booking.payment_expires_at <= now() then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_WINDOW_EXPIRED');
  end if;
  if p_payment_ref is null or length(trim(p_payment_ref)) = 0 then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_REQUIRED');
  end if;

  select p.* into v_payment from public.payments p
  where p.booking_id = p_booking_id and p.status = 'captured'
    and p.provider_payment_id = p_payment_ref
  order by p.updated_at desc limit 1;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NO_CAPTURED_PAYMENT');
  end if;

  -- D9: a venue with no valid, active cancellation policy cannot have a
  -- booking confirmed. This check is deliberately placed after the
  -- captured-payment check so the payment is not silently swallowed --
  -- the caller (webhook/Edge Function) gets a clear, distinct error code
  -- and the payment stays 'captured' but unconsumed, resolvable via the
  -- existing admin/reconciliation tooling. No booking/payment row is
  -- mutated when this fails.
  select v.* into v_venue from public.venues v where v.id = v_booking.venue_id;

  -- D9 Stage 4 ('enforce') only: refuse to confirm when no valid policy
  -- exists. Stages 1-3 (configure_only/snapshot_only/warn) never reach
  -- this branch -- confirmation proceeds exactly as it did before Phase 7,
  -- and the snapshot below still runs (or stores NULL) unconditionally.
  if public.get_cancellation_policy_rollout_stage() = 'enforce'
     and (not found or not public.is_valid_cancellation_policy(v_venue.cancellation_policy)) then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (v_booking.user_id, 'booking_confirmation_blocked', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id, 'reason', 'CANCELLATION_POLICY_REQUIRED',
        'payment_ref', p_payment_ref, 'payment_id', v_payment.id));
    return jsonb_build_object('success', false, 'error_code', 'CANCELLATION_POLICY_REQUIRED',
      'message', 'This venue has no active cancellation policy. Booking cannot be confirmed until the venue owner sets one.');
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  select s.id, s.start_time, s.end_time into v_slot
  from public.time_slots s
  where s.id = v_booking.slot_id and s.venue_id = v_booking.venue_id and s.is_active = true;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = v_booking.venue_id and d.blocked_date = v_booking.book_date
  ) or exists (
    select 1 from public.bookings b
    where b.id <> v_booking.id and b.venue_id = v_booking.venue_id
      and b.book_date = v_booking.book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if v_booking.hold_id is null or not exists (
    select 1 from public.booking_holds h
    where h.id = v_booking.hold_id and h.status = 'active' and h.expires_at > now()
  ) then
    return jsonb_build_object('success', false, 'error_code', 'HOLD_EXPIRED');
  end if;

  if exists (
    select 1 from public.external_reservations er
    where er.venue_id = v_booking.venue_id
      and er.book_date = v_booking.book_date
      and er.status <> 'cancelled'
      and (er.slot_id is null or er.slot_id = v_booking.slot_id)
  ) then
    update public.bookings
    set status = 'external_conflict',
        updated_at = now(),
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
          'external_conflict_at_confirm', now(),
          'external_conflict_payment_ref', p_payment_ref
        )
    where id = v_booking.id;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (v_booking.user_id, 'booking_external_conflict', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', v_booking.status,
        'to_status', 'external_conflict', 'payment_ref', p_payment_ref, 'payment_id', v_payment.id,
        'reason', 'external_channel_reservation_detected_at_confirmation'));

    return jsonb_build_object('success', false, 'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel while payment was captured. Payment success does not mean booking success; refund/void must be issued for payment ' || p_payment_ref || '. Booking placed in safe external_conflict state.');
  end if;

  v_receipt_number := 'BMS-R-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.booking_receipts (booking_id, payment_id, receipt_number, amount, currency, metadata)
  values (v_booking.id, v_payment.id, v_receipt_number, v_booking.total_amount,
    v_booking.currency, jsonb_build_object('issued_after', 'captured_payment_and_owner_approval'))
  on conflict (booking_id) do nothing;

  update public.booking_holds set status = 'confirmed' where id = v_booking.hold_id;
  -- D9/D10: snapshot the COMPLETE venue policy, as it stands right now,
  -- onto the booking. This is what governs this booking's refund
  -- calculation forever after, independent of any later policy edit.
  update public.bookings
  set status = 'confirmed', confirmed_at = now(), updated_at = now(),
      cancellation_policy = v_venue.cancellation_policy,
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref, 'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc',
        'cancellation_policy_version', v_venue.cancellation_policy_version)
  where id = v_booking.id and status = 'pending';

  select receipt_number into v_receipt_number
  from public.booking_receipts where booking_id = v_booking.id;
  insert into public.notifications (user_id, title, body, type, data)
  values (v_booking.user_id, 'Booking confirmed',
    'Your owner-approved payment was captured and the booking is confirmed. Your receipt is ready.',
    'booking_confirmed', jsonb_build_object('booking_id', v_booking.id,
      'receipt_number', v_receipt_number));
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (v_booking.user_id, 'booking_confirmed', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'pending',
      'to_status', 'confirmed', 'actor_role', 'payment_webhook',
      'payment_id', v_payment.id, 'receipt_number', v_receipt_number,
      'cancellation_policy_version', v_venue.cancellation_policy_version));
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref, 'status', 'CONFIRMED',
    'receipt_number', v_receipt_number, 'confirmed_at', now());
end;
$$;

-- ---------------------------------------------------------------------
-- 7. Venue-owner-initiated cancellation of a CONFIRMED (paid) booking
--    (D7). Distinct from cancel_confirmed_booking: the customer did
--    nothing to trigger this, so it always refunds 100% of the captured
--    amount -- it never calls the tiered calculate_refund_amount().
-- ---------------------------------------------------------------------
create or replace function public.owner_cancel_booking(
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
  v_payment record;
  v_refund_id uuid;
begin
  select b.* into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id
    and o.owner_user_id = auth.uid()
    and o.deleted_at is null
  for update of b;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
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
      'actor_role', 'venue_owner',
      'reason', p_reason,
      'captured_payment_id', v_payment.id,
      'refund_amount', v_payment.amount,
      'refund_basis', 'owner_cancellation_full_refund_no_penalty'
    )
  );

  if v_payment.id is not null and coalesce(v_payment.amount, 0) > 0 then
    begin
      insert into public.refunds (payment_id, booking_id, amount, reason, status)
      values (v_payment.id, p_booking_id, v_payment.amount,
        coalesce(p_reason, 'Cancelled by venue owner'), 'requested')
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
    'refund_amount', v_payment.amount
  );
end;
$$;

revoke all on function public.owner_cancel_booking(uuid, text) from public;
grant execute on function public.owner_cancel_booking(uuid, text) to authenticated;
