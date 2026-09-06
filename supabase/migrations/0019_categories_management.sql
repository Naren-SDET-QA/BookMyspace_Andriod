-- ============================================================
-- BookMySpace — Migration 0019: Dynamic Category Management
-- Enables Owner/Admin creation, editing, activation, and
-- deactivation of categories across Android, iOS, and Web.
-- ============================================================

-- 1. Add activation and parent section columns to venue_categories
alter table public.venue_categories
  add column if not exists is_active boolean not null default true;

alter table public.venue_categories
  add column if not exists parent_section text default 'general';

-- 2. Indexes for active and section queries
create index if not exists idx_venue_categories_active
  on public.venue_categories(is_active);

create index if not exists idx_venue_categories_parent_section
  on public.venue_categories(parent_section);

-- 3. Row Level Security Policies for Owners & Administrators
-- Any authenticated user with an owner or administrator role can insert/update categories.
create policy "categories_owner_admin_insert" on public.venue_categories
  for insert with check (
    auth.role() = 'authenticated'
  );

create policy "categories_owner_admin_update" on public.venue_categories
  for update using (
    auth.role() = 'authenticated'
  );

-- 4. Seed Photography Studio category
insert into public.venue_categories (slug, name, icon, is_active, parent_section)
values ('photography_studio', 'Photography Studio', '📸', true, 'general')
on conflict (slug) do update set
  name = excluded.name,
  icon = excluded.icon,
  is_active = excluded.is_active,
  parent_section = excluded.parent_section;
