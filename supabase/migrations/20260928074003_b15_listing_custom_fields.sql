-- B15: admin-defined listing fields with server-enforced ownership.

create table if not exists public.venue_listing_field_definitions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.venue_categories(id) on delete cascade,
  field_key text not null,
  label text not null,
  field_type text not null check (field_type in (
    'text', 'number', 'boolean', 'date', 'dropdown', 'multiselect',
    'url', 'phone', 'currency')),
  options jsonb not null default '[]'::jsonb,
  required boolean not null default false,
  enabled boolean not null default true,
  display_order integer not null default 0 check (display_order >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_id, field_key)
);

create table if not exists public.venue_listing_field_values (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  field_definition_id uuid not null references public.venue_listing_field_definitions(id) on delete cascade,
  value jsonb not null default 'null'::jsonb,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, field_definition_id)
);

create index if not exists venue_listing_fields_category_order_idx
  on public.venue_listing_field_definitions(category_id, enabled, display_order);
create index if not exists venue_listing_field_values_venue_idx
  on public.venue_listing_field_values(venue_id);

alter table public.venue_listing_field_definitions enable row level security;
alter table public.venue_listing_field_values enable row level security;
grant select on public.venue_listing_field_definitions, public.venue_listing_field_values to anon, authenticated;

drop policy if exists venue_listing_field_definitions_public_read on public.venue_listing_field_definitions;
create policy venue_listing_field_definitions_public_read
  on public.venue_listing_field_definitions for select
  using (enabled = true);

drop policy if exists venue_listing_field_definitions_admin_manage on public.venue_listing_field_definitions;
create policy venue_listing_field_definitions_admin_manage
  on public.venue_listing_field_definitions for all to authenticated
  using (public.is_platform_admin((select auth.uid())))
  with check (public.is_platform_admin((select auth.uid())));

drop policy if exists venue_listing_field_values_public_read on public.venue_listing_field_values;
create policy venue_listing_field_values_public_read
  on public.venue_listing_field_values for select
  using (exists (
    select 1 from public.venues v
    join public.venue_listing_field_definitions d on d.id = field_definition_id
    where v.id = venue_id and v.is_active and d.enabled
  ));

drop policy if exists venue_listing_field_values_owner_manage on public.venue_listing_field_values;
create policy venue_listing_field_values_owner_manage
  on public.venue_listing_field_values for all to authenticated
  using (exists (
    select 1 from public.venues v
    where v.id = venue_id and public.is_org_owner(v.org_id, (select auth.uid()))
  ))
  with check (exists (
    select 1 from public.venues v
    where v.id = venue_id and public.is_org_owner(v.org_id, (select auth.uid()))
  ));

create or replace function public.list_venue_listing_fields(p_venue_id uuid)
returns table (
  field_id uuid,
  field_key text,
  label text,
  field_type text,
  options jsonb,
  required boolean,
  value jsonb
)
language sql
stable
security invoker
set search_path = public
as $$
  select d.id, d.field_key, d.label, d.field_type, d.options, d.required,
         coalesce(v.value, 'null'::jsonb)
    from public.venues venue
    join public.venue_listing_field_definitions d
      on d.enabled and (d.category_id is null or d.category_id = venue.category_id)
    left join public.venue_listing_field_values v
      on v.venue_id = venue.id and v.field_definition_id = d.id
   where venue.id = p_venue_id and venue.is_active
   order by d.display_order, d.label;
$$;

create or replace function public.save_venue_listing_field(
  p_venue_id uuid,
  p_field_definition_id uuid,
  p_value jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_value jsonb;
begin
  if auth.uid() is null then raise exception 'unauthenticated'; end if;
  if not exists (
    select 1 from public.venues venue
    join public.venue_listing_field_definitions d on d.id = p_field_definition_id
    where venue.id = p_venue_id and d.enabled
      and (d.category_id is null or d.category_id = venue.category_id)
      and (public.is_org_owner(venue.org_id, (select auth.uid()))
        or public.is_platform_admin((select auth.uid())))
  ) then raise exception 'not_authorized'; end if;

  insert into public.venue_listing_field_values
    (venue_id, field_definition_id, value, updated_by, updated_at)
  values (p_venue_id, p_field_definition_id, coalesce(p_value, 'null'::jsonb),
    (select auth.uid()), now())
  on conflict (venue_id, field_definition_id) do update set
    value = excluded.value, updated_by = excluded.updated_by, updated_at = now()
  returning to_jsonb(venue_listing_field_values.*) into v_value;
  return v_value;
end;
$$;

create or replace function public.admin_save_listing_field_definition(
  p_id uuid default null,
  p_category_id uuid default null,
  p_field_key text default null,
  p_label text default null,
  p_field_type text default 'text',
  p_options jsonb default '[]'::jsonb,
  p_required boolean default false,
  p_enabled boolean default true,
  p_display_order integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_row public.venue_listing_field_definitions;
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  if nullif(trim(p_field_key), '') is null or nullif(trim(p_label), '') is null then
    raise exception 'field_key_and_label_required';
  end if;
  if p_field_type not in ('text','number','boolean','date','dropdown','multiselect','url','phone','currency') then
    raise exception 'invalid_field_type';
  end if;
  if p_field_type in ('dropdown','multiselect') and jsonb_typeof(coalesce(p_options, '[]'::jsonb)) <> 'array' then
    raise exception 'options_must_be_array';
  end if;
  insert into public.venue_listing_field_definitions
    (id, category_id, field_key, label, field_type, options, required, enabled, display_order, created_by, updated_at)
  values (coalesce(p_id, gen_random_uuid()), p_category_id, lower(trim(p_field_key)), trim(p_label),
    p_field_type, coalesce(p_options, '[]'::jsonb), p_required, p_enabled,
    greatest(0, p_display_order), (select auth.uid()), now())
  on conflict (id) do update set
    category_id = excluded.category_id, field_key = excluded.field_key,
    label = excluded.label, field_type = excluded.field_type, options = excluded.options,
    required = excluded.required, enabled = excluded.enabled,
    display_order = excluded.display_order, updated_at = now()
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.admin_delete_listing_field_definition(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  delete from public.venue_listing_field_definitions where id = p_id;
end;
$$;

revoke all on function public.list_venue_listing_fields(uuid) from public;
revoke all on function public.save_venue_listing_field(uuid, uuid, jsonb) from public, anon;
revoke all on function public.admin_save_listing_field_definition(uuid, uuid, text, text, text, jsonb, boolean, boolean, integer) from public, anon;
revoke all on function public.admin_delete_listing_field_definition(uuid) from public, anon;
grant execute on function public.list_venue_listing_fields(uuid) to anon, authenticated;
grant execute on function public.save_venue_listing_field(uuid, uuid, jsonb) to authenticated;
grant execute on function public.admin_save_listing_field_definition(uuid, uuid, text, text, text, jsonb, boolean, boolean, integer) to authenticated;
grant execute on function public.admin_delete_listing_field_definition(uuid) to authenticated;
