-- Secure live category management for the deployed metadata-backed schema.
-- Category writes are restricted to venue owners and administrators.

alter table public.venue_categories enable row level security;

drop policy if exists "categories_owner_admin_insert" on public.venue_categories;
create policy "categories_owner_admin_insert" on public.venue_categories
  for insert with check (
    public.has_role(auth.uid(), 'venue_owner'::public.user_role)
    or public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  );

drop policy if exists "categories_owner_admin_update" on public.venue_categories;
create policy "categories_owner_admin_update" on public.venue_categories
  for update using (
    public.has_role(auth.uid(), 'venue_owner'::public.user_role)
    or public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  ) with check (
    public.has_role(auth.uid(), 'venue_owner'::public.user_role)
    or public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
  );

grant select on public.venue_categories to anon, authenticated;
grant insert, update on public.venue_categories to authenticated;
