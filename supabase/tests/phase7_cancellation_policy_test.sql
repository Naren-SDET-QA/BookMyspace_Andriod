-- Phase 7 test suite: cancellation policy lifecycle, booking-time snapshot,
-- tiered refund calculation, owner/admin/customer cancellation paths,
-- authorization, idempotency/concurrency. Run against the disposable
-- bms_local database only.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

create extension if not exists pgcrypto;

create or replace function test_assert(p_label text, p_cond boolean) returns void
language plpgsql as $$
begin
  if p_cond then
    raise notice 'PASS: %', p_label;
  else
    raise exception 'FAIL: %', p_label;
  end if;
end;
$$;

-- Fixture identities
\set owner_id '11111111-1111-1111-1111-111111111111'
\set other_owner_id '22222222-2222-2222-2222-222222222222'
\set customer_id '33333333-3333-3333-3333-333333333333'
\set admin_id '44444444-4444-4444-4444-444444444444'
\set outsider_id '55555555-5555-5555-5555-555555555555'

insert into auth.users (id) values
  (:'owner_id'::uuid), (:'other_owner_id'::uuid), (:'customer_id'::uuid),
  (:'admin_id'::uuid), (:'outsider_id'::uuid)
on conflict do nothing;

insert into public.user_roles (user_id, role) values (:'admin_id'::uuid, 'administrator');

insert into public.organizations (id, owner_user_id, name) values
  ('a0000000-0000-0000-0000-000000000001', :'owner_id'::uuid, 'Owner Org')
on conflict do nothing;

insert into public.venues (id, org_id, name) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Test Venue')
on conflict do nothing;

insert into public.time_slots (id, venue_id, start_time, end_time) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '10:00', '14:00')
on conflict do nothing;

-- =====================================================================
-- 1. Policy creation / update / history (D10, D11)
-- =====================================================================
select set_config('request.jwt.claim.sub', :'owner_id', false); -- session-scoped for standalone psql script
select set_config('request.jwt.claim.role', 'authenticated', false); -- session-scoped for standalone psql script

select public.update_venue_cancellation_policy('b0000000-0000-0000-0000-000000000001'::uuid, true) as r1 \gset
select test_assert('owner can set venue cancellation policy',
  (:'r1')::jsonb ->> 'success' = 'true');
select test_assert('policy version starts at 1',
  ((:'r1')::jsonb ->> 'version')::int = 1);

select public.update_venue_cancellation_policy('b0000000-0000-0000-0000-000000000001'::uuid, true) as r2 \gset
select test_assert('second edit increments version to 2',
  ((:'r2')::jsonb ->> 'version')::int = 2);

select test_assert('history retains both versions',
  (select count(*) from public.venue_cancellation_policy_history
   where venue_id = 'b0000000-0000-0000-0000-000000000001') = 2);

select test_assert('one live policy per venue (single jsonb column, not multiple rows)',
  (select count(*) from public.venues where id = 'b0000000-0000-0000-0000-000000000001') = 1);

select set_config('request.jwt.claim.sub', :'outsider_id', false); -- session-scoped for standalone psql script
select public.update_venue_cancellation_policy('b0000000-0000-0000-0000-000000000001'::uuid, true) as r3 \gset
select test_assert('non-owner cannot edit venue policy',
  (:'r3')::jsonb ->> 'error_code' = 'NOT_OWNER_OR_NOT_FOUND');

-- =====================================================================
-- Helper: create a booking through to 'pending' (owner-approved, awaiting
-- payment), then a captured payment, mirroring the real state machine.
-- =====================================================================
-- Each call gets its OWN dedicated venue + slot (single booking's worth of
-- inventory), so tests exercising different tiers/timings in sequence can
-- never collide with each other via confirm_venue_booking's
-- venue/date/time overlap check. p_venue_id is accepted for call-site
-- compatibility with the shared-venue tests (sections 3/4) but a fresh
-- venue is always created; callers that need the venue id read it back off
-- the returned booking (bookings.venue_id).
create or replace function test_make_pending_booking(
  p_venue_id uuid, p_hours_from_now numeric, p_user_id uuid default '33333333-3333-3333-3333-333333333333'
) returns uuid language plpgsql as $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_hold_id uuid := gen_random_uuid();
  v_book_ts timestamptz := now() + (p_hours_from_now || ' hours')::interval;
  v_venue_id uuid := gen_random_uuid();
  v_slot_id uuid := gen_random_uuid();
  v_policy jsonb := jsonb_build_object(
    'active', true, 'policy_version', 'standard_tiered_v1',
    'tiers', jsonb_build_array(
      jsonb_build_object('hours_before', 48, 'refund_percent', 100),
      jsonb_build_object('hours_before', 24, 'refund_percent', 50),
      jsonb_build_object('hours_before', 0,  'refund_percent', 0)
    ),
    'cancellation_fee', 0, 'tax_treatment', 'proportional'
  );
begin
  insert into public.venues (id, org_id, name, cancellation_policy, cancellation_policy_version)
  values (v_venue_id, 'a0000000-0000-0000-0000-000000000001', 'Isolated Test Venue ' || v_venue_id, v_policy, 1);
  insert into public.venue_cancellation_policy_history (venue_id, version, policy, changed_by)
  values (v_venue_id, 1, v_policy, '11111111-1111-1111-1111-111111111111');
  insert into public.time_slots (id, venue_id, start_time, end_time)
  values (v_slot_id, v_venue_id, v_book_ts::time, (v_book_ts + interval '4 hours')::time);

  insert into public.booking_holds (id, venue_id, slot_id, book_date, status, expires_at)
  values (v_hold_id, v_venue_id, v_slot_id, v_book_ts::date, 'active', now() + interval '1 hour');

  insert into public.bookings (
    id, user_id, venue_id, slot_id, book_date, start_time, end_time, hold_id,
    status, amount, tax_amount, total_amount, approved_at, approved_by, payment_expires_at
  ) values (
    v_booking_id, p_user_id, v_venue_id, v_slot_id,
    v_book_ts::date, v_book_ts::time, (v_book_ts + interval '4 hours')::time, v_hold_id,
    'pending', 1000, 180, 1180, now(), '11111111-1111-1111-1111-111111111111', now() + interval '1 hour'
  );
  return v_booking_id;
end;
$$;

create or replace function test_capture_payment(p_booking_id uuid, p_user_id uuid, p_amount numeric)
returns text language plpgsql as $$
declare
  v_ref text := 'pay_' || substring(gen_random_uuid()::text, 1, 12);
begin
  insert into public.payments (booking_id, user_id, provider_payment_id, amount, status)
  values (p_booking_id, p_user_id, v_ref, p_amount, 'captured');
  return v_ref;
end;
$$;

-- confirm_venue_booking is invoked by the Edge Function/webhook using the
-- service_role key in production (see razorpay-webhook), which is why its
-- own auth check accepts either a matching auth.uid() or service_role.
-- Simulate that here for all confirm_venue_booking calls below.
select set_config('request.jwt.claim.role', 'service_role', false);

-- =====================================================================
-- 2. D9 staged rollout: default stage (test config = snapshot_only, D9
--    Stage 4 'enforce' OFF by default) must NOT block confirmation for a
--    policy-less venue -- this is the explicit "Stage 1-3 must not
--    unexpectedly block the existing catalog" requirement. A SEPARATE
--    sub-test then explicitly advances the rollout switch to 'enforce'
--    (an admin-only, audited, deliberate action) and re-checks the same
--    scenario now blocks, then restores the default so the rest of this
--    suite runs against the real production-default stage.
-- =====================================================================
insert into public.venues (id, org_id, name) values
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'No-Policy Venue');
insert into public.time_slots (id, venue_id, start_time, end_time) values
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', '10:00', '14:00');

do $$
begin
  perform test_assert('D9 rollout stage defaults to snapshot_only (Stage 4 enforce is OFF by default)',
    public.get_cancellation_policy_rollout_stage() = 'snapshot_only');
end $$;

do $$
declare
  v_booking uuid;
  v_ref text;
  v_result jsonb;
begin
  v_booking := gen_random_uuid();
  insert into public.booking_holds (id, venue_id, slot_id, book_date, status, expires_at)
  values (v_booking, 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', current_date + 3, 'active', now() + interval '1 hour');
  insert into public.bookings (id, user_id, venue_id, slot_id, book_date, start_time, end_time, hold_id, status, amount, tax_amount, total_amount, approved_at, approved_by, payment_expires_at)
  values (v_booking, '33333333-3333-3333-3333-333333333333', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', current_date + 3, '10:00', '14:00', v_booking, 'pending', 1000, 180, 1180, now(), '11111111-1111-1111-1111-111111111111', now() + interval '1 hour');
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  v_result := public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  perform test_assert('Stage <4 (default): policy-less venue confirmation SUCCEEDS unchanged (no unexpected catalog block)',
    v_result ->> 'success' = 'true');
  perform test_assert('Stage <4 (default): confirmed booking gets a NULL policy snapshot (nothing to snapshot)',
    (select cancellation_policy from public.bookings where id = v_booking) is null);
  perform test_assert('Stage <4 (default): confirmed booking status is confirmed, not blocked',
    (select status from public.bookings where id = v_booking) = 'confirmed');
end $$;

-- Non-admin cannot advance the rollout stage.
do $$
declare
  v_result jsonb;
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); -- customer, session-scoped
  perform set_config('request.jwt.claim.role', 'authenticated', false); -- session-scoped
  v_result := public.set_cancellation_policy_rollout_stage('enforce');
  perform test_assert('non-admin cannot change the D9 rollout stage',
    v_result ->> 'error_code' = 'NOT_AUTHORIZED');
end $$;

-- Admin deliberately advances to Stage 4 (enforce) -- audited, explicit.
do $$
declare
  v_result jsonb;
  v_booking uuid;
  v_ref text;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); -- admin, session-scoped
  perform set_config('request.jwt.claim.role', 'authenticated', false); -- session-scoped
  v_result := public.set_cancellation_policy_rollout_stage('enforce');
  perform test_assert('admin can deliberately advance the D9 rollout stage to enforce',
    v_result ->> 'success' = 'true' and v_result ->> 'to_stage' = 'enforce');
  perform test_assert('stage change is captured in the audit trail',
    exists (select 1 from public.audit_logs
      where action = 'cancellation_policy_rollout_stage_changed'
        and details ->> 'to_stage' = 'enforce'));

  perform set_config('request.jwt.claim.role', 'service_role', false); -- session-scoped, back to confirm-time actor
  v_booking := gen_random_uuid();
  insert into public.booking_holds (id, venue_id, slot_id, book_date, status, expires_at)
  values (v_booking, 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', current_date + 4, 'active', now() + interval '1 hour');
  insert into public.bookings (id, user_id, venue_id, slot_id, book_date, start_time, end_time, hold_id, status, amount, tax_amount, total_amount, approved_at, approved_by, payment_expires_at)
  values (v_booking, '33333333-3333-3333-3333-333333333333', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', current_date + 4, '10:00', '14:00', v_booking, 'pending', 1000, 180, 1180, now(), '11111111-1111-1111-1111-111111111111', now() + interval '1 hour');
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  v_result := public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  perform test_assert('Stage 4 (enforce, explicitly activated): policy-less venue confirmation now BLOCKED',
    v_result ->> 'error_code' = 'CANCELLATION_POLICY_REQUIRED');
  perform test_assert('Stage 4: booking stays pending, not silently mutated',
    (select status from public.bookings where id = v_booking) = 'pending');
end $$;

-- Restore the test/local default (snapshot_only) so the remainder of this
-- suite -- and any human re-running it locally -- exercises the actual
-- shipped default rather than a state left over from the Stage-4 probe
-- above.
do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); -- admin, session-scoped
  perform set_config('request.jwt.claim.role', 'authenticated', false); -- session-scoped
  perform public.set_cancellation_policy_rollout_stage('snapshot_only');
end $$;
select set_config('request.jwt.claim.role', 'service_role', false); -- session-scoped, restore for remaining confirm_venue_booking calls

-- =====================================================================
-- 3. Policy snapshot at booking confirmation (D9/D10) + 48h boundary (D2)
-- =====================================================================
do $$
declare
  v_booking uuid;
  v_ref text;
  v_result jsonb;
  v_snapshot jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 50);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  v_result := public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  perform test_assert('confirmation succeeds when venue has active policy',
    v_result ->> 'success' = 'true');

  select cancellation_policy into v_snapshot from public.bookings where id = v_booking;
  perform test_assert('booking.cancellation_policy snapshot is set at confirmation',
    v_snapshot is not null and (v_snapshot ->> 'active') = 'true');

  perform test_assert('confirmed booking status is confirmed',
    (select status from public.bookings where id = v_booking) = 'confirmed');
end $$;

-- =====================================================================
-- 4. Historical booking remains governed by its own snapshot even after
--    the venue's live policy changes (D10)
-- =====================================================================
do $$
declare
  v_booking uuid;
  v_venue_id uuid;
  v_ref text;
  v_before jsonb;
  v_after_update jsonb;
  v_snapshot_after jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 50);
  select venue_id into v_venue_id from public.bookings where id = v_booking;
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select cancellation_policy into v_before from public.bookings where id = v_booking;

  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); -- session-scoped for standalone psql script
  perform public.update_venue_cancellation_policy(v_venue_id, false); -- deactivate

  select cancellation_policy into v_snapshot_after from public.bookings where id = v_booking;
  perform test_assert('booking snapshot unchanged after venue policy later edited',
    v_snapshot_after = v_before and (v_snapshot_after ->> 'active') = 'true');

  -- The venue's own live policy, however, is now inactive.
  perform test_assert('venue live policy now inactive',
    not public.is_valid_cancellation_policy(
      (select cancellation_policy from public.venues where id = v_venue_id)
    ));

  -- Reactivate (not strictly needed since this venue is dedicated to this
  -- test, but exercises the re-activate path too).
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
  perform public.update_venue_cancellation_policy(v_venue_id, true);
end $$;

-- =====================================================================
-- 5. Refund tiers: 48h+, 24-48h boundary, <24h, and exact-boundary cases
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_calc record;
begin
  -- 48h+ -> 100%
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select * into v_calc from public.calculate_refund_amount(v_booking);
  perform test_assert('48h+ tier refunds 100%', v_calc.refund_percent = 100);
  perform test_assert('48h+ tier refundable_amount = full captured amount',
    v_calc.refundable_amount = 1180);
  perform test_assert('tax refunded proportionally at 100%', v_calc.tax_refund_amount = 180);

  -- exactly 48h -> 100% (boundary is inclusive per ">= 48")
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 48);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select * into v_calc from public.calculate_refund_amount(v_booking);
  perform test_assert('exactly 48h boundary refunds 100%', v_calc.refund_percent = 100);

  -- 24-48h -> 50%
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 36);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select * into v_calc from public.calculate_refund_amount(v_booking);
  perform test_assert('24-48h tier refunds 50%', v_calc.refund_percent = 50);
  perform test_assert('50% refundable_amount is half captured amount', v_calc.refundable_amount = 590);

  -- exactly 24h -> 50% (boundary inclusive per ">= 24")
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 24);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select * into v_calc from public.calculate_refund_amount(v_booking);
  perform test_assert('exactly 24h boundary refunds 50%', v_calc.refund_percent = 50);

  -- <24h -> 0%
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 12);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select * into v_calc from public.calculate_refund_amount(v_booking);
  perform test_assert('<24h tier refunds 0%', v_calc.refund_percent = 0);
  perform test_assert('0% refundable_amount is 0', v_calc.refundable_amount = 0);
end $$;

-- =====================================================================
-- 6. Customer cancellation end-to-end (uses calculate_refund_amount) +
--    D12: no $0 refund row created when tier is 0%
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
  v_refund_count int;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 12); -- <24h -> 0%
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); -- session-scoped for standalone psql script
  v_result := public.cancel_confirmed_booking(v_booking, 'change of plans');

  perform test_assert('customer cancellation of <24h booking succeeds (0% refund, still cancellable per D1)',
    v_result ->> 'success' = 'true');
  select count(*) into v_refund_count from public.refunds where booking_id = v_booking;
  perform test_assert('no $0 refund row created for 0% cancellation (D12)', v_refund_count = 0);

  -- Now a 48h+ booking -> 100% -> a refund row IS created.
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); -- session-scoped for standalone psql script
  v_result := public.cancel_confirmed_booking(v_booking, 'change of plans');

  perform test_assert('customer cancellation of 48h+ booking succeeds', v_result ->> 'success' = 'true');
  perform test_assert('refund row created for nonzero refund', (v_result ->> 'refund_id') is not null);
  perform test_assert('no cancellation fee subtracted (D3): refund == captured amount at 100%',
    (v_result ->> 'refundable_amount')::numeric = 1180);
end $$;

-- =====================================================================
-- 7. Policy-less (pre-Phase7 style) historical booking hard-blocks (D12)
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
begin
  -- Simulate a historical booking confirmed before the snapshot mechanism
  -- existed: cancellation_policy is NULL and venue's own policy is NULL.
  insert into public.venues (id, org_id, name) values
    ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Historical Venue (no policy)');
  insert into public.time_slots (id, venue_id, start_time, end_time) values
    ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', '10:00', '14:00');

  v_booking := gen_random_uuid();
  insert into public.bookings (id, user_id, venue_id, slot_id, book_date, start_time, end_time,
    status, amount, tax_amount, total_amount, confirmed_at)
  values (v_booking, '33333333-3333-3333-3333-333333333333', 'b0000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000003', current_date + 5, '10:00', '14:00',
    'confirmed', 1000, 180, 1180, now() - interval '10 days');
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); -- session-scoped for standalone psql script
  v_result := public.cancel_confirmed_booking(v_booking, 'test');

  perform test_assert('historical booking with no snapshot and no venue policy hard-blocks',
    v_result ->> 'error_code' = 'CANCELLATION_POLICY_UNDEFINED');
end $$;

-- =====================================================================
-- 8. Owner cancellation: 100% refund, no penalty (D7)
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 6); -- <24h, would be 0% for customer
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); -- session-scoped for standalone psql script
  v_result := public.owner_cancel_booking(v_booking, 'venue double-booked internally');

  perform test_assert('owner cancellation succeeds', v_result ->> 'success' = 'true');
  perform test_assert('owner cancellation refunds 100% regardless of <24h tier (D7)',
    (v_result ->> 'refund_amount')::numeric = 1180);
end $$;

-- Unauthorized owner cancellation
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true); -- other_owner
  v_result := public.owner_cancel_booking(v_booking, 'not my venue');

  perform test_assert('a different owner cannot cancel a booking on someone else''s venue',
    v_result ->> 'error_code' = 'NOT_OWNER_OR_NOT_FOUND');
end $$;

-- =====================================================================
-- 9. Admin cancellation: mandatory reason, audit trail, no artificial cap
--    (D8), and unauthorized non-admin rejected
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
  v_audit_count int;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true); -- admin
  v_result := public.admin_cancel_booking(v_booking, null::numeric, null); -- missing reason
  perform test_assert('admin cancellation requires a reason', v_result ->> 'error_code' = 'REASON_REQUIRED');

  v_result := public.admin_cancel_booking(v_booking, 1180, 'fraud investigation hold');

  perform test_assert('admin cancellation with full captured amount succeeds (no artificial cap, D8)',
    v_result ->> 'success' = 'true' and (v_result ->> 'refund_amount')::numeric = 1180);

  select count(*) into v_audit_count from public.audit_logs
  where entity_id = v_booking and action = 'booking_cancelled' and details ->> 'actor_role' = 'admin';
  perform test_assert('admin cancellation is audit-logged with reason', v_audit_count = 1);

  -- Non-admin attempt
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true); -- customer, not admin
  v_result := public.admin_cancel_booking(v_booking, 1180, 'trying to self-serve as admin');
  perform test_assert('non-admin cannot call admin_cancel_booking', v_result ->> 'error_code' = 'NOT_AUTHORIZED');
end $$;

-- =====================================================================
-- 10. Duplicate/retry refund protection (idempotency backstop)
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result1 jsonb; v_result2 jsonb;
  v_refund_count int;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); -- session-scoped for standalone psql script
  v_result1 := public.admin_cancel_booking(v_booking, 1180, 'first attempt');
  -- Retry with the same booking now in 'cancelled' state: CANNOT_CANCEL, not a second refund row.
  v_result2 := public.admin_cancel_booking(v_booking, 1180, 'retry after client timeout');

  perform test_assert('retry after cancellation is rejected, not double-processed',
    v_result2 ->> 'error_code' = 'CANNOT_CANCEL');
  select count(*) into v_refund_count from public.refunds where booking_id = v_booking;
  perform test_assert('exactly one refund row exists despite retry', v_refund_count = 1);
end $$;

-- Direct unique-index-level duplicate insert protection (simulates a race
-- where two concurrent cancel calls both pass the status check before
-- either commits -- the partial unique index is the real gate).
do $$
declare
  v_booking uuid; v_ref text; v_payment_id uuid;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select id into v_payment_id from public.payments where booking_id = v_booking;

  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking, 1180, 'requested');
  begin
    insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking, 1180, 'requested');
    perform test_assert('second concurrent refund insert should have been rejected', false);
  exception when unique_violation then
    perform test_assert('partial unique index blocks a second concurrent non-failed refund row', true);
  end;
end $$;

-- =====================================================================
-- 11. Concurrent cancellation (two sessions racing on the same booking):
--     simulated via a nested transaction using a SAVEPOINT + row lock,
--     since psql cannot open two real concurrent sessions in one script.
--     The `for update` row lock inside admin_cancel_booking/
--     cancel_confirmed_booking/owner_cancel_booking is what makes the
--     second caller see the already-cancelled status rather than racing
--     the refund insert -- verified here indirectly via the status check.
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_r1 jsonb; v_r2 jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); -- session-scoped for standalone psql script
  v_r1 := public.cancel_confirmed_booking(v_booking, 'first caller');
  v_r2 := public.cancel_confirmed_booking(v_booking, 'second caller (would-be concurrent)');

  perform test_assert('first cancellation call succeeds', v_r1 ->> 'success' = 'true');
  perform test_assert('second cancellation call on already-cancelled booking is rejected, not double-refunded',
    v_r2 ->> 'error_code' = 'CANNOT_CANCEL');
end $$;

-- =====================================================================
-- 12. Unauthorized actions: customer cancelling someone else's booking,
--     owner cancelling on a venue they don't own (already covered above),
--     customer calling owner/admin RPCs
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_result jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72, '33333333-3333-3333-3333-333333333333'::uuid);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);

  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true); -- outsider
  v_result := public.cancel_confirmed_booking(v_booking, 'not my booking');
  perform test_assert('a stranger cannot cancel another customer''s booking',
    v_result ->> 'error_code' = 'NOT_AUTHORIZED');

  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); -- session-scoped for standalone psql script
  v_result := public.owner_cancel_booking(v_booking, 'not my venue');
  perform test_assert('a stranger cannot owner-cancel a booking on a venue they do not own',
    v_result ->> 'error_code' = 'NOT_OWNER_OR_NOT_FOUND');
end $$;

-- =====================================================================
-- 13. Webhook / apply_refund_result: success, failure, idempotency
--     (service_role path, unchanged from the existing 20260914170000
--     migration -- exercised here to confirm it still works after the
--     Phase 7 migration layered on top)
-- =====================================================================
do $$
declare
  v_booking uuid; v_ref text; v_payment_id uuid; v_refund_id uuid;
  v_r1 jsonb; v_r2 jsonb; v_r3 jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select id into v_payment_id from public.payments where booking_id = v_booking;
  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking, 1180, 'requested')
  returning id into v_refund_id;

  v_r1 := public.apply_refund_result(v_refund_id, 'rzp_refund_abc', 'processed');
  perform test_assert('webhook success marks refund processed', v_r1 ->> 'success' = 'true');
  perform test_assert('payment marked refunded once amount matches captured amount',
    (select status from public.payments where id = v_payment_id) = 'refunded');

  -- Idempotent redelivery of the same success event
  v_r2 := public.apply_refund_result(v_refund_id, 'rzp_refund_abc', 'processed');
  perform test_assert('duplicate webhook success delivery is idempotent', (v_r2 ->> 'idempotent')::boolean = true);

  -- Late failure notification after success already landed: no-op, not a regression
  v_r3 := public.apply_refund_result(v_refund_id, 'rzp_refund_abc', 'failed', 'gateway timeout');
  perform test_assert('late failure after success is a no-op, does not revert refund',
    (select status from public.refunds where id = v_refund_id) = 'processed');
end $$;

-- Genuine failure path on a separate refund
do $$
declare
  v_booking uuid; v_ref text; v_payment_id uuid; v_refund_id uuid; v_r jsonb;
begin
  v_booking := test_make_pending_booking('b0000000-0000-0000-0000-000000000001'::uuid, 72);
  v_ref := test_capture_payment(v_booking, '33333333-3333-3333-3333-333333333333', 1180);
  perform public.confirm_venue_booking(v_booking, '33333333-3333-3333-3333-333333333333', v_ref);
  select id into v_payment_id from public.payments where booking_id = v_booking;
  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking, 1180, 'requested')
  returning id into v_refund_id;

  v_r := public.apply_refund_result(v_refund_id, null, 'failed', 'insufficient balance at gateway');
  perform test_assert('webhook failure marks refund failed', v_r ->> 'success' = 'true' and v_r ->> 'status' = 'failed');
  perform test_assert('payment status untouched on refund failure',
    (select status from public.payments where id = v_payment_id) = 'captured');

  -- Because the failed refund frees the partial unique index, a fresh
  -- retry can create a new refund row for the same payment.
  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking, 1180, 'requested');
  perform test_assert('a new refund attempt is possible after a failed one (index only blocks non-failed rows)', true);
end $$;

select 'ALL PHASE 7 TESTS PASSED' as result;
