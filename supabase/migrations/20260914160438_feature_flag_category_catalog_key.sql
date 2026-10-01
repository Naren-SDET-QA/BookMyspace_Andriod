-- Allowlist the `category_catalog` CMS document key.
--
-- Batch 1 adds lib/features/cms/domain/catalog_content.dart, the
-- backend-editable mirror of the hardcoded discovery taxonomy in
-- home_category_catalog.dart. It serializes into feature_flags.config under
-- the key `category_catalog`, the same storage home_appearance and nav_tabs
-- already use.
--
-- Added now, ahead of any writer, specifically to avoid repeating the defect
-- fixed in 20260914155335: there, three keys shipped in the Flutter manifests
-- while the validator allowlist was never extended, so every admin save was
-- rejected with `unsupported_module` and nobody noticed because the Dart
-- tests run without a database.
--
-- No row is seeded. An absent row resolves to CatalogContent.defaults, which
-- is generated from home_category_catalog.dart, so discovery renders exactly
-- as it does today until an admin saves something. Batch 1 changes nothing a
-- customer can see.

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
    -- CMS composition documents. Not feature toggles: admin-authored content
    -- documents that share this table's (key, enabled, platforms, config)
    -- shape. Each falls back to shipped Dart defaults when absent, disabled
    -- or malformed, so a rejected or missing row can never leave the customer
    -- app without a Home, a bottom bar or a discovery catalogue.
    'home_appearance', 'nav_tabs', 'category_catalog',
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
  -- Structural checks only. The client drops unknown entries and re-adds any
  -- missing one from its shipped defaults, so pinning the per-entry schema
  -- here would duplicate that logic and have to change with every new type.
  if new.config ? 'blocks' and jsonb_typeof(new.config->'blocks') <> 'array' then
    raise exception 'invalid_home_blocks';
  end if;
  if new.config ? 'tabs' and jsonb_typeof(new.config->'tabs') <> 'array' then
    raise exception 'invalid_nav_tabs';
  end if;
  if new.config ? 'facility_types' and
     jsonb_typeof(new.config->'facility_types') <> 'array' then
    raise exception 'invalid_facility_types';
  end if;
  if new.config ? 'show_on_home' and
     jsonb_typeof(new.config->'show_on_home') <> 'boolean' then
    raise exception 'invalid_show_on_home';
  end if;
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

revoke all on function public.validate_feature_flag_config() from public, anon, authenticated;

comment on function public.validate_feature_flag_config() is
  'Validates public.feature_flags writes. Allowlist covers optional modules plus the CMS content documents home_appearance, nav_tabs and category_catalog. Each such document falls back to shipped Dart defaults when absent, disabled or malformed.';
