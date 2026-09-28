-- Phase C3: audited, locale-aware live UI text and visibility overrides.

create table if not exists public.ui_element_overrides (
  id uuid primary key default gen_random_uuid(),
  screen_key text not null,
  element_key text not null,
  locale text not null default 'en',
  text_value text,
  placeholder_value text,
  is_hidden boolean not null default false,
  enabled boolean not null default true,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (screen_key, element_key, locale),
  check (length(trim(screen_key)) between 1 and 120),
  check (length(trim(element_key)) between 1 and 160),
  check (text_value is null or length(text_value) <= 2000),
  check (placeholder_value is null or length(placeholder_value) <= 500)
);

create index if not exists ui_element_overrides_lookup_idx
  on public.ui_element_overrides(screen_key, locale, enabled);
alter table public.ui_element_overrides enable row level security;

drop policy if exists ui_element_overrides_public_read on public.ui_element_overrides;
create policy ui_element_overrides_public_read on public.ui_element_overrides
  for select to anon, authenticated using (enabled);
drop policy if exists ui_element_overrides_admin_write on public.ui_element_overrides;
create policy ui_element_overrides_admin_write on public.ui_element_overrides
  for all to authenticated
  using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
  with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

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
    'hidden', is_hidden
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

create or replace function public.admin_save_ui_element_override(
  p_screen_key text,
  p_element_key text,
  p_locale text default 'en',
  p_text_value text default null,
  p_placeholder_value text default null,
  p_is_hidden boolean default false,
  p_enabled boolean default true
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
    is_hidden, enabled, updated_by
  ) values (
    trim(p_screen_key), trim(p_element_key), coalesce(nullif(trim(p_locale), ''), 'en'),
    nullif(trim(p_text_value), ''), nullif(trim(p_placeholder_value), ''),
    coalesce(p_is_hidden, false), coalesce(p_enabled, true), auth.uid()
  ) on conflict (screen_key, element_key, locale) do update set
    text_value = excluded.text_value,
    placeholder_value = excluded.placeholder_value,
    is_hidden = excluded.is_hidden,
    enabled = excluded.enabled,
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$function$;

create or replace function public.admin_delete_ui_element_override(p_override_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $function$
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  delete from public.ui_element_overrides where id = p_override_id;
end;
$function$;

revoke all on function public.get_ui_element_overrides(text, text) from public;
revoke all on function public.admin_save_ui_element_override(text, text, text, text, text, boolean, boolean) from public, anon;
revoke all on function public.admin_delete_ui_element_override(uuid) from public, anon;
grant execute on function public.get_ui_element_overrides(text, text) to anon, authenticated;
grant execute on function public.admin_save_ui_element_override(text, text, text, text, text, boolean, boolean) to authenticated;
grant execute on function public.admin_delete_ui_element_override(uuid) to authenticated;
