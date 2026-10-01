-- Behavioral verification scenarios for the refund/cancellation domain.
-- Runs against the local throwaway Postgres (bms_verify), NOT against
-- bookmyspace-dev. Each scenario is wrapped in its own DO block so a
-- failed assertion raises and halts the whole script (psql -v ON_ERROR_STOP=1).

\set ON_ERROR_STOP on

-- Fixtures --------------------------------------------------------------
insert into public.organizations (id, owner_user_id) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a');

insert into public.venues (id, org_id, cancellation_policy) values
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000f1', null),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-0000000000f1', '{"refund_percent": 100}'::jsonb);

insert into public.user_roles (user_id, role) values
  ('00000000-0000-0000-0000-00000000000a', 'administrator'),
  ('00000000-0000-0000-0000-00000000000b', 'customer');

-- Scenario 1: normal full refund (policy present, 100%) ------------------
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_payment_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 1000, 1000);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test1', 1000, 'captured');

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false);
  v_result := public.cancel_confirmed_booking(v_booking_id, 'change of plans');

  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL scenario1: expected success, got %', v_result;
  end if;
  if (v_result->>'refundable_amount')::numeric <> 1000 then
    raise exception 'FAIL scenario1: expected refundable_amount=1000, got %', v_result;
  end if;
  if (select status from public.bookings where id = v_booking_id) <> 'cancelled' then
    raise exception 'FAIL scenario1: booking not cancelled';
  end if;
  if (select count(*) from public.refunds where booking_id = v_booking_id and status = 'requested') <> 1 then
    raise exception 'FAIL scenario1: expected exactly one requested refund row';
  end if;
  raise notice 'PASS scenario1: normal full refund, amount computed server-side from venue policy';
end $$;

-- Scenario 2: no policy set -> CANCELLATION_POLICY_UNDEFINED, no mutation ---
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_payment_id uuid := gen_random_uuid();
  v_result jsonb;
  v_status public.booking_status;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f2', 'confirmed', 500, 500);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test2', 500, 'captured');

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false);
  v_result := public.cancel_confirmed_booking(v_booking_id, 'no policy case');

  if v_result->>'error_code' <> 'CANCELLATION_POLICY_UNDEFINED' then
    raise exception 'FAIL scenario2: expected CANCELLATION_POLICY_UNDEFINED, got %', v_result;
  end if;
  select status into v_status from public.bookings where id = v_booking_id;
  if v_status <> 'confirmed' then
    raise exception 'FAIL scenario2: booking must NOT be mutated when policy is undefined, got status=%', v_status;
  end if;
  if exists (select 1 from public.refunds where booking_id = v_booking_id) then
    raise exception 'FAIL scenario2: no refund row should have been created';
  end if;
  raise notice 'PASS scenario2: undefined policy blocks mutation instead of guessing an amount';
end $$;

-- Scenario 3: unauthorized customer cannot cancel someone else's booking --
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 100, 100);

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000c', false); -- different user
  v_result := public.cancel_confirmed_booking(v_booking_id, 'attempted takeover');

  if v_result->>'error_code' <> 'NOT_AUTHORIZED' then
    raise exception 'FAIL scenario3: expected NOT_AUTHORIZED, got %', v_result;
  end if;
  if (select status from public.bookings where id = v_booking_id) <> 'confirmed' then
    raise exception 'FAIL scenario3: booking must be unchanged';
  end if;
  raise notice 'PASS scenario3: unauthorized customer rejected server-side, no mutation';
end $$;

-- Scenario 4: unauthorized (non-admin) cannot call admin_cancel_booking ---
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 100, 100);

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false); -- a customer, not admin
  v_result := public.admin_cancel_booking(v_booking_id, 100, 'goodwill');

  if v_result->>'error_code' <> 'NOT_AUTHORIZED' then
    raise exception 'FAIL scenario4: expected NOT_AUTHORIZED, got %', v_result;
  end if;
  raise notice 'PASS scenario4: non-admin rejected by admin_cancel_booking role check';
end $$;

-- Scenario 5: admin override amount is bound-checked against captured amount
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_payment_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f2', 'confirmed', 200, 200);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test5', 200, 'captured');

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000a', false); -- administrator
  v_result := public.admin_cancel_booking(v_booking_id, 500, 'trying to overpay');

  if v_result->>'error_code' <> 'AMOUNT_EXCEEDS_CAPTURED' then
    raise exception 'FAIL scenario5: expected AMOUNT_EXCEEDS_CAPTURED, got %', v_result;
  end if;
  if (select status from public.bookings where id = v_booking_id) <> 'confirmed' then
    raise exception 'FAIL scenario5: booking must be unchanged when amount check fails';
  end if;

  v_result := public.admin_cancel_booking(v_booking_id, 150, 'partial goodwill refund');
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL scenario5b: expected success, got %', v_result;
  end if;
  if (select status from public.bookings where id = v_booking_id) <> 'cancelled' then
    raise exception 'FAIL scenario5b: booking should now be cancelled';
  end if;
  raise notice 'PASS scenario5: admin override amount bound-checked; valid partial override accepted';
end $$;

-- Scenario 6: admin_cancel_booking requires a non-empty reason ------------
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f2', 'confirmed', 100, 100);

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000a', false);
  v_result := public.admin_cancel_booking(v_booking_id, 0, '   ');

  if v_result->>'error_code' <> 'REASON_REQUIRED' then
    raise exception 'FAIL scenario6: expected REASON_REQUIRED, got %', v_result;
  end if;
  raise notice 'PASS scenario6: admin override requires a real reason';
end $$;

-- Scenario 7: duplicate cancellation is a safe no-op, not a double effect --
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_payment_id uuid := gen_random_uuid();
  v_result1 jsonb;
  v_result2 jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 700, 700);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test7', 700, 'captured');

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false);
  v_result1 := public.cancel_confirmed_booking(v_booking_id, 'first call');
  v_result2 := public.cancel_confirmed_booking(v_booking_id, 'second call, duplicate');

  if (v_result1->>'success')::boolean is not true then
    raise exception 'FAIL scenario7: first call should succeed, got %', v_result1;
  end if;
  if v_result2->>'error_code' <> 'CANNOT_CANCEL' then
    raise exception 'FAIL scenario7: second call should be rejected as CANNOT_CANCEL, got %', v_result2;
  end if;
  if (select count(*) from public.refunds where booking_id = v_booking_id) <> 1 then
    raise exception 'FAIL scenario7: exactly one refund row must exist after a duplicate cancel attempt';
  end if;
  raise notice 'PASS scenario7: duplicate cancellation rejected, no double refund row';
end $$;

-- Scenario 8: duplicate/concurrent refund race is blocked by the unique index
-- (simulates two concurrent refund-creation attempts for the same payment
-- by inserting directly, bypassing the RPC's own guard, to prove the DB-
-- level backstop holds even if application logic were ever bypassed).
do $$
declare
  v_payment_id uuid := gen_random_uuid();
  v_booking_id uuid := gen_random_uuid();
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 900, 900);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test8', 900, 'captured');

  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking_id, 900, 'requested');

  begin
    insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking_id, 900, 'requested');
    raise exception 'FAIL scenario8: second non-failed refund insert should have been rejected by the unique index';
  exception when unique_violation then
    raise notice 'PASS scenario8: refunds_payment_id_active_uq blocked a second non-failed refund for the same payment';
  end;

  -- A FAILED retry for the same payment must still be insertable (the
  -- partial index only blocks non-failed duplicates), matching the design
  -- (a failed attempt must not permanently block a legitimate retry).
  update public.refunds set status = 'failed' where payment_id = v_payment_id;
  insert into public.refunds (payment_id, booking_id, amount, status) values (v_payment_id, v_booking_id, 900, 'requested');
  if (select count(*) from public.refunds where payment_id = v_payment_id and status <> 'failed') <> 1 then
    raise exception 'FAIL scenario8b: expected exactly one active refund row after retry-following-failure';
  end if;
  raise notice 'PASS scenario8b: a fresh refund attempt is allowed after the prior one is marked failed';
end $$;

-- Scenario 9: apply_refund_result is idempotent under webhook replay ------
do $$
declare
  v_payment_id uuid := gen_random_uuid();
  v_booking_id uuid := gen_random_uuid();
  v_refund_id uuid;
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'cancelled', 1200, 1200);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test9', 1200, 'captured');
  insert into public.refunds (payment_id, booking_id, amount, status)
  values (v_payment_id, v_booking_id, 1200, 'requested') returning id into v_refund_id;

  v_result := public.apply_refund_result(v_refund_id, 'rfnd_abc', 'processed', null);
  if v_result->>'status' <> 'processed' then
    raise exception 'FAIL scenario9: expected processed, got %', v_result;
  end if;
  if (select status from public.payments where id = v_payment_id) <> 'refunded' then
    raise exception 'FAIL scenario9: payment should be refunded (full amount)';
  end if;

  -- Replay the SAME webhook event outcome again (e.g. Razorpay retries delivery).
  v_result := public.apply_refund_result(v_refund_id, 'rfnd_abc', 'processed', null);
  if (v_result->>'idempotent')::boolean is not true then
    raise exception 'FAIL scenario9b: replayed processed event should be reported idempotent, got %', v_result;
  end if;

  -- A late/out-of-order 'failed' notification must NOT downgrade an already
  -- processed refund.
  v_result := public.apply_refund_result(v_refund_id, 'rfnd_abc', 'failed', 'late_out_of_order');
  if (select status from public.refunds where id = v_refund_id) <> 'processed' then
    raise exception 'FAIL scenario9c: a late failed notification must not downgrade a processed refund';
  end if;
  raise notice 'PASS scenario9: apply_refund_result is idempotent and monotonic under webhook replay/reordering';
end $$;

-- Scenario 10: failed refund retry path (requested -> failed -> reconciler
-- sweep target) --------------------------------------------------------
do $$
declare
  v_payment_id uuid := gen_random_uuid();
  v_booking_id uuid := gen_random_uuid();
  v_refund_id uuid;
  v_result jsonb;
  v_stale_count integer;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'cancelled', 300, 300);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test10', 300, 'captured');
  insert into public.refunds (payment_id, booking_id, amount, status, created_at)
  values (v_payment_id, v_booking_id, 300, 'requested', now() - interval '20 minutes') returning id into v_refund_id;

  select count(*) into v_stale_count from public.list_stale_refund_requests(10, 50) where refund_id = v_refund_id;
  if v_stale_count <> 1 then
    raise exception 'FAIL scenario10: expected the aged requested refund to be listed as stale for the reconciler';
  end if;

  v_result := public.apply_refund_result(v_refund_id, null, 'failed', 'razorpay_400_test');
  if v_result->>'status' <> 'failed' then
    raise exception 'FAIL scenario10b: expected failed, got %', v_result;
  end if;
  if (select status from public.payments where id = v_payment_id) <> 'captured' then
    raise exception 'FAIL scenario10b: payment must remain captured (not refunded) when the refund failed';
  end if;
  if (select status from public.bookings where id = v_booking_id) <> 'cancelled' then
    raise exception 'FAIL scenario10b: booking must remain cancelled even though the refund failed (no revert)';
  end if;
  raise notice 'PASS scenario10: stale-requested refund surfaced for reconciliation; failure recorded without reverting booking/payment';
end $$;

-- Scenario 11: partial refund correctly distinguished from full refund ----
do $$
declare
  v_payment_id uuid := gen_random_uuid();
  v_booking_id uuid := gen_random_uuid();
  v_refund_id uuid;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'cancelled', 1000, 1000);
  insert into public.payments (id, booking_id, user_id, provider_payment_id, amount, status)
  values (v_payment_id, v_booking_id, '00000000-0000-0000-0000-00000000000b', 'pay_test11', 1000, 'captured');
  insert into public.refunds (payment_id, booking_id, amount, status)
  values (v_payment_id, v_booking_id, 400, 'requested') returning id into v_refund_id;

  perform public.apply_refund_result(v_refund_id, 'rfnd_partial', 'processed', null);
  if (select status from public.payments where id = v_payment_id) <> 'partially_refunded' then
    raise exception 'FAIL scenario11: 400 of 1000 should mark payment partially_refunded';
  end if;
  raise notice 'PASS scenario11: partial vs full refund correctly distinguished on payments.status';
end $$;

-- Scenario 12: cancelling a booking with zero captured payment produces no
-- refund row at all (nothing to refund) ----------------------------------
do $$
declare
  v_booking_id uuid := gen_random_uuid();
  v_result jsonb;
begin
  insert into public.bookings (id, user_id, venue_id, status, amount, total_amount)
  values (v_booking_id, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3', 'confirmed', 0, 0);

  perform set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false);
  v_result := public.cancel_confirmed_booking(v_booking_id, 'free booking, nothing paid');
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL scenario12: expected success, got %', v_result;
  end if;
  if v_result->>'refund_id' is not null then
    raise exception 'FAIL scenario12: no refund row should be created when there is no captured payment';
  end if;
  raise notice 'PASS scenario12: booking with no captured payment cancels cleanly, no phantom refund row';
end $$;

do $$ begin raise notice '=== ALL SEQUENTIAL SCENARIOS PASSED ==='; end $$;
