-- Universal admin edit: any element / image / field / logo across the app.
--
-- Extends ui_element_overrides with image / link / color so a single table
-- covers text + placeholder + image + navigation + tint for EVERY screen.
-- Branding (logo, splash, app name) lives in the existing global
-- module_feature_configs row with module_key = 'branding' -- no new table,
-- so current RLS/admin-write paths keep working.

alter table public.ui_element_overrides
  add column if not exists image_url text,
  add column if not exists link_url text,
  add column if not exists color_value text;

alter table public.ui_element_overrides
  drop constraint if exists ui_element_overrides_image_url_check;
alter table public.ui_element_overrides
  add constraint ui_element_overrides_image_url_check
  check (image_url is null or length(image_url) <= 2000);
alter table public.ui_element_overrides
  drop constraint if exists ui_element_overrides_link_url_check;
alter table public.ui_element_overrides
  add constraint ui_element_overrides_link_url_check
  check (link_url is null or length(link_url) <= 2000);
alter table public.ui_element_overrides
  drop constraint if exists ui_element_overrides_color_check;
alter table public.ui_element_overrides
  add constraint ui_element_overrides_color_check
  check (color_value is null or length(color_value) <= 32);

-- Resolved payload now includes image / link / color alongside text.
create or replace function public.get_ui_element_overrides(
  p_screen_key text,
  p_locale text default 'en'
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $function$
  select coalesce(jsonb_object_agg(element_key, jsonb_build_object(
    'text', text_value,
    'placeholder', placeholder_value,
    'hidden', is_hidden,
    'image', image_url,
    'link', link_url,
    'color', color_value
  )), '{}'::jsonb)
  from public.ui_element_overrides
  where screen_key = trim(p_screen_key)
    and enabled
    and (
      locale = coalesce(nullif(trim(p_locale), ''), 'en')
      or (
        locale = 'en'
        and coalesce(nullif(trim(p_locale), ''), 'en') <> 'en'
        and not exists (
          select 1 from public.ui_element_overrides newer
          where newer.screen_key = ui_element_overrides.screen_key
            and newer.element_key = ui_element_overrides.element_key
            and newer.enabled
            and newer.locale = coalesce(nullif(trim(p_locale), ''), 'en')
        )
      )
    );
$function$;

-- Save path accepts the new columns; old clients calling with 7 args keep
-- working because defaults cover the new params.
create or replace function public.admin_save_ui_element_override(
  p_screen_key text,
  p_element_key text,
  p_locale text default 'en',
  p_text_value text default null,
  p_placeholder_value text default null,
  p_is_hidden boolean default false,
  p_enabled boolean default true,
  p_image_url text default null,
  p_link_url text default null,
  p_color_value text default null
)
returns public.ui_element_overrides
language plpgsql
security definer
set search_path = public
as $function$
declare v_row public.ui_element_overrides;
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  insert into public.ui_element_overrides(
    screen_key, element_key, locale, text_value, placeholder_value,
    is_hidden, enabled, image_url, link_url, color_value, updated_by
  ) values (
    trim(p_screen_key), trim(p_element_key), coalesce(nullif(trim(p_locale), ''), 'en'),
    nullif(trim(p_text_value), ''), nullif(trim(p_placeholder_value), ''),
    coalesce(p_is_hidden, false), coalesce(p_enabled, true),
    nullif(trim(p_image_url), ''), nullif(trim(p_link_url), ''),
    nullif(trim(p_color_value), ''), auth.uid()
  ) on conflict (screen_key, element_key, locale) do update set
    text_value = excluded.text_value,
    placeholder_value = excluded.placeholder_value,
    is_hidden = excluded.is_hidden,
    enabled = excluded.enabled,
    image_url = excluded.image_url,
    link_url = excluded.link_url,
    color_value = excluded.color_value,
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$function$;

revoke all on function public.get_ui_element_overrides(text, text) from public;
grant execute on function public.get_ui_element_overrides(text, text) to anon, authenticated;
revoke all on function public.admin_save_ui_element_override(text, text, text, text, text, boolean, boolean, text, text, text) from public, anon;
grant execute on function public.admin_save_ui_element_override(text, text, text, text, text, boolean, boolean, text, text, text) to authenticated;

-- Seed the global branding row so Admin settings always has something to edit.
-- Values are null/empty by default: the app falls back to bundled assets.
insert into public.module_feature_configs (module_key, venue_id, metadata)
select 'branding', null, jsonb_build_object(
  'app_name', 'BookMySpace',
  'tagline', 'Find your perfect space',
  'logo_url', null,
  'logo_dark_url', null,
  'splash_url', null,
  'wordmark_first_color', '#3F51B5',
  'wordmark_rest_color', null
)
where not exists (
  select 1 from public.module_feature_configs
  where module_key = 'branding' and venue_id is null
);
