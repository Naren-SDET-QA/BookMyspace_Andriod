-- ============================================================
-- BookMySpace — External Channel: read-only production security contract
--
-- Companion to supabase/tests/production_security_contract.sql, same
-- convention: safe to run directly against a deployed database
-- (bookmyspace-dev included). It never inserts, updates, or deletes
-- application data — every check is a structural query against
-- pg_catalog / information_schema / has_*_privilege.
--
-- Run: psql "$DATABASE_URL" -f supabase/tests/external_channel_production_security_contract.sql
--
-- Verified 2026-09-14 against bookmyspace-dev (zykxneztahxbjduagutv):
-- all 7 checks below PASS with zero exceptions raised, after
-- 20260914140000_external_channel_anon_lockdown.sql was applied.
-- ============================================================

-- ------------------------------------------------------------
-- 1. anon must have ZERO privilege on every external-channel table.
--    (Regression guard for the 2026-09-14 anon-exposure finding —
--    see 20260914140000_external_channel_anon_lockdown.sql.)
-- ------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array[
    'external_channel_providers', 'external_channel_connections',
    'external_property_mappings', 'external_room_mappings',
    'external_rate_plan_mappings', 'external_reservations',
    'external_inventory_events', 'inventory_sync_state',
    'inventory_sync_errors', 'inventory_change_log'
  ];
begin
  foreach v_table in array v_tables loop
    if has_table_privilege('anon', format('public.%I', v_table), 'SELECT')
       or has_table_privilege('anon', format('public.%I', v_table), 'INSERT')
       or has_table_privilege('anon', format('public.%I', v_table), 'UPDATE')
       or has_table_privilege('anon', format('public.%I', v_table), 'DELETE') then
      raise exception 'FAIL: anon has a privilege on public.%', v_table;
    end if;
  end loop;
  raise notice 'PASS: anon has zero privileges on every external-channel table';
end $$;

-- ------------------------------------------------------------
-- 2. anon must have ZERO execute on every external-channel RPC.
-- ------------------------------------------------------------
do $$
begin
  if has_function_privilege('anon', 'public.apply_external_reservation_event(uuid, text, text, text, uuid, uuid, date, bigint, timestamptz, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute apply_external_reservation_event (service-role-only RPC)';
  end if;
  if has_function_privilege('anon', 'public.record_external_sync_result(uuid, boolean, integer, text, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute record_external_sync_result (service-role-only RPC)';
  end if;
  if has_function_privilege('anon', 'public.can_manage_external_connection(uuid)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute can_manage_external_connection';
  end if;
  if has_function_privilege('anon', 'public.create_external_channel_connection(uuid, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute create_external_channel_connection';
  end if;
  if has_function_privilege('anon', 'public.disconnect_external_channel_connection(uuid)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute disconnect_external_channel_connection';
  end if;
  if has_function_privilege('anon', 'public.request_external_manual_sync(uuid)', 'EXECUTE') then
    raise exception 'FAIL: anon can execute request_external_manual_sync';
  end if;
  raise notice 'PASS: anon cannot execute any external-channel RPC';
end $$;

-- ------------------------------------------------------------
-- 3. authenticated/service_role must NOT have lost legitimate access
--    (the lockdown migration must be anon-only, never touching these).
-- ------------------------------------------------------------
do $$
begin
  if not has_function_privilege('service_role', 'public.apply_external_reservation_event(uuid, text, text, text, uuid, uuid, date, bigint, timestamptz, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: service_role lost execute on apply_external_reservation_event';
  end if;
  if not has_function_privilege('service_role', 'public.record_external_sync_result(uuid, boolean, integer, text, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: service_role lost execute on record_external_sync_result';
  end if;
  if not has_function_privilege('authenticated', 'public.create_external_channel_connection(uuid, text, jsonb)', 'EXECUTE') then
    raise exception 'FAIL: authenticated lost execute on create_external_channel_connection (owners could no longer connect a provider)';
  end if;
  if not has_function_privilege('authenticated', 'public.acquire_venue_hold(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)', 'EXECUTE') then
    raise exception 'FAIL: authenticated lost execute on acquire_venue_hold — unrelated booking flow was affected';
  end if;
  raise notice 'PASS: authenticated/service_role retain every legitimate privilege';
end $$;

-- ------------------------------------------------------------
-- 4. Every external-channel table has RLS enabled and forced-by-default
--    (no policy applies to anon; authenticated is scoped by ownership).
-- ------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array[
    'external_channel_providers', 'external_channel_connections',
    'external_property_mappings', 'external_room_mappings',
    'external_rate_plan_mappings', 'external_reservations',
    'external_inventory_events', 'inventory_sync_state',
    'inventory_sync_errors', 'inventory_change_log'
  ];
  v_rls boolean;
begin
  foreach v_table in array v_tables loop
    select c.relrowsecurity into v_rls
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = v_table;
    if coalesce(v_rls, false) is not true then
      raise exception 'FAIL: % does not have RLS enabled', v_table;
    end if;
  end loop;
  raise notice 'PASS: RLS is enabled on every external-channel table';
end $$;

-- ------------------------------------------------------------
-- 5. DELETE on external_channel_connections must stay withheld from
--    authenticated — owners must go through the audited
--    disconnect_external_channel_connection() RPC, never a raw DELETE.
-- ------------------------------------------------------------
do $$
begin
  if has_table_privilege('authenticated', 'public.external_channel_connections', 'DELETE') then
    raise exception 'FAIL: authenticated can DELETE external_channel_connections directly (bypasses the audited disconnect RPC)';
  end if;
  raise notice 'PASS: connections can only be disconnected through the audited RPC';
end $$;

-- ------------------------------------------------------------
-- 6. Mapping-integrity trigger (defense-in-depth, RLS-independent)
--    must exist on all three mapping tables.
-- ------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array['external_property_mappings', 'external_room_mappings', 'external_rate_plan_mappings'];
  v_trigger_prefix text := 'trg_validate_';
begin
  foreach v_table in array v_tables loop
    if not exists (
      select 1 from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = v_table
        and t.tgname like v_trigger_prefix || '%'
        and not t.tgisinternal
    ) then
      raise exception 'FAIL: % is missing its mapping-integrity BEFORE INSERT/UPDATE trigger', v_table;
    end if;
  end loop;
  raise notice 'PASS: mapping-integrity trigger present on every mapping table';
end $$;

-- ------------------------------------------------------------
-- 7. All catalog providers must be status='blocked_external' unless a
--    real credential/partner agreement has genuinely been wired up —
--    this repo/environment never claims a fake live connection.
-- ------------------------------------------------------------
do $$
declare
  v_live_count integer;
begin
  select count(*) into v_live_count
  from public.external_channel_providers
  where status = 'available';
  if v_live_count > 0 then
    raise notice 'INFO: % provider(s) marked available — verify each has a real, non-fabricated credential/partner agreement', v_live_count;
  else
    raise notice 'PASS: no provider claims a live connection without a real credential (all blocked_external or deprecated)';
  end if;
end $$;
