-- The 20260912140000 migration dropped and recreated this SECURITY DEFINER
-- function, then revoked only PUBLIC. Revoke the Supabase anon role explicitly
-- as well; authenticated/service_role are the only intended callers.
revoke all on function public.mark_ticket_resolved(uuid) from public, anon;
grant execute on function public.mark_ticket_resolved(uuid) to authenticated, service_role;
