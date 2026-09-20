-- PENDING — do not apply until approved.
-- Category listing templates, filter groups, and draft/publish overlay.
--
-- Why this is optional: the Flutter app already reads/writes
-- venue_categories.metadata.listing (jsonb). This migration promotes that
-- overlay into first-class columns + a dedicated table so Admin RLS and
-- customer read policies can enforce draft/publish without client filtering.
--
-- Rollback is at the bottom of this file.

-- ------------------------------------------------------------
-- 1. Columns on venue_categories
-- ------------------------------------------------------------
alter table public.venue_categories
  add column if not exists listing_template text not null default 'generic',
  add column if not exists listing_config jsonb not null default '{}'::jsonb,
  add column if not exists is_published boolean not null default true,
  add column if not exists cta_book text not null default 'Book & Pay',
  add column if not exists cta_availability text not null default 'Availability',
  add column if not exists accent_color text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_listing_template_chk'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_listing_template_chk
      check (listing_template in (
        'generic','hall','hotel','education','temple','sports','studio','pg'
      ));
  end if;
end $$;

-- Backfill from the metadata overlay the app already writes.
update public.venue_categories
set
  listing_template = coalesce(nullif(metadata #>> '{listing,template}', ''), listing_template),
  listing_config = coalesce(metadata -> 'listing', listing_config),
  is_published = coalesce((metadata #>> '{listing,published}')::boolean, is_published),
  cta_book = coalesce(nullif(metadata #>> '{listing,cta_book}', ''), cta_book),
  cta_availability = coalesce(nullif(metadata #>> '{listing,cta_availability}', ''), cta_availability),
  accent_color = coalesce(nullif(metadata #>> '{listing,accent_color}', ''), accent_color);

create index if not exists idx_venue_categories_published
  on public.venue_categories (is_published, is_active, display_order)
  where deleted_at is null;

-- Customers may only read enabled AND published rows. Managers still see drafts.
drop policy if exists categories_public_read on public.venue_categories;
create policy categories_public_read on public.venue_categories
  for select to anon, authenticated
  using (is_active and is_published and deleted_at is null);

-- ------------------------------------------------------------
-- 2. Filter groups / options (category-specific search filters)
-- ------------------------------------------------------------
create table if not exists public.category_filter_groups (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.venue_categories(id) on delete cascade,
  slug text not null,
  label text not null,
  filter_type text not null default 'options'
    check (filter_type in ('options','range','toggle')),
  options text[] not null default '{}',
  display_order integer not null default 0,
  is_required boolean not null default false,
  is_active boolean not null default true,
  unique (category_id, slug)
);

create index if not exists idx_category_filter_groups_category
  on public.category_filter_groups (category_id, display_order);

alter table public.category_filter_groups enable row level security;

drop policy if exists category_filter_groups_public_read on public.category_filter_groups;
create policy category_filter_groups_public_read on public.category_filter_groups
  for select to anon, authenticated
  using (
    is_active
    and exists (
      select 1 from public.venue_categories c
      where c.id = category_id
        and c.is_active
        and c.is_published
        and c.deleted_at is null
    )
  );

drop policy if exists category_filter_groups_admin_all on public.category_filter_groups;
create policy category_filter_groups_admin_all on public.category_filter_groups
  for all to authenticated
  using (public.is_category_manager())
  with check (public.is_category_manager());

grant select on public.category_filter_groups to anon, authenticated;
grant insert, update, delete on public.category_filter_groups to authenticated;

-- ------------------------------------------------------------
-- 3. Optional per-listing extra field values (booking extras stay UI-only
--    until this table is applied; do not invent occupancy or success).
-- ------------------------------------------------------------
create table if not exists public.listing_field_values (
  listing_id uuid not null,
  field_key text not null,
  value text,
  updated_at timestamptz not null default now(),
  primary key (listing_id, field_key)
);

alter table public.listing_field_values enable row level security;

drop policy if exists listing_field_values_public_read on public.listing_field_values;
create policy listing_field_values_public_read on public.listing_field_values
  for select to anon, authenticated
  using (true);

drop policy if exists listing_field_values_owner_write on public.listing_field_values;
create policy listing_field_values_owner_write on public.listing_field_values
  for all to authenticated
  using (
    public.is_category_manager()
    or exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = listing_id
        and o.owner_user_id = (select auth.uid())
    )
  )
  with check (
    public.is_category_manager()
    or exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = listing_id
        and o.owner_user_id = (select auth.uid())
    )
  );

grant select on public.listing_field_values to anon, authenticated;
grant insert, update, delete on public.listing_field_values to authenticated;

-- ------------------------------------------------------------
-- ROLLBACK
-- ------------------------------------------------------------
-- drop policy if exists listing_field_values_owner_write on public.listing_field_values;
-- drop policy if exists listing_field_values_public_read on public.listing_field_values;
-- drop table if exists public.listing_field_values;
-- drop policy if exists category_filter_groups_admin_all on public.category_filter_groups;
-- drop policy if exists category_filter_groups_public_read on public.category_filter_groups;
-- drop table if exists public.category_filter_groups;
-- drop policy if exists categories_public_read on public.venue_categories;
-- create policy categories_public_read on public.venue_categories
--   for select to anon, authenticated
--   using (is_active and deleted_at is null);
-- drop index if exists public.idx_venue_categories_published;
-- alter table public.venue_categories
--   drop constraint if exists venue_categories_listing_template_chk;
-- alter table public.venue_categories
--   drop column if exists listing_template,
--   drop column if exists listing_config,
--   drop column if exists is_published,
--   drop column if exists cta_book,
--   drop column if exists cta_availability,
--   drop column if exists accent_color;
