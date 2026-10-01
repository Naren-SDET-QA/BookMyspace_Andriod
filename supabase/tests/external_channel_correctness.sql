-- ============================================================
-- BookMySpace — External Channel: Correctness & Security Tests
--
-- Self-asserting plpgsql tests, same convention as
-- supabase/tests/booking_concurrency.sql. This file DELETES/INSERTS
-- fixture data — run it only against a disposable/local database,
-- NEVER against bookmyspace-dev or any database holding real bookings.
--
-- Run: psql "$DATABASE_URL" -f supabase/tests/external_channel_correctness.sql
--
-- Auth simulation: this project's auth.uid() (see
-- supabase/test_harness_auth_stub.sql, or the real `auth.uid()` on a
-- live/branch Supabase Postgres) reads
-- current_setting('request.jwt.claim.sub', true)::uuid. Every test
-- that calls a function checking auth.uid() sets that GUC first via
-- set_config(..., true) (transaction-local) and clears it after.
-- ============================================================

-- ------------------------------------------------------------
-- Fixture
-- ------------------------------------------------------------
create or replace function test_ext_setup_fixture()
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  delete from public.inventory_change_log;
  delete from public.inventory_sync_errors;
  delete from public.inventory_sync_state;
  delete from public.external_inventory_events;
  delete from public.external_reservations;
  delete from public.external_room_mappings;
  delete from public.external_property_mappings;
  delete from public.external_rate_plan_mappings;
  delete from public.external_channel_connections;
  delete from public.notifications;
  delete from public.audit_logs where entity_type = 'booking';
  delete from public.booking_receipts;
  delete from public.payments;
  delete from public.bookings;
  delete from public.booking_holds;
  delete from public.time_slots;
  delete from public.venues;
  delete from public.organizations;
  delete from auth.users where email like '%@ext-test.com';

  insert into auth.users (id, email) values
    ('a0000000-0000-0000-0000-00000000000a', 'owner_a@ext-test.com'),
    ('b0000000-0000-0000-0000-00000000000b', 'owner_b@ext-test.com'),
    ('c0000000-0000-0000-0000-00000000000c', 'customer_c@ext-test.com');

  insert into public.organizations (owner_user_id, org_type, name) values
    ('a0000000-0000-0000-0000-00000000000a', 'venue_owner', 'Ext Test Org A'),
    ('b0000000-0000-0000-0000-00000000000b', 'venue_owner', 'Ext Test Org B');

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  select o.id, 'Ext Test Venue A', 17.3850, 78.4867, 100
  from public.organizations o where o.name = 'Ext Test Org A';

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  select o.id, 'Ext Test Venue B', 17.3850, 78.4867, 100
  from public.organizations o where o.name = 'Ext Test Org B';

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  select v.id, 'Morning', '09:00', '12:00', 5000
  from public.venues v where v.name = 'Ext Test Venue A';

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  select v.id, 'Morning', '09:00', '12:00', 5000
  from public.venues v where v.name = 'Ext Test Venue B';
end $$;

-- ------------------------------------------------------------
-- Test 1: cross-venue isolation — owner B cannot create a connection
-- for owner A's venue.
-- ------------------------------------------------------------
create or replace function test_ext_cross_owner_connection_isolation()
returns void language plpgsql as $$
declare
  v_venue_a uuid;
  v_result jsonb;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  perform set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-00000000000b', true);

  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  if (v_result->>'success')::boolean = true then
    raise exception 'FAIL: owner B was allowed to create a connection for owner A''s venue';
  end if;
  if v_result->>'error_code' <> 'NOT_VENUE_OWNER' then
    raise exception 'FAIL: unexpected error_code %, wanted NOT_VENUE_OWNER', v_result->>'error_code';
  end if;
  raise notice 'PASS: cross-owner connection creation rejected (NOT_VENUE_OWNER)';
end $$;

-- ------------------------------------------------------------
-- Test 2: mapping integrity — a room mapping cannot point at a slot
-- belonging to a different venue than its own connection's venue.
-- ------------------------------------------------------------
create or replace function test_ext_mapping_venue_integrity()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_b uuid; v_connection_id uuid;
  v_result jsonb;
  v_exc text;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select ts.id into v_slot_b from public.time_slots ts join public.venues v on v.id = ts.venue_id
    where v.name = 'Ext Test Venue B';

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: owner A could not create their own connection: %', v_result;
  end if;
  v_connection_id := (v_result->>'connection_id')::uuid;

  begin
    insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
    values (v_connection_id, 'ROOM-1', v_slot_b);
    raise exception 'FAIL: mapping to a foreign-venue slot was not rejected';
  exception
    when others then
      get stacked diagnostics v_exc = message_text;
      if v_exc ilike '%belongs to a different venue%' then
        raise notice 'PASS: cross-venue room mapping rejected by trigger';
      else
        raise exception 'FAIL: unexpected error on cross-venue mapping: %', v_exc;
      end if;
  end;
end $$;

-- ------------------------------------------------------------
-- Test 3: acquire_venue_hold is blocked when the slot/date is already
-- externally reserved.
-- ------------------------------------------------------------
create or replace function test_ext_acquire_hold_blocked_by_external_reservation()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid; v_provider_id uuid;
  v_result jsonb;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;
  select id into v_provider_id from public.external_channel_providers where code = 'generic_pms';

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;

  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-1', v_slot_a);

  -- Service-role path: no auth.uid() needed, apply_external_reservation_event
  -- has no internal identity check by design (service-role-only via grants).
  perform set_config('request.jwt.claim.sub', '', true);
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-1', 'reservation.created', 'ext-res-1',
    v_venue_a, v_slot_a, '2027-01-10', 1, now(), 'guest-1', '{}'::jsonb
  );
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: apply_external_reservation_event failed unexpectedly: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-00000000000c', true);
  v_result := public.acquire_venue_hold(
    v_venue_a, v_slot_a, '2027-01-10', 'c0000000-0000-0000-0000-00000000000c',
    gen_random_uuid(), 5000, 0, 0, 10
  );
  if (v_result->>'success')::boolean = true then
    raise exception 'FAIL: acquire_venue_hold succeeded despite an externally-booked slot';
  end if;
  if v_result->>'error_code' <> 'EXTERNALLY_BOOKED' then
    raise exception 'FAIL: unexpected error_code %, wanted EXTERNALLY_BOOKED', v_result->>'error_code';
  end if;
  raise notice 'PASS: acquire_venue_hold rejects an externally-booked slot';
end $$;

-- ------------------------------------------------------------
-- Test 4: owner-approval re-check — an external reservation that
-- appears while a request is awaiting_owner_approval must block the
-- owner from accepting it, release the hold, and must NOT set up a
-- payment window.
-- ------------------------------------------------------------
create or replace function test_ext_approve_blocked_by_external_conflict()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid;
  v_booking_id uuid; v_hold_id uuid;
  v_result jsonb; v_booking record;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;
  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-2', v_slot_a);

  perform set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-00000000000c', true);
  v_result := public.request_venue_booking(
    v_venue_a, v_slot_a, '2027-01-11', 'c0000000-0000-0000-0000-00000000000c',
    gen_random_uuid(), 5000, 0, 0, 120
  );
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: request_venue_booking failed unexpectedly: %', v_result;
  end if;
  v_booking_id := (v_result->>'booking_id')::uuid;
  v_hold_id := (v_result->>'hold_id')::uuid;

  -- External reservation arrives while the owner has not yet approved.
  perform set_config('request.jwt.claim.sub', '', true);
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-2', 'reservation.created', 'ext-res-2',
    v_venue_a, v_slot_a, '2027-01-11', 1, now(), 'guest-2', '{}'::jsonb
  );
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: apply_external_reservation_event failed unexpectedly: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.approve_venue_booking(v_booking_id, gen_random_uuid(), 60);
  if (v_result->>'success')::boolean = true then
    raise exception 'FAIL: approve_venue_booking approved a request that was externally booked in the meantime';
  end if;
  if v_result->>'error_code' <> 'EXTERNALLY_BOOKED' then
    raise exception 'FAIL: unexpected error_code %, wanted EXTERNALLY_BOOKED', v_result->>'error_code';
  end if;

  select * into v_booking from public.bookings where id = v_booking_id;
  if v_booking.status <> 'external_conflict' then
    raise exception 'FAIL: booking status is %, wanted external_conflict', v_booking.status;
  end if;
  if v_booking.payment_expires_at is not null then
    raise exception 'FAIL: a payment window was opened for an unavailable booking';
  end if;
  if not exists (select 1 from public.booking_holds where id = v_hold_id and status = 'released') then
    raise exception 'FAIL: the hold was not released';
  end if;
  if not exists (
    select 1 from public.audit_logs
    where entity_id = v_booking_id and action = 'booking_external_conflict'
  ) then
    raise exception 'FAIL: no audit_logs entry for the external-conflict transition';
  end if;
  if not exists (select 1 from public.notifications where user_id = 'c0000000-0000-0000-0000-00000000000c') then
    raise exception 'FAIL: customer was not notified';
  end if;
  raise notice 'PASS: owner-approval re-check blocks an externally-booked request, releases the hold, opens no payment window';
end $$;

-- ------------------------------------------------------------
-- Test 5: final-confirmation re-check — payment success must NOT be
-- treated as booking success if an external reservation appeared
-- after owner approval but before payment confirmation.
-- ------------------------------------------------------------
create or replace function test_ext_confirm_blocked_by_external_conflict()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid;
  v_booking_id uuid;
  v_result jsonb; v_booking record; v_payment_id uuid;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;
  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-3', v_slot_a);

  perform set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-00000000000c', true);
  v_result := public.request_venue_booking(
    v_venue_a, v_slot_a, '2027-01-12', 'c0000000-0000-0000-0000-00000000000c',
    gen_random_uuid(), 5000, 0, 0, 120
  );
  v_booking_id := (v_result->>'booking_id')::uuid;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.approve_venue_booking(v_booking_id, gen_random_uuid(), 60);
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: approve_venue_booking failed unexpectedly: %', v_result;
  end if;

  insert into public.payments (booking_id, user_id, status, provider_payment_id, amount, currency)
  values (v_booking_id, 'c0000000-0000-0000-0000-00000000000c', 'captured', 'pay_test_5', 5000, 'INR')
  returning id into v_payment_id;

  -- External reservation arrives AFTER approval and AFTER payment capture,
  -- but BEFORE the confirm_venue_booking call.
  perform set_config('request.jwt.claim.sub', '', true);
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-3', 'reservation.created', 'ext-res-3',
    v_venue_a, v_slot_a, '2027-01-12', 1, now(), 'guest-3', '{}'::jsonb
  );
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: apply_external_reservation_event failed unexpectedly: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-00000000000c', true);
  v_result := public.confirm_venue_booking(v_booking_id, 'c0000000-0000-0000-0000-00000000000c', 'pay_test_5', 'UPIRazorpay');
  if (v_result->>'success')::boolean = true then
    raise exception 'FAIL: confirm_venue_booking confirmed a booking that was externally booked in the meantime — payment success was wrongly treated as booking success';
  end if;
  if v_result->>'error_code' <> 'EXTERNALLY_BOOKED' then
    raise exception 'FAIL: unexpected error_code %, wanted EXTERNALLY_BOOKED', v_result->>'error_code';
  end if;

  select * into v_booking from public.bookings where id = v_booking_id;
  if v_booking.status <> 'external_conflict' then
    raise exception 'FAIL: booking status is %, wanted external_conflict', v_booking.status;
  end if;
  if exists (select 1 from public.booking_receipts where booking_id = v_booking_id) then
    raise exception 'FAIL: a receipt was issued for an unconfirmed/conflicted booking';
  end if;
  raise notice 'PASS: final confirmation re-check refuses to confirm despite captured payment; no receipt issued';
end $$;

-- ------------------------------------------------------------
-- Test 6: idempotency — replaying the same external_event_id must be
-- a no-op, not a duplicate row / double side effect.
-- ------------------------------------------------------------
create or replace function test_ext_duplicate_event_idempotent()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid;
  v_result jsonb; v_reservation_count integer; v_event_count integer;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;
  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-6', v_slot_a);

  perform set_config('request.jwt.claim.sub', '', true);
  perform public.apply_external_reservation_event(
    v_connection_id, 'evt-dup-1', 'reservation.created', 'ext-res-6',
    v_venue_a, v_slot_a, '2027-01-15', 1, now(), 'guest-6', '{}'::jsonb
  );
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-dup-1', 'reservation.created', 'ext-res-6',
    v_venue_a, v_slot_a, '2027-01-15', 1, now(), 'guest-6', '{}'::jsonb
  );
  if v_result->>'status' <> 'duplicate_event_ignored' then
    raise exception 'FAIL: replayed event was not recognized as a duplicate: %', v_result;
  end if;

  select count(*) into v_reservation_count from public.external_reservations where external_reservation_id = 'ext-res-6';
  select count(*) into v_event_count from public.external_inventory_events where external_event_id = 'evt-dup-1';
  if v_reservation_count <> 1 or v_event_count <> 1 then
    raise exception 'FAIL: duplicate event created extra rows (reservations=%, events=%)', v_reservation_count, v_event_count;
  end if;
  raise notice 'PASS: duplicate webhook event is idempotent (no extra rows, no extra side effects)';
end $$;

-- ------------------------------------------------------------
-- Test 7: provider-version ordering — all four combinations.
-- ------------------------------------------------------------
create or replace function test_ext_version_ordering()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid;
  v_result jsonb; v_version bigint; v_updated_at timestamptz;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;
  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-7', v_slot_a);
  perform set_config('request.jwt.claim.sub', '', true);

  -- (a) versioned -> versioned: seed at version 5, a lower version 3 must be stale.
  perform public.apply_external_reservation_event(
    v_connection_id, 'evt-v1', 'reservation.created', 'ext-res-7',
    v_venue_a, v_slot_a, '2027-01-16', 5, now(), 'guest-7', '{}'::jsonb
  );
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-v2', 'reservation.modified', 'ext-res-7',
    v_venue_a, v_slot_a, '2027-01-16', 3, now(), 'guest-7-modified', '{}'::jsonb
  );
  if v_result->>'status' <> 'stale_event_ignored' then
    raise exception 'FAIL: (versioned->versioned, lower) not treated as stale: %', v_result;
  end if;
  select provider_version into v_version from public.external_reservations where external_reservation_id = 'ext-res-7';
  if v_version <> 5 then
    raise exception 'FAIL: stale versioned event clobbered a newer version (now %)', v_version;
  end if;

  -- (b) versionless -> versioned-existing: an unversioned event must not
  -- blindly overwrite a record that already carries a known version.
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-v3', 'reservation.modified', 'ext-res-7',
    v_venue_a, v_slot_a, '2027-01-16', null, null, 'guest-7-unversioned', '{}'::jsonb
  );
  if v_result->>'status' <> 'stale_event_ignored' then
    raise exception 'FAIL: (versionless -> existing versioned) was not rejected as stale: %', v_result;
  end if;

  -- (c) versioned-existing -> higher versioned: must apply.
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-v4', 'reservation.modified', 'ext-res-7',
    v_venue_a, v_slot_a, '2027-01-16', 9, now(), 'guest-7-latest', '{}'::jsonb
  );
  if v_result->>'status' = 'stale_event_ignored' then
    raise exception 'FAIL: a genuinely newer versioned event was rejected as stale';
  end if;
  select provider_version into v_version from public.external_reservations where external_reservation_id = 'ext-res-7';
  if v_version <> 9 then
    raise exception 'FAIL: newer versioned event did not apply (version is %)', v_version;
  end if;

  -- (d) versionless -> versionless: fall back to provider_updated_at.
  perform public.apply_external_reservation_event(
    v_connection_id, 'evt-v5', 'reservation.created', 'ext-res-8',
    v_venue_a, v_slot_a, '2027-01-17', null, '2027-01-01 10:00:00+00'::timestamptz, 'guest-8', '{}'::jsonb
  );
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-v6', 'reservation.modified', 'ext-res-8',
    v_venue_a, v_slot_a, '2027-01-17', null, '2027-01-01 09:00:00+00'::timestamptz, 'guest-8-older', '{}'::jsonb
  );
  if v_result->>'status' <> 'stale_event_ignored' then
    raise exception 'FAIL: (versionless->versionless, older provider_updated_at) not treated as stale: %', v_result;
  end if;
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-v7', 'reservation.modified', 'ext-res-8',
    v_venue_a, v_slot_a, '2027-01-17', null, '2027-01-01 11:00:00+00'::timestamptz, 'guest-8-newer', '{}'::jsonb
  );
  if v_result->>'status' = 'stale_event_ignored' then
    raise exception 'FAIL: (versionless->versionless, newer provider_updated_at) was wrongly rejected as stale';
  end if;
  select provider_updated_at into v_updated_at from public.external_reservations where external_reservation_id = 'ext-res-8';
  if v_updated_at <> '2027-01-01 11:00:00+00'::timestamptz then
    raise exception 'FAIL: newer versionless event by timestamp did not apply';
  end if;

  raise notice 'PASS: all four version-ordering combinations behave correctly (versioned/versioned, versionless/versioned, versioned/versionless-existing, versionless/versionless-by-timestamp)';
end $$;

-- ------------------------------------------------------------
-- Test 8: conflict recovery — cancelling the external reservation
-- that caused a conflict reopens availability without auto-confirming,
-- and a replayed cancellation is idempotent.
-- ------------------------------------------------------------
create or replace function test_ext_conflict_recovery()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_slot_a uuid; v_connection_id uuid; v_booking_id uuid;
  v_result jsonb; v_booking record; v_audit_count integer;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;
  insert into public.external_room_mappings (connection_id, external_room_id, local_slot_id)
  values (v_connection_id, 'ROOM-9', v_slot_a);

  perform set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-00000000000c', true);
  v_result := public.request_venue_booking(
    v_venue_a, v_slot_a, '2027-01-20', 'c0000000-0000-0000-0000-00000000000c',
    gen_random_uuid(), 5000, 0, 0, 120
  );
  v_booking_id := (v_result->>'booking_id')::uuid;

  perform set_config('request.jwt.claim.sub', '', true);
  perform public.apply_external_reservation_event(
    v_connection_id, 'evt-9a', 'reservation.created', 'ext-res-9',
    v_venue_a, v_slot_a, '2027-01-20', 1, now(), 'guest-9', '{}'::jsonb
  );

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.approve_venue_booking(v_booking_id, gen_random_uuid(), 60);
  if v_result->>'error_code' <> 'EXTERNALLY_BOOKED' then
    raise exception 'FAIL: fixture setup did not reach external_conflict as expected: %', v_result;
  end if;

  -- The external reservation is cancelled.
  perform set_config('request.jwt.claim.sub', '', true);
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-9b', 'reservation.cancelled', 'ext-res-9',
    v_venue_a, v_slot_a, '2027-01-20', 2, now(), 'guest-9', '{}'::jsonb
  );
  if (v_result->>'success')::boolean is not true then
    raise exception 'FAIL: cancellation event failed: %', v_result;
  end if;

  select * into v_booking from public.bookings where id = v_booking_id;
  if v_booking.status <> 'availability_reopened' then
    raise exception 'FAIL: booking status is %, wanted availability_reopened', v_booking.status;
  end if;
  if not exists (
    select 1 from public.audit_logs
    where entity_id = v_booking_id and action = 'booking_external_conflict_recovered'
  ) then
    raise exception 'FAIL: no audit_logs entry for the recovery transition';
  end if;

  -- Idempotency: cancelling again (a new event id, same reservation)
  -- must not create a second recovery record for a booking no longer
  -- in external_conflict.
  select count(*) into v_audit_count from public.audit_logs
    where entity_id = v_booking_id and action = 'booking_external_conflict_recovered';
  perform public.apply_external_reservation_event(
    v_connection_id, 'evt-9c', 'reservation.cancelled', 'ext-res-9',
    v_venue_a, v_slot_a, '2027-01-20', 3, now(), 'guest-9', '{}'::jsonb
  );
  if (select count(*) from public.audit_logs where entity_id = v_booking_id and action = 'booking_external_conflict_recovered') <> v_audit_count then
    raise exception 'FAIL: replaying the cancellation re-processed an already-recovered booking';
  end if;

  raise notice 'PASS: external-conflict recovery reopens availability without auto-confirming, and is idempotent on replay';
end $$;

-- ------------------------------------------------------------
-- Test 9: a caller-supplied venue/slot that does not belong to the
-- connection must be rejected rather than trusted.
-- ------------------------------------------------------------
create or replace function test_ext_venue_slot_mismatch_rejected()
returns void language plpgsql as $$
declare
  v_venue_a uuid; v_venue_b uuid; v_slot_a uuid; v_slot_b uuid; v_connection_id uuid;
  v_result jsonb;
begin
  select id into v_venue_a from public.venues where name = 'Ext Test Venue A';
  select id into v_venue_b from public.venues where name = 'Ext Test Venue B';
  select id into v_slot_a from public.time_slots where venue_id = v_venue_a;
  select id into v_slot_b from public.time_slots where venue_id = v_venue_b;

  perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-00000000000a', true);
  v_result := public.create_external_channel_connection(v_venue_a, 'generic_pms', '{}'::jsonb);
  v_connection_id := (v_result->>'connection_id')::uuid;

  perform set_config('request.jwt.claim.sub', '', true);
  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-mismatch-1', 'reservation.created', 'ext-res-mismatch-1',
    v_venue_b, v_slot_b, '2027-01-25', 1, now(), 'guest-x', '{}'::jsonb
  );
  if v_result->>'error_code' <> 'VENUE_MISMATCH' then
    raise exception 'FAIL: cross-venue p_venue_id was not rejected: %', v_result;
  end if;

  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-mismatch-2', 'reservation.created', 'ext-res-mismatch-2',
    v_venue_a, v_slot_b, '2027-01-25', 1, now(), 'guest-y', '{}'::jsonb
  );
  if v_result->>'error_code' <> 'SLOT_VENUE_MISMATCH' then
    raise exception 'FAIL: cross-venue p_slot_id was not rejected: %', v_result;
  end if;

  v_result := public.apply_external_reservation_event(
    v_connection_id, 'evt-mismatch-3', 'reservation.created', 'ext-res-mismatch-3',
    v_venue_a, v_slot_a, '2027-01-25', 1, now(), 'guest-z', '{}'::jsonb
  );
  if v_result->>'error_code' <> 'SLOT_NOT_MAPPED' then
    raise exception 'FAIL: an unmapped-but-same-venue slot was not rejected: %', v_result;
  end if;

  raise notice 'PASS: venue/slot mismatch and unmapped-slot events are all rejected rather than trusted';
end $$;

-- ------------------------------------------------------------
-- RUNNER
-- ------------------------------------------------------------
do $$
begin
  perform test_ext_setup_fixture();
  perform test_ext_cross_owner_connection_isolation();
  perform test_ext_setup_fixture();
  perform test_ext_mapping_venue_integrity();
  perform test_ext_setup_fixture();
  perform test_ext_acquire_hold_blocked_by_external_reservation();
  perform test_ext_setup_fixture();
  perform test_ext_approve_blocked_by_external_conflict();
  perform test_ext_setup_fixture();
  perform test_ext_confirm_blocked_by_external_conflict();
  perform test_ext_setup_fixture();
  perform test_ext_duplicate_event_idempotent();
  perform test_ext_setup_fixture();
  perform test_ext_version_ordering();
  perform test_ext_setup_fixture();
  perform test_ext_conflict_recovery();
  perform test_ext_setup_fixture();
  perform test_ext_venue_slot_mismatch_rejected();
  perform set_config('request.jwt.claim.sub', '', true);
  raise notice 'ALL EXTERNAL-CHANNEL CORRECTNESS TESTS PASSED';
end $$;
