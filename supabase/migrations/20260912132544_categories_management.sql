-- ============================================================
-- BookMySpace — Migration 0019: Dynamic Category Management
-- Enables Owner/Admin creation, editing, activation, and
-- deactivation of categories across Android, iOS, and Web.
-- ============================================================

-- 1. Category state and parent section are stored in the existing metadata JSON.
-- This keeps the migration compatible with the deployed schema, where
-- venue_categories has id/slug/name/icon/metadata columns.
alter table public.venue_categories
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- 2. Row Level Security policies for owners and administrators.
-- Never treat authentication alone as authorization.
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

-- 3. Seed Photography Studio category without overwriting admin edits.
insert into public.venue_categories (slug, name, icon, metadata)
values (
  'photography_studio',
  'Photography Studio',
  '📸',
  '{"active": true, "parent_section": "general"}'::jsonb
)
on conflict (slug) do nothing;
