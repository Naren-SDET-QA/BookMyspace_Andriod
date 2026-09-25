-- Read-only production security contract check, in the same style as
-- production_security_contract.sql. Run this against a deployed
-- BookMySpace database after 20260915130000_revoke_anon_execute_stale_refund_rollout.sql
-- has been applied. It never inserts, updates, or deletes application data
-- -- it only inspects function privileges via has_function_privilege().
--
-- Verifies the exact grant matrix required by that migration:
--   list_stale_refund_requests(integer, integer)      -> service_role ONLY
--   get_cancellation_policy_rollout_stage()            -> authenticated, service_role

do $$
begin
  -- anon must NOT be able to execute either function.
  if has_function_privilege('anon', 'public.list_stale_refund_requests(integer, integer)', 'EXECUTE') then
    raise exception 'FAIL: anon can still execute list_stale_refund_requests';
  end if;
  raise notice 'PASS: anon cannot execute list_stale_refund_requests';

  if has_function_privilege('anon', 'public.get_cancellation_policy_rollout_stage()', 'EXECUTE') then
    raise exception 'FAIL: anon can still execute get_cancellation_policy_rollout_stage';
  end if;
  raise notice 'PASS: anon cannot execute get_cancellation_policy_rollout_stage';

  -- authenticated must NOT be able to execute the reconciler-only selector.
  if has_function_privilege('authenticated', 'public.list_stale_refund_requests(integer, integer)', 'EXECUTE') then
    raise exception 'FAIL: authenticated can still execute list_stale_refund_requests (must be service_role-only)';
  end if;
  raise notice 'PASS: authenticated cannot execute list_stale_refund_requests';

  -- authenticated MUST retain execute on the rollout-stage reader (unchanged
  -- from its originally-intended grant).
  if not has_function_privilege('authenticated', 'public.get_cancellation_policy_rollout_stage()', 'EXECUTE') then
    raise exception 'FAIL: authenticated lost execute on get_cancellation_policy_rollout_stage';
  end if;
  raise notice 'PASS: authenticated retains execute on get_cancellation_policy_rollout_stage';

  -- service_role must retain execute on both, unconditionally.
  if not has_function_privilege('service_role', 'public.list_stale_refund_requests(integer, integer)', 'EXECUTE') then
    raise exception 'FAIL: service_role lost execute on list_stale_refund_requests';
  end if;
  raise notice 'PASS: service_role retains execute on list_stale_refund_requests';

  if not has_function_privilege('service_role', 'public.get_cancellation_policy_rollout_stage()', 'EXECUTE') then
    raise exception 'FAIL: service_role lost execute on get_cancellation_policy_rollout_stage';
  end if;
  raise notice 'PASS: service_role retains execute on get_cancellation_policy_rollout_stage';

  raise notice 'ALL ANON-EXECUTE-LOCKDOWN TESTS PASSED';
end $$;
