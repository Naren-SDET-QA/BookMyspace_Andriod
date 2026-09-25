-- Owner plug-and-play venue page sections.
--
-- Gives a venue Owner a genuinely per-venue, backend-authoritative way to
-- enable/disable optional page sections for their OWN venue, configure
-- subsection visibility, edit title/content/image/icon where the schema
-- permits, reorder sections, set multilingual content, preview a draft, and
-- publish it -- all without any Flutter/code change, mirroring the
-- Admin-owned venue_categories/feature_flags plug-and-play model but scoped
-- to a single organisation's own venue instead of the whole platform.
--
-- Two-table shape, same pattern as venue_categories/venue_subsections:
--   venue_section_types  -- Admin-only global catalog of supported sections
--   venue_sections        -- one row per venue per section type; Owner-writable
--                             draft columns, plus a published_config snapshot
--                             that only publish_venue_sections() may write.
-- Customer surfaces read ONLY through list_published_venue_sections(); the
-- base table is never selectable by anon and never by another owner.

-- ---------------------------------------------------------------------------
-- 1. Admin-managed catalog of supported section types.
-- ---------------------------------------------------------------------------
create table if not exists public.venue_section_types (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (char_length(name) between 1 and 80),
  description text not null default '',
  icon text,
  allows_multiple boolean not null default false,
  available_subsections jsonb not null default '[]'::jsonb,
  editable_fields jsonb not null default '{"title": true, "content": true, "image": true}'::jsonb,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.venue_section_types is
  'Admin-defined catalog of optional page sections an Owner may enable for their own venue. Global platform configuration, never Owner-writable -- mirrors venue_categories.';

drop trigger if exists venue_section_types_set_updated_at on public.venue_section_types;
create trigger venue_section_types_set_updated_at
  before update on public.venue_section_types
  for each row execute function public.set_updated_at();

alter table public.venue_section_types enable row level security;

drop policy if exists venue_section_types_public_read on public.venue_section_types;
create policy venue_section_types_public_read on public.venue_section_types
  for select to anon, authenticated
  using (is_active);

drop policy if exists venue_section_types_admin_write on public.venue_section_types;
create policy venue_section_types_admin_write on public.venue_section_types
  for all to authenticated
  using (public.is_platform_admin((select auth.uid())))
  with check (public.is_platform_admin((select auth.uid())));

revoke all on public.venue_section_types from public, anon;
grant select on public.venue_section_types to anon, authenticated;
grant insert, update, delete on public.venue_section_types to authenticated;

insert into public.venue_section_types (key, name, description, icon, allows_multiple, available_subsections, editable_fields, display_order)
values
  ('about', 'About this venue', 'Longer description shown below the headline summary.', 'info_outline', false,
    '[]'::jsonb, '{"title": true, "content": true, "image": false, "subsections": false}'::jsonb, 10),
  ('amenities', 'Amenities', 'Facilities and conveniences available at the venue.', 'check_circle_outline', false,
    '[{"key":"parking","label":"Parking"},{"key":"catering","label":"Catering"},{"key":"wifi","label":"Wi-Fi"},{"key":"ac","label":"Air Conditioning"},{"key":"outdoor","label":"Outdoor Area"},{"key":"stage","label":"Stage / AV"},{"key":"decor","label":"In-house Decor"}]'::jsonb,
    '{"title": true, "content": true, "image": false, "subsections": true}'::jsonb, 20),
  ('gallery', 'Photo gallery', 'Additional photos beyond the main cover images.', 'photo_library_outlined', false,
    '[]'::jsonb, '{"title": true, "content": false, "image": true, "subsections": false}'::jsonb, 30),
  ('policies', 'Policies', 'Cancellation, refund, and house rules.', 'gavel_outlined', false,
    '[{"key":"cancellation","label":"Cancellation Policy"},{"key":"refund","label":"Refund Policy"},{"key":"house_rules","label":"House Rules"}]'::jsonb,
    '{"title": true, "content": true, "image": false, "subsections": true}'::jsonb, 40),
  ('faq', 'Frequently asked questions', 'Common customer questions and answers.', 'help_outline', false,
    '[]'::jsonb, '{"title": true, "content": true, "image": false, "subsections": false}'::jsonb, 50),
  ('nearby', 'Nearby attractions', 'Landmarks, parking, or transit near the venue.', 'place_outlined', false,
    '[]'::jsonb, '{"title": true, "content": true, "image": true, "subsections": false}'::jsonb, 60),
  ('custom', 'Custom section', 'A free-form section for anything not covered above.', 'dashboard_customize_outlined', true,
    '[]'::jsonb, '{"title": true, "content": true, "image": true, "subsections": false}'::jsonb, 70)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Per-venue section instance. Draft columns are Owner-editable;
--    published_config is a snapshot written only by publish_venue_sections().
-- ---------------------------------------------------------------------------
create table if not exists public.venue_sections (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  section_type_id uuid not null references public.venue_section_types(id),
  type_key text,
  type_allows_multiple boolean not null default false,
  is_enabled boolean not null default true,
  title text check (char_length(title) <= 150),
  title_i18n jsonb not null default '{}'::jsonb,
  content text check (char_length(content) <= 8000),
  content_i18n jsonb not null default '{}'::jsonb,
  image_url text,
  image_path text,
  icon text,
  display_order integer not null default 0,
  visible_subsections jsonb not null default '[]'::jsonb,
  config jsonb not null default '{}'::jsonb,
  published_config jsonb,
  published_at timestamptz,
  published_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.venue_sections is
  'Owner-configurable optional page sections for one venue. Draft columns are edited directly by the owning organisation via RLS; published_config is a snapshot written only by publish_venue_sections() and is the only thing customer surfaces ever read.';

create index if not exists venue_sections_venue_id_idx on public.venue_sections (venue_id, display_order);

create unique index if not exists venue_sections_unique_single_type_idx
  on public.venue_sections (venue_id, section_type_id)
  where not type_allows_multiple;

drop trigger if exists venue_sections_set_updated_at on public.venue_sections;
create trigger venue_sections_set_updated_at
  before update on public.venue_sections
  for each row execute function public.set_updated_at();

create or replace function public.validate_venue_section()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_type record;
  v_item text;
  v_ok boolean;
begin
  select key, allows_multiple, available_subsections
  into v_type
  from public.venue_section_types
  where id = new.section_type_id;

  if not found then
    raise exception 'invalid_section_type' using errcode = '23503';
  end if;

  if tg_op = 'UPDATE' and new.section_type_id <> old.section_type_id then
    raise exception 'section_type_immutable' using errcode = '22023';
  end if;

  new.type_key := v_type.key;
  new.type_allows_multiple := v_type.allows_multiple;

  if not v_type.allows_multiple and exists (
    select 1 from public.venue_sections s
    where s.venue_id = new.venue_id
      and s.section_type_id = new.section_type_id
      and s.id <> new.id
  ) then
    raise exception 'section_type_already_added' using errcode = '23505';
  end if;

  if jsonb_typeof(new.visible_subsections) is distinct from 'array' then
    raise exception 'visible_subsections_must_be_array' using errcode = '22023';
  end if;
  for v_item in select value from jsonb_array_elements_text(new.visible_subsections) loop
    v_ok := exists (
      select 1 from jsonb_array_elements(coalesce(v_type.available_subsections, '[]'::jsonb)) a
      where a->>'key' = v_item
    );
    if not v_ok then
      raise exception 'unsupported_subsection: %', v_item using errcode = '22023';
    end if;
  end loop;

  -- Publication state is only ever written by publish_venue_sections();
  -- neutralise any client attempt to set it directly, even though the
  -- column-level grants below already withhold write access to it.
  if tg_op = 'UPDATE' then
    new.published_config := old.published_config;
    new.published_at := old.published_at;
    new.published_by := old.published_by;
  else
    new.published_config := null;
    new.published_at := null;
    new.published_by := null;
  end if;

  new.updated_by := coalesce((select auth.uid()), new.updated_by);
  return new;
end;
$$;

drop trigger if exists venue_sections_validate on public.venue_sections;
create trigger venue_sections_validate
  before insert or update on public.venue_sections
  for each row execute function public.validate_venue_section();

create or replace function public.audit_venue_section_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    case tg_op when 'INSERT' then 'venue_section_added' else 'venue_section_removed' end,
    'venue_section',
    coalesce(new.id, old.id),
    jsonb_build_object(
      'venue_id', coalesce(new.venue_id, old.venue_id),
      'section_type_id', coalesce(new.section_type_id, old.section_type_id)
    )
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists venue_sections_audit on public.venue_sections;
create trigger venue_sections_audit
  after insert or delete on public.venue_sections
  for each row execute function public.audit_venue_section_change();

alter table public.venue_sections enable row level security;

-- No policy grants anon/authenticated-at-large any SELECT here: the
-- customer app must go through list_published_venue_sections() below.
drop policy if exists venue_sections_owner_select on public.venue_sections;
create policy venue_sections_owner_select on public.venue_sections
  for select to authenticated
  using (
    public.owns_venue((select auth.uid()), venue_id)
    or public.is_platform_admin((select auth.uid()))
  );

drop policy if exists venue_sections_owner_insert on public.venue_sections;
create policy venue_sections_owner_insert on public.venue_sections
  for insert to authenticated
  with check (
    public.owns_venue((select auth.uid()), venue_id)
    or public.is_platform_admin((select auth.uid()))
  );

drop policy if exists venue_sections_owner_update on public.venue_sections;
create policy venue_sections_owner_update on public.venue_sections
  for update to authenticated
  using (
    public.owns_venue((select auth.uid()), venue_id)
    or public.is_platform_admin((select auth.uid()))
  )
  with check (
    public.owns_venue((select auth.uid()), venue_id)
    or public.is_platform_admin((select auth.uid()))
  );

drop policy if exists venue_sections_owner_delete on public.venue_sections;
create policy venue_sections_owner_delete on public.venue_sections
  for delete to authenticated
  using (
    public.owns_venue((select auth.uid()), venue_id)
    or public.is_platform_admin((select auth.uid()))
  );

revoke all on public.venue_sections from public, anon;
grant select, insert, delete on public.venue_sections to authenticated;
grant update (
  is_enabled, title, title_i18n, content, content_i18n,
  image_url, image_path, icon, display_order, visible_subsections, config
) on public.venue_sections to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Publish: the only path that may turn a draft into what customers see.
-- ---------------------------------------------------------------------------
create or replace function public.publish_venue_sections(p_venue_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if not (public.owns_venue((select auth.uid()), p_venue_id) or public.is_platform_admin((select auth.uid()))) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  update public.venue_sections s
  set published_config = jsonb_build_object(
        'is_enabled', s.is_enabled,
        'title', s.title,
        'title_i18n', s.title_i18n,
        'content', s.content,
        'content_i18n', s.content_i18n,
        'image_url', s.image_url,
        'icon', s.icon,
        'display_order', s.display_order,
        'visible_subsections', s.visible_subsections,
        'config', s.config
      ),
      published_at = now(),
      published_by = (select auth.uid())
  where s.venue_id = p_venue_id;
  get diagnostics v_count = row_count;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()), 'venue_sections_published', 'venue', p_venue_id,
    jsonb_build_object('venue_id', p_venue_id, 'section_count', v_count)
  );

  return jsonb_build_object(
    'success', true, 'venue_id', p_venue_id,
    'published_count', v_count, 'published_at', now()
  );
end;
$$;

revoke all on function public.publish_venue_sections(uuid) from public, anon;
grant execute on function public.publish_venue_sections(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Customer read path: published, enabled sections only, for active
--    venues and still-active section types. This is the ONLY way section
--    content reaches anon/authenticated customer surfaces.
-- ---------------------------------------------------------------------------
create or replace function public.list_published_venue_sections(p_venue_id uuid)
returns table (
  id uuid,
  section_key text,
  section_name text,
  section_icon text,
  title text,
  content text,
  image_url text,
  display_order integer,
  visible_subsections jsonb,
  config jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    s.id,
    t.key,
    t.name,
    coalesce(s.icon, t.icon),
    coalesce(s.published_config->>'title', ''),
    coalesce(s.published_config->>'content', ''),
    coalesce(s.published_config->>'image_url', s.image_url, ''),
    coalesce((s.published_config->>'display_order')::integer, s.display_order),
    coalesce(s.published_config->'visible_subsections', '[]'::jsonb),
    coalesce(s.published_config->'config', '{}'::jsonb),
    s.published_at
  from public.venue_sections s
  join public.venue_section_types t on t.id = s.section_type_id
  join public.venues v on v.id = s.venue_id
  where s.venue_id = p_venue_id
    and s.published_config is not null
    and coalesce((s.published_config->>'is_enabled')::boolean, false) = true
    and t.is_active = true
    and v.deleted_at is null
    and v.is_active = true
  order by coalesce((s.published_config->>'display_order')::integer, s.display_order), t.display_order;
$$;

revoke all on function public.list_published_venue_sections(uuid) from public;
grant execute on function public.list_published_venue_sections(uuid) to anon, authenticated;

-- Realtime so the Owner's own editor and (optionally) a live preview can
-- react to server-side confirmation without polling.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_rel pr
       join pg_class c on c.oid = pr.prrelid
       join pg_namespace n on n.oid = c.relnamespace
       join pg_publication p on p.oid = pr.prpubid
       where p.pubname = 'supabase_realtime'
         and n.nspname = 'public'
         and c.relname = 'venue_sections'
     ) then
    alter publication supabase_realtime add table public.venue_sections;
  end if;
end $$;

-- Trigger functions must never be directly callable as RPCs (matches the
-- existing pattern for validate_feature_flag_config/audit_feature_flag_change).
revoke all on function public.validate_venue_section() from public, anon, authenticated;
revoke all on function public.audit_venue_section_change() from public, anon, authenticated;
grant execute on function public.validate_venue_section() to postgres, service_role;
grant execute on function public.audit_venue_section_change() to postgres, service_role;

-- Found via live testing: this project's default privileges grant
-- authenticated blanket SELECT/INSERT/UPDATE/REFERENCES on every column of
-- every new public table, so the earlier column-scoped "grant update (...)"
-- above was purely additive and did not actually withhold UPDATE on
-- published_config/published_at/published_by/venue_id/section_type_id/etc.
-- The BEFORE trigger already neutralises any client-supplied published_*
-- value on write (verified live), so this was not an exploitable gap, but
-- the column grants should actually mean what they say.
revoke all on public.venue_sections from authenticated;
grant select, insert, delete on public.venue_sections to authenticated;
grant update (
  is_enabled, title, title_i18n, content, content_i18n,
  image_url, image_path, icon, display_order, visible_subsections, config
) on public.venue_sections to authenticated;

-- Bug found via live testing: validate_venue_section() unconditionally reset
-- published_config/published_at/published_by back to the OLD row on every
-- UPDATE, including the UPDATE issued by publish_venue_sections() itself.
-- Result: publish_venue_sections() reported success with a nonzero row
-- count, but published_config stayed null and nothing ever became visible
-- to list_published_venue_sections(). Fix: let the trigger tell the
-- difference between a client-initiated draft edit (must not touch
-- published_*) and the publish RPC's own write (must be allowed through),
-- using a transaction-local flag that only the security-definer publish
-- function can set -- there is no RPC or table grant that lets a normal
-- client set this GUC, so it cannot be spoofed via PostgREST.

create or replace function public.validate_venue_section()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_type record;
  v_item text;
  v_ok boolean;
  v_publishing boolean;
begin
  select key, allows_multiple, available_subsections
  into v_type
  from public.venue_section_types
  where id = new.section_type_id;

  if not found then
    raise exception 'invalid_section_type' using errcode = '23503';
  end if;

  if tg_op = 'UPDATE' and new.section_type_id <> old.section_type_id then
    raise exception 'section_type_immutable' using errcode = '22023';
  end if;

  new.type_key := v_type.key;
  new.type_allows_multiple := v_type.allows_multiple;

  if not v_type.allows_multiple and exists (
    select 1 from public.venue_sections s
    where s.venue_id = new.venue_id
      and s.section_type_id = new.section_type_id
      and s.id <> new.id
  ) then
    raise exception 'section_type_already_added' using errcode = '23505';
  end if;

  if jsonb_typeof(new.visible_subsections) is distinct from 'array' then
    raise exception 'visible_subsections_must_be_array' using errcode = '22023';
  end if;
  for v_item in select value from jsonb_array_elements_text(new.visible_subsections) loop
    v_ok := exists (
      select 1 from jsonb_array_elements(coalesce(v_type.available_subsections, '[]'::jsonb)) a
      where a->>'key' = v_item
    );
    if not v_ok then
      raise exception 'unsupported_subsection: %', v_item using errcode = '22023';
    end if;
  end loop;

  v_publishing := coalesce(current_setting('app.publishing_venue_sections', true), '') = 'true';

  if tg_op = 'UPDATE' and not v_publishing then
    new.published_config := old.published_config;
    new.published_at := old.published_at;
    new.published_by := old.published_by;
  elsif tg_op = 'INSERT' then
    new.published_config := null;
    new.published_at := null;
    new.published_by := null;
  end if;
  -- else: tg_op = 'UPDATE' and v_publishing -- publish_venue_sections()
  -- writing published_* itself; let its values through unchanged.

  new.updated_by := coalesce((select auth.uid()), new.updated_by);
  return new;
end;
$$;

create or replace function public.publish_venue_sections(p_venue_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if not (public.owns_venue((select auth.uid()), p_venue_id) or public.is_platform_admin((select auth.uid()))) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  perform set_config('app.publishing_venue_sections', 'true', true);

  update public.venue_sections s
  set published_config = jsonb_build_object(
        'is_enabled', s.is_enabled,
        'title', s.title,
        'title_i18n', s.title_i18n,
        'content', s.content,
        'content_i18n', s.content_i18n,
        'image_url', s.image_url,
        'icon', s.icon,
        'display_order', s.display_order,
        'visible_subsections', s.visible_subsections,
        'config', s.config
      ),
      published_at = now(),
      published_by = (select auth.uid())
  where s.venue_id = p_venue_id;
  get diagnostics v_count = row_count;

  perform set_config('app.publishing_venue_sections', 'false', true);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()), 'venue_sections_published', 'venue', p_venue_id,
    jsonb_build_object('venue_id', p_venue_id, 'section_count', v_count)
  );

  return jsonb_build_object(
    'success', true, 'venue_id', p_venue_id,
    'published_count', v_count, 'published_at', now()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Hardening fix (final verification pass, 2026-09-13): publish_venue_sections
-- already snapshotted title_i18n/content_i18n into published_config, and
-- Owners could already write those draft columns, but
-- list_published_venue_sections() silently dropped them from its return
-- shape -- so a published translation was stored but unreachable by any
-- customer-facing read. Purely additive: adds two output columns only.
-- ---------------------------------------------------------------------------

drop function if exists public.list_published_venue_sections(uuid);

create function public.list_published_venue_sections(p_venue_id uuid)
returns table (
  id uuid,
  section_key text,
  section_name text,
  section_icon text,
  title text,
  title_i18n jsonb,
  content text,
  content_i18n jsonb,
  image_url text,
  display_order integer,
  visible_subsections jsonb,
  config jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    s.id,
    t.key,
    t.name,
    coalesce(s.icon, t.icon),
    coalesce(s.published_config->>'title', ''),
    coalesce(s.published_config->'title_i18n', '{}'::jsonb),
    coalesce(s.published_config->>'content', ''),
    coalesce(s.published_config->'content_i18n', '{}'::jsonb),
    coalesce(s.published_config->>'image_url', s.image_url, ''),
    coalesce((s.published_config->>'display_order')::integer, s.display_order),
    coalesce(s.published_config->'visible_subsections', '[]'::jsonb),
    coalesce(s.published_config->'config', '{}'::jsonb),
    s.published_at
  from public.venue_sections s
  join public.venue_section_types t on t.id = s.section_type_id
  join public.venues v on v.id = s.venue_id
  where s.venue_id = p_venue_id
    and s.published_config is not null
    and coalesce((s.published_config->>'is_enabled')::boolean, false) = true
    and t.is_active = true
    and v.deleted_at is null
    and v.is_active = true
  order by coalesce((s.published_config->>'display_order')::integer, s.display_order), t.display_order;
$$;

comment on function public.list_published_venue_sections(uuid) is
  'Customer-facing read of published venue sections only. Fixed 2026-09-13: '
  'now also returns title_i18n/content_i18n (already captured by '
  'publish_venue_sections) so multilingual owner content is actually '
  'reachable by customer surfaces, not just stored.';

revoke all on function public.list_published_venue_sections(uuid) from public;
grant execute on function public.list_published_venue_sections(uuid) to anon, authenticated;
