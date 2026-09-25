-- Allow the owner profile screen to edit only the name column. The existing
-- owner_profiles RLS policy still restricts UPDATE to user_id = auth.uid().
-- Supabase's default table grants otherwise leave authenticated with UPDATE
-- on every column, making a column-level GRANT ineffective as a restriction.
revoke update on table public.owner_profiles from public, anon, authenticated;
grant update (name) on table public.owner_profiles to authenticated;
