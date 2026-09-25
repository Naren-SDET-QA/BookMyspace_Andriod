-- Read-only production security contract checks.
-- Run this against a deployed BookMySpace database after migrations are
-- applied. It never inserts, updates, or deletes application data.

do $$
declare
  v_rls boolean;
  v_private_category_manager text;
begin
  select c.relrowsecurity
    into v_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'venue_categories';
  if coalesce(v_rls, false) is not true then
    raise exception 'FAIL: venue_categories RLS is not enabled';
  end if;

  select pg_get_functiondef(p.oid)
    into v_private_category_manager
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.proname = 'is_category_manager'
  order by p.oid desc
  limit 1;
  if v_private_category_manager is null
     or v_private_category_manager ilike '%venue_owner%'
     or v_private_category_manager ilike '%owner_profiles%' then
    raise exception 'FAIL: global category manager is not admin-only';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'venue_categories'
      and policyname = 'categories_manager_insert'
  ) or not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'venue_categories'
      and policyname = 'categories_manager_update'
  ) or not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'venue_categories'
      and policyname = 'categories_manager_delete'
  ) then
    raise exception 'FAIL: admin-only category mutation policies are missing';
  end if;

  raise notice 'PASS: global category mutations are RLS protected for admins';
end $$;

do $$
declare
  v_rls boolean;
begin
  select c.relrowsecurity
    into v_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'venue_sections';
  if coalesce(v_rls, false) is not true then
    raise exception 'FAIL: venue_sections RLS is not enabled';
  end if;
  if has_table_privilege('anon', 'public.venue_sections', 'SELECT') then
    raise exception 'FAIL: anon can read venue section drafts';
  end if;
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'list_published_venue_sections'
  ) then
    raise exception 'FAIL: published venue section customer read path is missing';
  end if;
  if not has_function_privilege(
    'anon',
    'public.list_published_venue_sections(uuid)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: customer published venue section read path is not public';
  end if;
  raise notice 'PASS: venue section drafts are private and published reads are gated';
end $$;

do $$
begin
  if has_function_privilege(
    'authenticated',
    'public.confirm_venue_booking(uuid,uuid,text,text)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'public.confirm_venue_booking(uuid,uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: client roles can execute booking confirmation';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.confirm_venue_booking(uuid,uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service role cannot execute booking confirmation';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.approve_venue_booking(uuid,uuid,integer)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.reject_venue_booking(uuid,uuid,text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: owner approval RPC grants are missing';
  end if;
  raise notice 'PASS: booking confirmation is service-role only';
end $$;

do $$
declare
  v_receipt_unique boolean;
  v_event_unique boolean;
begin
  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'booking_receipts'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) like '%booking_id%'
  ) into v_receipt_unique;
  if not v_receipt_unique then
    raise exception 'FAIL: receipt uniqueness by booking is missing';
  end if;

  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'webhook_events'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) like '%provider%event_id%'
  ) into v_event_unique;
  if not v_event_unique then
    raise exception 'FAIL: webhook event idempotency uniqueness is missing';
  end if;
  raise notice 'PASS: receipts and webhook events are idempotent';
end $$;
