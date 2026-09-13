-- Finalize the approval-only booking boundary for deployments that already
-- had the compatibility columns/functions from an earlier migration.
-- New direct booking rows must default to an approval-required state even
-- though customer inserts are blocked by RLS.
alter table public.bookings
  alter column approval_required set default true;

-- Confirmation is a webhook/service operation, never a client RPC.
revoke all on function public.confirm_venue_booking(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.confirm_venue_booking(uuid, uuid, text, text)
  to service_role;

-- Expiry is owned by the scheduler/service role. The request/approval
-- functions invoke the helper internally under their security-definer owner.
revoke all on function public.expire_stale_holds() from public, anon, authenticated;
grant execute on function public.expire_stale_holds() to service_role;

-- Keep the legacy confirmation helper unavailable to app clients.
revoke all on function public.confirm_booking(uuid, text)
  from public, anon, authenticated;
grant execute on function public.confirm_booking(uuid, text) to service_role;
