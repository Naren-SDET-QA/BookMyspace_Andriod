-- BookMySpace — Admin Theme Customizer
--
-- Theme drafts are intentionally kept outside the exposed public schema. The
-- customer app receives only the published JSON through a read-only RPC;
-- administrators use explicit draft/publish RPCs. This keeps draft values out
-- of the existing public feature_flags read path while preserving the same
-- backend-driven configuration model.

create schema if not exists private;

create or replace function private.default_app_theme_config()
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select $json$
  {
    "schema_version": 1,
    "light": {
      "primary": "#00C9A7",
      "secondary": "#2979FF",
      "background": "#F3F7FA",
      "surface": "#FFFFFF",
      "surface_variant": "#E9F0F5",
      "text": "#0B1F33",
      "card": "#FFFFFF",
      "glass_tint": "#FFFFFF"
    },
    "dark": {
      "primary": "#5EEAD4",
      "secondary": "#2979FF",
      "background": "#071422",
      "surface": "#102433",
      "surface_variant": "#1D3447",
      "text": "#F8FAFC",
      "card": "#102433",
      "glass_tint": "#FFFFFF"
    },
    "card_radius": 16,
    "button_radius": 14,
    "input_radius": 14,
    "card_elevation": 0,
    "glass_opacity": 0.72,
    "glass_border_opacity": 0.55,
    "banner_style": "gradient",
    "button_style": "filled"
  }
  $json$::jsonb;
$$;

create or replace function private.validate_app_theme_config(p_config jsonb)
returns void
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_mode text;
  v_key text;
  v_value text;
begin
  if p_config is null or jsonb_typeof(p_config) <> 'object' then
    raise exception 'invalid_theme_config' using errcode = '22023';
  end if;

  if coalesce((p_config->>'schema_version')::integer, 0) <> 1 then
    raise exception 'unsupported_theme_config_version' using errcode = '22023';
  end if;

  foreach v_mode in array['light', 'dark'] loop
    if jsonb_typeof(p_config->v_mode) <> 'object' then
      raise exception 'invalid_theme_mode' using errcode = '22023';
    end if;
    foreach v_key in array[
      'primary', 'secondary', 'background', 'surface', 'surface_variant',
      'text', 'card', 'glass_tint'
    ] loop
      v_value := p_config->v_mode->>v_key;
      if v_value is null or v_value !~ '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$' then
        raise exception 'invalid_theme_color' using errcode = '22023';
      end if;
    end loop;
  end loop;

  if coalesce(jsonb_typeof(p_config->'card_radius'), '') <> 'number'
     or (p_config->>'card_radius')::numeric not between 0 and 32 then
    raise exception 'invalid_card_radius' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_config->'button_radius'), '') <> 'number'
     or (p_config->>'button_radius')::numeric not between 0 and 32 then
    raise exception 'invalid_button_radius' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_config->'input_radius'), '') <> 'number'
     or (p_config->>'input_radius')::numeric not between 0 and 32 then
    raise exception 'invalid_input_radius' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_config->'card_elevation'), '') <> 'number'
     or (p_config->>'card_elevation')::numeric not between 0 and 12 then
    raise exception 'invalid_card_elevation' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_config->'glass_opacity'), '') <> 'number'
     or (p_config->>'glass_opacity')::numeric not between 0 and 1 then
    raise exception 'invalid_glass_opacity' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_config->'glass_border_opacity'), '') <> 'number'
     or (p_config->>'glass_border_opacity')::numeric not between 0 and 1 then
    raise exception 'invalid_glass_border_opacity' using errcode = '22023';
  end if;
  if coalesce(p_config->>'banner_style', '') not in ('gradient', 'solid', 'minimal') then
    raise exception 'invalid_banner_style' using errcode = '22023';
  end if;
  if coalesce(p_config->>'button_style', '') not in ('filled', 'soft', 'outline') then
    raise exception 'invalid_button_style' using errcode = '22023';
  end if;
end;
$$;

revoke all on function private.default_app_theme_config() from public;
revoke all on function private.validate_app_theme_config(jsonb) from public;
grant usage on schema private to authenticated, service_role;

create table if not exists private.app_theme_configs (
  singleton boolean primary key default true check (singleton),
  draft_config jsonb not null,
  published_config jsonb not null,
  draft_version bigint not null default 1 check (draft_version > 0),
  published_version bigint not null default 1 check (published_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  published_at timestamptz not null default now(),
  published_by uuid references auth.users(id)
);

alter table private.app_theme_configs enable row level security;
revoke all on private.app_theme_configs from public, anon, authenticated;

insert into private.app_theme_configs (
  singleton,
  draft_config,
  published_config,
  updated_by,
  published_by
)
values (
  true,
  private.default_app_theme_config(),
  private.default_app_theme_config(),
  null,
  null
)
on conflict (singleton) do nothing;

create or replace function public.get_published_app_theme_config()
returns jsonb
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select coalesce(
    (
      select published_config
      from private.app_theme_configs
      where singleton = true
    ),
    private.default_app_theme_config()
  );
$$;

create or replace function public.get_admin_app_theme_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_row private.app_theme_configs%rowtype;
begin
  if not public.is_platform_admin((select auth.uid())) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;

  select * into v_row
  from private.app_theme_configs
  where singleton = true;

  return jsonb_build_object(
    'draft_config', v_row.draft_config,
    'published_config', v_row.published_config,
    'draft_version', v_row.draft_version,
    'published_version', v_row.published_version,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at,
    'updated_by', v_row.updated_by,
    'published_at', v_row.published_at,
    'published_by', v_row.published_by
  );
end;
$$;

create or replace function public.save_app_theme_draft(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_old jsonb;
begin
  if not public.is_platform_admin((select auth.uid())) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  perform private.validate_app_theme_config(p_config);

  select draft_config into v_old
  from private.app_theme_configs
  where singleton = true
  for update;

  update private.app_theme_configs
  set draft_config = p_config,
      draft_version = draft_version + 1,
      updated_at = now(),
      updated_by = (select auth.uid())
  where singleton = true;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    'app_theme_draft_saved',
    'app_theme_config',
    null,
    jsonb_build_object('old_draft', v_old, 'new_draft', p_config)
  );

  return public.get_admin_app_theme_config();
end;
$$;

create or replace function public.publish_app_theme_config()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_old jsonb;
  v_draft jsonb;
begin
  if not public.is_platform_admin((select auth.uid())) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;

  select published_config, draft_config
    into v_old, v_draft
  from private.app_theme_configs
  where singleton = true
  for update;

  perform private.validate_app_theme_config(v_draft);

  update private.app_theme_configs
  set published_config = v_draft,
      published_version = published_version + 1,
      published_at = now(),
      published_by = (select auth.uid()),
      updated_at = now(),
      updated_by = (select auth.uid())
  where singleton = true;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    'app_theme_published',
    'app_theme_config',
    null,
    jsonb_build_object(
      'old_published', v_old,
      'new_published', v_draft,
      'published_at', now()
    )
  );

  return public.get_admin_app_theme_config();
end;
$$;

revoke all on function public.get_published_app_theme_config() from public, anon, authenticated;
revoke all on function public.get_admin_app_theme_config() from public, anon, authenticated;
revoke all on function public.save_app_theme_draft(jsonb) from public, anon, authenticated;
revoke all on function public.publish_app_theme_config() from public, anon, authenticated;

grant execute on function public.get_published_app_theme_config() to anon, authenticated;
grant execute on function public.get_admin_app_theme_config() to authenticated;
grant execute on function public.save_app_theme_draft(jsonb) to authenticated;
grant execute on function public.publish_app_theme_config() to authenticated;

comment on table private.app_theme_configs is
  'Singleton global app theme. Draft and published snapshots are private; use the explicit RPCs.';
comment on function public.get_published_app_theme_config() is
  'Public customer read path. Returns published theme tokens only.';
comment on function public.get_admin_app_theme_config() is
  'Administrator-only read of draft and published theme snapshots.';
