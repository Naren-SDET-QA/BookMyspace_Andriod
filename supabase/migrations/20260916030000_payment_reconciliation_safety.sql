-- Phase 9XE/9XG: Pre-implementation safety scaffolding for provider-verified
-- payment/refund reconciliation. This migration is SCHEMA/FUNCTION ONLY:
-- it adds tracking columns/tables and narrows an existing unsafe function.
-- It does not schedule any cron job, does not call Razorpay, and does not
-- change the status of any existing payment/refund/booking row.

-- 1. Track when a payment row was last checked against Razorpay, so a
--    future reconciliation sweep does not re-query rows it already
--    verified recently.
alter table public.payments
  add column if not exists last_reconciled_at timestamptz;

comment on column public.payments.last_reconciled_at is
  'Timestamp of the last provider-verified reconciliation check for this row (see reconcile-payment-drift). Null means never checked.';

-- 2. Track Razorpay-side orders/payments that have no corresponding
--    Supabase payments row (the "D" / orphan-in-the-other-direction case
--    identified in Phase 9XA). Detection-only: nothing auto-creates a
--    payments/booking row from this table.
create table if not exists public.provider_orphan_orders (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'razorpay',
  provider_order_id text,
  provider_payment_id text,
  amount numeric,
  currency text,
  status text,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_note text,
  unique (provider, provider_order_id)
);

comment on table public.provider_orphan_orders is
  'Razorpay orders/payments detected with no matching public.payments row. Populated only by reconcile-payment-drift in dry-run/report mode initially. Manual review required before any remediation.';

alter table public.provider_orphan_orders enable row level security;

-- Phase 9XG fix (9XF MUST-FIX #2): this project's public schema carries a
-- standing default ACL (confirmed via pg_default_acl) that grants
-- anon/authenticated FULL table privileges (arwdDxtm) on every new table
-- created by the postgres role. RLS-with-no-policy already blocks row
-- access for those roles today, but relying on RLS alone as the only
-- layer is fragile -- if RLS were ever disabled or a permissive policy
-- added by mistake, this table would already have standing full grants
-- sitting on anon/authenticated with nothing else to catch it. Revoke
-- explicitly so this table matches the narrower pattern already used for
-- vault.secrets (no anon/authenticated grant at all), independent of RLS.
revoke all on public.provider_orphan_orders from anon, authenticated;
-- service_role and postgres/table-owner access is untouched by the above
-- REVOKE (service_role's ability to read/write this table for the
-- reconciliation functions is preserved; it was never revoked).

-- 3. Narrow reconcile_stale_payments(): it must NEVER change payment
--    status again (previously: blind `set status = 'failed'` on any
--    payment stuck 'pending', with no check against Razorpay -- flagged
--    in Phase 9XB/9XD as capable of falsely failing an order Razorpay
--    actually captured). It now only resets last_reconciled_at so the
--    row gets re-checked by the provider-verified sweep, and leaves
--    status untouched. Provider-verified status changes are the sole
--    responsibility of reconcile-payment-drift going forward.
--    Also fixes the pre-existing function_search_path_mutable advisory
--    finding while this function is already being edited.
--
-- ROLLBACK (9XF SHOULD-FIX #4): the previous, unsafe definition is
-- preserved here verbatim so this change can be reverted without relying
-- on conversation history. To roll back, run the block below (NOT
-- executed by this migration):
--
--   create or replace function public.reconcile_stale_payments(p_stale_after_minutes integer default 30)
--   returns integer
--   language plpgsql
--   as $function$
--   declare
--     v_count integer := 0;
--   begin
--     update public.payments
--     set status = 'failed', updated_at = now()
--     where status = 'pending'
--       and created_at < now() - make_interval(mins => p_stale_after_minutes);
--     get diagnostics v_count = row_count;
--     return v_count;
--   end $function$;
--
-- (Reverting this restores the unverified blind-fail behavior flagged as
-- unsafe in Phase 9XB/9XD -- do not roll back without also disabling the
-- reconcile-stale-payments cron job, or re-review why a revert is needed.)
create or replace function public.reconcile_stale_payments(p_stale_after_minutes integer default 30)
returns integer
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_count integer := 0;
begin
  -- SAFETY: this function intentionally does not mutate `payments.status`.
  -- It only flags rows that look stale so they can be picked up by a
  -- provider-verified process (reconcile-payment-drift). This preserves
  -- the original "detect stale pending payments" purpose while removing
  -- the unverified status mutation that could falsely fail a paid order.
  update public.payments
  set last_reconciled_at = null
  where status = 'pending'
    and created_at < now() - make_interval(mins => p_stale_after_minutes)
    and (last_reconciled_at is null or last_reconciled_at < created_at);
  get diagnostics v_count = row_count;
  return v_count;
end
$function$;

comment on function public.reconcile_stale_payments(integer) is
  'SAFE (Phase 9XE/9XG): no longer mutates payment status. Only marks stale-pending payments for re-check by reconcile-payment-drift, which verifies against Razorpay before any status change.';
