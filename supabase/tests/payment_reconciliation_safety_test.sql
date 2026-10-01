-- Phase 9XG focused tests for the 9XE/9XG payment reconciliation safety
-- change. Same style as anon_execute_lockdown_test.sql: read-only where
-- possible, uses a throwaway transaction-scoped fixture row where a real
-- write must be exercised, and always rolls back via the do-block
-- exception path rather than leaving fixture data behind.
--
-- Run against a deployed database after
-- 20260916030000_payment_reconciliation_safety.sql has been applied.

-- Test 1: reconcile_stale_payments() never changes payment status,
-- regardless of how stale the row is.
do $$
declare
  v_booking_id uuid;
  v_payment_id uuid;
  v_status_before public.payment_status;
  v_status_after public.payment_status;
begin
  -- Minimal fixture: reuse an existing booking if one exists, else skip
  -- (this test asserts a behavioral property of the function, not
  -- specific data, so it degrades gracefully rather than fabricating a
  -- full booking/venue/user chain).
  select id into v_booking_id from public.bookings limit 1;
  if v_booking_id is null then
    raise notice 'SKIP: no booking rows available to attach a fixture payment to';
    return;
  end if;

  insert into public.payments (booking_id, provider, provider_order_id, amount, currency, status, created_at)
  values (v_booking_id, 'razorpay', 'order_test_9xg_stale_' || gen_random_uuid()::text, 100.00, 'INR', 'pending', now() - interval '2 hours')
  returning id, status into v_payment_id, v_status_before;

  perform public.reconcile_stale_payments(30);

  select status into v_status_after from public.payments where id = v_payment_id;

  delete from public.payments where id = v_payment_id; -- cleanup regardless of outcome

  if v_status_after <> v_status_before then
    raise exception 'FAIL: reconcile_stale_payments changed status from % to % -- it must NEVER mutate status', v_status_before, v_status_after;
  end if;
  raise notice 'PASS: reconcile_stale_payments left status unchanged (%)', v_status_after;
end $$;

-- Test 2: provider_orphan_orders denies anon and authenticated at the
-- grant level (independent of RLS), per 9XF MUST-FIX #2.
do $$
begin
  if has_table_privilege('anon', 'public.provider_orphan_orders', 'SELECT') then
    raise exception 'FAIL: anon can still SELECT provider_orphan_orders';
  end if;
  raise notice 'PASS: anon cannot SELECT provider_orphan_orders';

  if has_table_privilege('anon', 'public.provider_orphan_orders', 'INSERT') then
    raise exception 'FAIL: anon can still INSERT into provider_orphan_orders';
  end if;
  raise notice 'PASS: anon cannot INSERT into provider_orphan_orders';

  if has_table_privilege('authenticated', 'public.provider_orphan_orders', 'SELECT') then
    raise exception 'FAIL: authenticated can still SELECT provider_orphan_orders';
  end if;
  raise notice 'PASS: authenticated cannot SELECT provider_orphan_orders';

  if has_table_privilege('authenticated', 'public.provider_orphan_orders', 'INSERT') then
    raise exception 'FAIL: authenticated can still INSERT into provider_orphan_orders';
  end if;
  raise notice 'PASS: authenticated cannot INSERT into provider_orphan_orders';

  if not has_table_privilege('service_role', 'public.provider_orphan_orders', 'SELECT') then
    raise exception 'FAIL: service_role lost SELECT on provider_orphan_orders -- reconciliation would break';
  end if;
  raise notice 'PASS: service_role retains SELECT on provider_orphan_orders';
end $$;

-- Test 3: RLS is enabled with zero permissive policies on
-- provider_orphan_orders (the second, independent layer alongside the
-- grant revocation in Test 2).
do $$
declare
  v_rls_enabled boolean;
  v_policy_count integer;
begin
  select relrowsecurity into v_rls_enabled
  from pg_class where relname = 'provider_orphan_orders' and relnamespace = 'public'::regnamespace;

  if not v_rls_enabled then
    raise exception 'FAIL: RLS is not enabled on provider_orphan_orders';
  end if;
  raise notice 'PASS: RLS is enabled on provider_orphan_orders';

  select count(*) into v_policy_count from pg_policies
  where schemaname = 'public' and tablename = 'provider_orphan_orders';

  if v_policy_count <> 0 then
    raise exception 'FAIL: provider_orphan_orders has % permissive/restrictive policies -- expected 0 (fail-closed by default)', v_policy_count;
  end if;
  raise notice 'PASS: provider_orphan_orders has zero policies (fail-closed)';
end $$;

-- Test 4: reconcile_stale_payments() has search_path pinned (closes the
-- pre-existing function_search_path_mutable advisory finding).
do $$
declare
  v_config text[];
begin
  select proconfig into v_config
  from pg_proc where proname = 'reconcile_stale_payments'
    and pronamespace = 'public'::regnamespace;

  if v_config is null or not (v_config @> array['search_path=public, pg_temp']) then
    raise exception 'FAIL: reconcile_stale_payments search_path is not pinned as expected (got %)', v_config;
  end if;
  raise notice 'PASS: reconcile_stale_payments search_path is pinned';
end $$;
