-- Security contract for the Admin Theme Customizer.
-- Run with a privileged database connection after the migration is applied.

do $$
declare
  v_schema text;
  v_rls boolean;
  v_definition text;
begin
  select n.nspname, c.relrowsecurity
    into v_schema, v_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relname = 'app_theme_configs';

  if v_schema <> 'private' or not v_rls then
    raise exception 'FAIL: app_theme_configs must be private and RLS-enabled';
  end if;

  if has_table_privilege('anon', 'private.app_theme_configs', 'SELECT')
     or has_table_privilege('authenticated', 'private.app_theme_configs', 'SELECT')
     or has_table_privilege('anon', 'private.app_theme_configs', 'UPDATE')
     or has_table_privilege('authenticated', 'private.app_theme_configs', 'UPDATE') then
    raise exception 'FAIL: public roles have direct theme table access';
  end if;

  if not has_function_privilege(
    'anon', 'public.get_published_app_theme_config()', 'EXECUTE') then
    raise exception 'FAIL: published theme read RPC is not public-readable';
  end if;
  if has_function_privilege(
    'anon', 'public.get_admin_app_theme_config()', 'EXECUTE')
     or has_function_privilege(
       'anon', 'public.save_app_theme_draft(jsonb)', 'EXECUTE')
     or has_function_privilege(
       'anon', 'public.publish_app_theme_config()', 'EXECUTE') then
    raise exception 'FAIL: anon can invoke an admin theme RPC';
  end if;

  select pg_get_functiondef(p.oid)
    into v_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'save_app_theme_draft'
    and pg_get_function_identity_arguments(p.oid) = 'p_config jsonb';
  if v_definition is null or position('is_platform_admin' in v_definition) = 0 then
    raise exception 'FAIL: draft save RPC lacks server-side admin authorization';
  end if;

  select pg_get_functiondef(p.oid)
    into v_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'publish_app_theme_config';
  if v_definition is null or position('is_platform_admin' in v_definition) = 0 then
    raise exception 'FAIL: publish RPC lacks server-side admin authorization';
  end if;

  raise notice 'PASS: theme drafts are private, published reads are scoped, and mutations require platform admin RPC authorization';
end $$;
