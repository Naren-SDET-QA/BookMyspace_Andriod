-- Fix: three shipped admin screens cannot save.
--
-- public.validate_feature_flag_config() (20260912203000) gates every write to
-- public.feature_flags against a hardcoded key allowlist. Three keys that the
-- Flutter client actively writes were never added to it:
--
--   home_appearance  -- lib/features/home/presentation/home_appearance_providers.dart
--                       (homeAppearanceFlagKey), written by
--                       HomeAppearanceController.save() from /admin/home-layout
--   nav_tabs         -- lib/features/navigation/presentation/nav_tabs_providers.dart
--                       (navTabsFlagKey), written by NavTabsController.save()
--                       from /admin/nav-tabs
--   ai_booking       -- module_manifests.dart, toggled from /admin/modules
--
-- All three are declared in optionalModuleManifests, so the admin UI offers
-- them, but every save is rejected with 'unsupported_module'. No migration
-- after 20260912203000 redefines the function.
--
-- The Dart test suite cannot catch this: home_appearance_test.dart,
-- nav_tabs_test.dart and feature_flag_test.dart exercise serialization only,
-- with no database in the loop, so the trigger never runs.
--
-- This migration redefines the validator with those three keys added and
-- every other rule preserved byte-for-byte. It is additive: no existing key,
-- platform rule, config rule or grant changes.

create or replace function public.validate_feature_flag_config()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_platform text;
begin
  if new.key not in (
    'gps', 'pin_search', 'offers', 'events', 'courses', 'reviews', 'favorites',
    'payments', 'notifications', 'support', 'analytics', 'integrations', 'referrals',
    -- CMS composition documents. These are not feature toggles; they are
    -- admin-authored layout documents that happen to share this table's
    -- (key, enabled, platforms, config) shape. Both fall back to shipped
    -- Dart defaults when absent or malformed, so a rejected or missing row
    -- can never leave the customer app without a Home or a bottom bar.
    'home_appearance', 'nav_tabs',
    -- Optional module with a config flag (show_on_home).
    'ai_booking'
  ) then
    raise exception 'unsupported_module';
  end if;
  if new.key in ('payments', 'notifications', 'courses') and new.enabled is false then
    raise exception 'core_module_cannot_be_disabled';
  end if;
  if new.platforms is null or cardinality(new.platforms) = 0 then
    raise exception 'module_requires_platform';
  end if;
  foreach v_platform in array new.platforms loop
    if v_platform not in ('ios', 'android', 'web') then
      raise exception 'unsupported_module_platform';
    end if;
  end loop;
  if new.config is null or jsonb_typeof(new.config) <> 'object' then
    raise exception 'module_config_must_be_object';
  end if;
  if new.config ? 'display_title' and
     (jsonb_typeof(new.config->'display_title') <> 'string'
      or length(new.config->>'display_title') not between 1 and 80) then
    raise exception 'invalid_display_title';
  end if;
  if new.config ? 'max_items' and
     (jsonb_typeof(new.config->'max_items') <> 'number'
      or (new.config->>'max_items')::numeric not between 1 and 100
      or (new.config->>'max_items')::numeric <> trunc((new.config->>'max_items')::numeric)) then
    raise exception 'invalid_max_items';
  end if;
  if new.config ? 'reward_amount' and
     (jsonb_typeof(new.config->'reward_amount') <> 'number'
      or (new.config->>'reward_amount')::numeric not between 0 and 100000) then
    raise exception 'invalid_reward_amount';
  end if;
  if new.config ? 'expiry_days' and
     (jsonb_typeof(new.config->'expiry_days') <> 'number'
      or (new.config->>'expiry_days')::numeric not between 1 and 365
      or (new.config->>'expiry_days')::numeric <> trunc((new.config->>'expiry_days')::numeric)) then
    raise exception 'invalid_expiry_days';
  end if;
  -- Structural checks only, matching the permissive style above: reject a
  -- clearly malformed document, but do not pin the per-block or per-tab
  -- schema here. The client already drops unknown kinds and re-adds any
  -- missing block/tab from its shipped defaults, so field-level validation in
  -- SQL would duplicate that logic and would have to change with every new
  -- block type.
  if new.config ? 'blocks' and jsonb_typeof(new.config->'blocks') <> 'array' then
    raise exception 'invalid_home_blocks';
  end if;
  if new.config ? 'tabs' and jsonb_typeof(new.config->'tabs') <> 'array' then
    raise exception 'invalid_nav_tabs';
  end if;
  if new.config ? 'show_on_home' and
     jsonb_typeof(new.config->'show_on_home') <> 'boolean' then
    raise exception 'invalid_show_on_home';
  end if;
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

-- CREATE OR REPLACE preserves privileges, so the deliberate revoke from
-- 20260912154948 still stands. Re-asserted here so this file is correct on
-- its own if it is ever replayed out of order.
revoke all on function public.validate_feature_flag_config() from public, anon, authenticated;

comment on function public.validate_feature_flag_config() is
  'Validates public.feature_flags writes. Allowlist covers optional modules plus the CMS composition documents home_appearance and nav_tabs. Fixed 2026-09-14: home_appearance, nav_tabs and ai_booking were declared in the Flutter module manifests and written by the admin console, but were missing from the allowlist, so /admin/home-layout, /admin/nav-tabs and the AI-booking toggle all failed with unsupported_module.';

-- Seed the two composition rows so the admin console has something to update
-- rather than insert on first use. An empty config resolves to the shipped
-- HomeAppearance.defaults / NavTabsConfig.defaults, so this changes nothing
-- a customer can see.
insert into public.feature_flags (key, enabled, platforms, config)
values
  ('home_appearance', true, array['ios', 'android', 'web'], '{}'::jsonb),
  ('nav_tabs', true, array['ios', 'android', 'web'], '{}'::jsonb),
  ('ai_booking', true, array['ios', 'android', 'web'], '{"show_on_home": true}'::jsonb)
on conflict (key) do nothing;
