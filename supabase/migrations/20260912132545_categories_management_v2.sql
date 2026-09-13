-- ============================================================
-- BookMySpace - Migration 0020: Category Management v2
--
-- The category catalogue is shared by the customer apps and the admin
-- surface.  All writes are role checked in Postgres; the clients do not
-- maintain an authoritative local copy.
-- ============================================================

-- ------------------------------------------------------------
-- Category metadata
-- ------------------------------------------------------------
alter table public.venue_categories
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists is_active boolean not null default true,
  add column if not exists parent_section text default 'general',
  add column if not exists description text not null default '',
  add column if not exists image_url text,
  add column if not exists image_path text,
  add column if not exists display_order integer not null default 0,
  add column if not exists supported_languages text[] not null default array['en']::text[],
  add column if not exists name_i18n jsonb not null default '{}'::jsonb,
  add column if not exists description_i18n jsonb not null default '{}'::jsonb,
  add column if not exists deleted_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- Older deployed projects keep activation, section, and localized names in
-- metadata. Promote those values before the new catalogue columns are used.
update public.venue_categories
set is_active = case
      when jsonb_typeof(metadata->'active') = 'boolean'
        then (metadata->>'active')::boolean
      else is_active
    end,
    parent_section = coalesce(nullif(metadata->>'section', ''), parent_section, 'general'),
    name_i18n = case
      when name_i18n = '{}'::jsonb and jsonb_typeof(metadata->'localized_names') = 'object'
        then metadata->'localized_names'
      else name_i18n
    end,
    supported_languages = case
      when jsonb_typeof(metadata->'localized_names') = 'object'
        and cardinality(
          array(
            select key
            from jsonb_object_keys(metadata->'localized_names') as key
            where key in ('en', 'te', 'hi', 'kn', 'ta')
          )
        ) > 0
        then array(
          select key
          from jsonb_object_keys(metadata->'localized_names') as key
          where key in ('en', 'te', 'hi', 'kn', 'ta')
        )
      else supported_languages
    end;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_slug_format'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_slug_format
      check (slug ~ '^[a-z0-9]+(?:[-_][a-z0-9]+)*$');
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_name_length'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_name_length
      check (char_length(btrim(name)) between 1 and 120);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_display_order_nonnegative'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_display_order_nonnegative
      check (display_order >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_description_length'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_description_length
      check (char_length(description) <= 200);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'venue_categories_supported_languages'
  ) then
    alter table public.venue_categories
      add constraint venue_categories_supported_languages
      check (
        cardinality(supported_languages) > 0
        and supported_languages <@ array['en', 'te', 'hi', 'kn', 'ta']::text[]
      );
  end if;
end $$;

with ordered as (
  select id, row_number() over (
    order by
      coalesce(nullif(metadata->>'section', ''), parent_section, 'general'),
      case
        when metadata->>'section_sort_order' ~ '^[0-9]+$'
          then (metadata->>'section_sort_order')::integer
        else 0
      end,
      name,
      id
  ) - 1 as position
  from public.venue_categories
)
update public.venue_categories c
set display_order = ordered.position
from ordered
where c.id = ordered.id
  and c.display_order = 0
  and not exists (
    select 1 from public.venue_categories existing
    where existing.display_order > 0
  );

create index if not exists idx_venue_categories_display_order
  on public.venue_categories(display_order, name);

drop trigger if exists trg_venue_categories_updated_at on public.venue_categories;
create trigger trg_venue_categories_updated_at
  before update on public.venue_categories
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Subsections shown beneath a category in the catalogue
-- ------------------------------------------------------------
create table if not exists public.venue_subsections (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.venue_categories(id) on delete cascade,
  slug text not null,
  name text not null,
  icon text,
  description text not null default '',
  image_url text,
  image_path text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  supported_languages text[] not null default array['en']::text[],
  name_i18n jsonb not null default '{}'::jsonb,
  description_i18n jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_id, slug),
  check (slug ~ '^[a-z0-9]+(?:[-_][a-z0-9]+)*$'),
  check (char_length(btrim(name)) between 1 and 120),
  check (char_length(description) <= 200),
  check (
    cardinality(supported_languages) > 0
    and supported_languages <@ array['en', 'te', 'hi', 'kn', 'ta']::text[]
  ),
  check (display_order >= 0)
);

create index if not exists idx_venue_subsections_category_order
  on public.venue_subsections(category_id, display_order, name);

drop trigger if exists trg_venue_subsections_updated_at on public.venue_subsections;
create trigger trg_venue_subsections_updated_at
  before update on public.venue_subsections
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Role checks and RLS
-- ------------------------------------------------------------
alter table public.venue_categories enable row level security;

create schema if not exists private;

create or replace function private.is_category_manager()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    exists (
      select 1
      from public.owner_profiles
      where user_id = (select auth.uid())
    )
    or public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
    or public.has_role((select auth.uid()), 'venue_owner');
$$;

-- Keep the exposed wrapper invoker-safe; the private helper avoids RLS
-- recursion while remaining unavailable as a public RPC endpoint.
create or replace function public.is_category_manager()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select private.is_category_manager();
$$;

revoke all on function private.is_category_manager() from public;
grant execute on function private.is_category_manager() to authenticated, service_role;
grant usage on schema private to authenticated, service_role;
revoke all on function public.is_category_manager() from public, anon, authenticated;
grant execute on function public.is_category_manager() to authenticated, service_role;

drop policy if exists categories_owner_admin_insert on public.venue_categories;
drop policy if exists categories_owner_admin_update on public.venue_categories;
drop policy if exists categories_public_read on public.venue_categories;
drop policy if exists categories_manager_read on public.venue_categories;
drop policy if exists categories_manager_insert on public.venue_categories;
drop policy if exists categories_manager_update on public.venue_categories;
drop policy if exists categories_manager_delete on public.venue_categories;

create policy categories_public_read on public.venue_categories
  for select to anon, authenticated
  using (is_active and deleted_at is null);

create policy categories_manager_read on public.venue_categories
  for select to authenticated
  using (public.is_category_manager());

create policy categories_manager_insert on public.venue_categories
  for insert to authenticated
  with check (public.is_category_manager());

create policy categories_manager_update on public.venue_categories
  for update to authenticated
  using (public.is_category_manager())
  with check (public.is_category_manager());

create policy categories_manager_delete on public.venue_categories
  for delete to authenticated
  using (public.is_category_manager());

alter table public.venue_subsections enable row level security;

create policy subsections_public_read on public.venue_subsections
  for select to anon, authenticated
  using (is_active);

create policy subsections_manager_read on public.venue_subsections
  for select to authenticated
  using (public.is_category_manager());

create policy subsections_manager_insert on public.venue_subsections
  for insert to authenticated
  with check (public.is_category_manager());

create policy subsections_manager_update on public.venue_subsections
  for update to authenticated
  using (public.is_category_manager())
  with check (public.is_category_manager());

create policy subsections_manager_delete on public.venue_subsections
  for delete to authenticated
  using (public.is_category_manager());

-- Reordering is atomic and cannot be used to move rows the caller does not own
-- through a crafted client payload.
create or replace function public.reorder_category_catalog(p_category_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.is_category_manager() then
    raise exception 'category manager role required' using errcode = '42501';
  end if;

  update public.venue_categories c
  set display_order = positions.position
  from (
    select id, row_number() over (order by ordinality) - 1 as position
    from unnest(p_category_ids) with ordinality as ids(id, ordinality)
  ) positions
  where c.id = positions.id;
end;
$$;

create or replace function public.reorder_category_subsections(p_category_id uuid, p_subsection_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.is_category_manager() then
    raise exception 'category manager role required' using errcode = '42501';
  end if;

  update public.venue_subsections s
  set display_order = positions.position
  from (
    select id, row_number() over (order by ordinality) - 1 as position
    from unnest(p_subsection_ids) with ordinality as ids(id, ordinality)
  ) positions
  where s.id = positions.id and s.category_id = p_category_id;
end;
$$;

grant execute on function public.reorder_category_catalog(uuid[]) to authenticated;
grant execute on function public.reorder_category_subsections(uuid, uuid[]) to authenticated;

-- ------------------------------------------------------------
-- Category media bucket
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('category-media', 'category-media', true)
on conflict (id) do update set public = excluded.public;

create policy category_media_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'category-media');

create policy category_media_manager_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'category-media'
    and public.is_category_manager()
    and (storage.foldername(name))[1] in ('categories', 'subsections')
  );

create policy category_media_manager_update on storage.objects
  for update to authenticated
  using (bucket_id = 'category-media' and public.is_category_manager())
  with check (bucket_id = 'category-media' and public.is_category_manager());

create policy category_media_manager_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'category-media' and public.is_category_manager());

-- ------------------------------------------------------------
-- Audit trail for every category/subsection mutation
-- ------------------------------------------------------------
-- Earlier migrations in this repository used both `user_id` and `actor_id`
-- for audit rows. Keep both nullable compatibility columns so this migration
-- works against either already-provisioned schema while new rows identify the
-- authenticated administrator consistently.
alter table public.audit_logs
  add column if not exists actor_id uuid references auth.users(id),
  add column if not exists user_id uuid references auth.users(id);

drop policy if exists audit_insert_any_auth on public.audit_logs;
drop policy if exists audit_admin_insert on public.audit_logs;
drop policy if exists dev_audit_insert on public.audit_logs;
drop policy if exists audit_category_manager_insert on public.audit_logs;

create policy audit_category_manager_insert on public.audit_logs
  for insert to authenticated
  with check (public.is_category_manager() and actor_id = (select auth.uid()));

create or replace function public.audit_category_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  changed_id uuid;
begin
  changed_id := coalesce(new.id, old.id);
  insert into public.audit_logs(actor_id, user_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    changed_id,
    jsonb_build_object('source', 'category_management')
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_audit_venue_categories on public.venue_categories;
create trigger trg_audit_venue_categories
  after insert or update or delete on public.venue_categories
  for each row execute function public.audit_category_mutation();

drop trigger if exists trg_audit_venue_subsections on public.venue_subsections;
create trigger trg_audit_venue_subsections
  after insert or update or delete on public.venue_subsections
  for each row execute function public.audit_category_mutation();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'venue_categories'
     ) then
    alter publication supabase_realtime add table public.venue_categories;
  end if;
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'venue_subsections'
     ) then
    alter publication supabase_realtime add table public.venue_subsections;
  end if;
end $$;
