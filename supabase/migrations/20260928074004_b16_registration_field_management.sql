-- B16: complete admin lifecycle for owner-registration fields.

alter table public.owner_registration_field_configs
  add column if not exists regex_pattern text,
  add column if not exists preset_key text;

create table if not exists public.owner_registration_field_presets (
  id uuid primary key default gen_random_uuid(),
  preset_key text not null unique,
  display_label text not null,
  fields jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(fields) = 'array')
);

alter table public.owner_registration_field_presets enable row level security;
revoke all on public.owner_registration_field_presets from anon, authenticated;

create or replace function public.admin_create_registration_field(
  p_field_key text,
  p_display_label text,
  p_field_type text default 'text',
  p_required boolean default false,
  p_regex_pattern text default null,
  p_validation_rules jsonb default '{}'::jsonb,
  p_preset_key text default null,
  p_display_order integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_row public.owner_registration_field_configs;
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  if nullif(trim(p_field_key), '') is null or nullif(trim(p_display_label), '') is null then
    raise exception 'field_key_and_label_required';
  end if;
  if p_field_type not in ('text','number','phone','email','date','dropdown','multiselect','address','document_upload','image_upload','boolean') then
    raise exception 'invalid_field_type';
  end if;
  insert into public.owner_registration_field_configs
    (field_key, display_label, field_type, required, validation_rules,
     regex_pattern, preset_key, display_order, updated_by, updated_at)
  values (lower(trim(p_field_key)), trim(p_display_label), p_field_type, p_required,
    coalesce(p_validation_rules, '{}'::jsonb), nullif(trim(p_regex_pattern), ''),
    nullif(trim(p_preset_key), ''), greatest(0, p_display_order), (select auth.uid()), now())
  on conflict (field_key) do update set
    display_label = excluded.display_label, field_type = excluded.field_type,
    required = excluded.required, validation_rules = excluded.validation_rules,
    regex_pattern = excluded.regex_pattern, preset_key = excluded.preset_key,
    display_order = excluded.display_order, updated_by = excluded.updated_by,
    updated_at = now()
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.admin_delete_registration_field(p_field_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  delete from public.owner_registration_values where field_key = p_field_key;
  delete from public.owner_registration_field_configs where field_key = p_field_key;
end;
$$;

create or replace function public.admin_reorder_registration_fields(p_field_keys text[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_key text; v_order integer := 0; v_count integer := 0;
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  foreach v_key in array coalesce(p_field_keys, '{}'::text[]) loop
    update public.owner_registration_field_configs
       set display_order = v_order, updated_by = (select auth.uid()), updated_at = now()
     where field_key = v_key;
    if found then v_count := v_count + 1; end if;
    v_order := v_order + 10;
  end loop;
  return v_count;
end;
$$;

create or replace function public.admin_save_registration_preset(
  p_preset_key text,
  p_display_label text,
  p_fields jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_row public.owner_registration_field_presets;
begin
  if not public.is_platform_admin((select auth.uid())) then raise exception 'admin_required'; end if;
  if nullif(trim(p_preset_key), '') is null or nullif(trim(p_display_label), '') is null then
    raise exception 'preset_key_and_label_required';
  end if;
  if jsonb_typeof(coalesce(p_fields, '[]'::jsonb)) <> 'array' then
    raise exception 'preset_fields_must_be_array';
  end if;
  insert into public.owner_registration_field_presets
    (preset_key, display_label, fields, created_by, updated_at)
  values (lower(trim(p_preset_key)), trim(p_display_label), coalesce(p_fields, '[]'::jsonb),
    (select auth.uid()), now())
  on conflict (preset_key) do update set
    display_label = excluded.display_label, fields = excluded.fields,
    created_by = excluded.created_by, updated_at = now()
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

revoke all on function public.admin_create_registration_field(text, text, text, boolean, text, jsonb, text, integer) from public, anon;
revoke all on function public.admin_delete_registration_field(text) from public, anon;
revoke all on function public.admin_reorder_registration_fields(text[]) from public, anon;
revoke all on function public.admin_save_registration_preset(text, text, jsonb) from public, anon;
grant execute on function public.admin_create_registration_field(text, text, text, boolean, text, jsonb, text, integer) to authenticated;
grant execute on function public.admin_delete_registration_field(text) to authenticated;
grant execute on function public.admin_reorder_registration_fields(text[]) to authenticated;
grant execute on function public.admin_save_registration_preset(text, text, jsonb) to authenticated;
