-- =============================================================================
-- Fix: anon EXECUTE still granted on two functions not covered by
-- 20260915120000_fix_phase7_anon_execute_and_null_auth.sql's root-cause-#1
-- fix (the stale `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ... TO
-- anon ...` set up at project init auto-grants EXECUTE to `anon` on every
-- new function in `public`, regardless of any REVOKE ALL FROM PUBLIC the
-- function's own migration performs).
--
-- Affected functions, verified live via has_function_privilege('anon', ...)
-- during a read-only audit (see accompanying report):
--
--   1. list_stale_refund_requests(integer, integer)
--      SECURITY DEFINER, returns refund_id/payment_id/booking_id/amount for
--      every stale ('requested' > N minutes old) refund system-wide, with
--      no RLS scoping and no caller-identity parameter. Its only legitimate
--      caller is the reconcile-refunds Edge Function, which already uses
--      the service_role key. Must be service_role-only.
--
--   2. get_cancellation_policy_rollout_stage()
--      Low-sensitivity (returns only the current rollout-stage string), but
--      its defining migration (20260914180000_cancellation_policy_lifecycle.sql)
--      only ever intended `authenticated, service_role` -- anon access is an
--      unintended side effect of the same stale default-privilege grant, not
--      a decision. No client code (repo-wide grep) calls this from an anon
--      context.
--
-- default privileges in schema public were already fixed for anon by
-- 20260915120000; this migration adds no new default-privilege statement,
-- only the missing per-function REVOKE/GRANT pair for these two functions.
--
-- Scope: strictly additive privilege correction. No function body, no
-- table, no RLS policy, and no application/client code is touched.
-- =============================================================================

-- list_stale_refund_requests: internal reconciler-only selector. Never
-- callable by anon or by a plain authenticated client -- only the
-- reconcile-refunds Edge Function (service_role) may call it.
revoke all on function public.list_stale_refund_requests(integer, integer) from public, anon, authenticated;
grant execute on function public.list_stale_refund_requests(integer, integer) to service_role;

-- get_cancellation_policy_rollout_stage: restore the originally-intended
-- authenticated + service_role grant; remove the unintended anon grant.
revoke all on function public.get_cancellation_policy_rollout_stage() from public, anon;
grant execute on function public.get_cancellation_policy_rollout_stage() to authenticated, service_role;
