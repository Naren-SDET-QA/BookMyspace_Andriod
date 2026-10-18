-- The analytics closure migration recreated this SECURITY DEFINER function
-- and revoked PUBLIC but did not explicitly revoke Supabase's anon role.
-- Keep the original authenticated-only policy and make it explicit.
revoke all on function public.list_authorized_analytics_events(integer) from public, anon;
grant execute on function public.list_authorized_analytics_events(integer) to authenticated;
