-- ============================================================
-- BookMySpace — External Channel Inventory: RPCs
--
-- All SECURITY DEFINER functions pin search_path per project convention
-- and never trust client-supplied user IDs — owner identity always comes
-- from auth.uid(). The two service-role-only entry points
-- (apply_external_reservation_event, record_external_sync_result) have
-- EXECUTE revoked from authenticated/anon entirely, so only the
-- service-role key (used by the webhook/sync edge functions) can call
-- them at all.
-- ============================================================

alter type public.booking_status add value if not exists 'external_conflict';

-- ------------------------------------------------------------
-- Helper: is the caller the owner of this connection (or admin)?
--
-- P2 fix: identity is derived internally from auth.uid() rather than
-- accepted as a caller-supplied parameter, so this function can never be
-- called with someone else's uid. The old 2-arg overload is dropped
-- (not just replaced) so no caller-supplied-uid entry point survives.
-- ------------------------------------------------------------
drop function if exists public.can_manage_external_connection(uuid, uuid);

create or replace function public.can_manage_external_connection(p_connection_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1 from public.external_channel_connections c
    where c.id = p_connection_id
      and (c.owner_user_id = auth.uid() or public.is_platform_admin(auth.uid()))
  );
$$;

revoke all on function public.can_manage_external_connection(uuid) from public;
grant execute on function public.can_manage_external_connection(uuid) to authenticated;

-- ------------------------------------------------------------
-- Owner: create a connection (status stays pending_setup / blocked_external
-- until a real credential is wired server-side).
-- ------------------------------------------------------------
create or replace function public.create_external_channel_connection(
  p_venue_id uuid,
  p_provider_code text,
  p_config jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_provider_id uuid;
  v_connection_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;

  if not public.owns_venue(v_uid, p_venue_id) and not public.is_platform_admin(v_uid) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_VENUE_OWNER');
  end if;

  select id into v_provider_id from public.external_channel_providers where code = p_provider_code;
  if v_provider_id is null then
    return jsonb_build_object('success', false, 'error_code', 'UNKNOWN_PROVIDER');
  end if;

  insert into public.external_channel_connections (venue_id, provider_id, owner_user_id, config, status, health)
  values (p_venue_id, v_provider_id, v_uid, coalesce(p_config, '{}'::jsonb), 'pending_setup', 'not_configured')
  on conflict (venue_id, provider_id) do update
    set config = excluded.config, updated_at = now()
  returning id into v_connection_id;

  insert into public.inventory_sync_state (connection_id, sync_status)
  values (v_connection_id, 'idle')
  on conflict (connection_id) do nothing;

  return jsonb_build_object('success', true, 'connection_id', v_connection_id, 'status', 'pending_setup');
end;
$$;

revoke all on function public.create_external_channel_connection(uuid, text, jsonb) from public;
grant execute on function public.create_external_channel_connection(uuid, text, jsonb) to authenticated;

-- ------------------------------------------------------------
-- Owner: disconnect safely (does not delete history; marks disconnected).
-- ------------------------------------------------------------
create or replace function public.disconnect_external_channel_connection(p_connection_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not public.can_manage_external_connection(p_connection_id) then
    return jsonb_build_object('success', false, 'error_code', 'FORBIDDEN');
  end if;

  update public.external_channel_connections
  set status = 'disconnected', health = 'not_configured', updated_at = now()
  where id = p_connection_id;

  insert into public.inventory_change_log (venue_id, connection_id, source, change_type, actor)
  select c.venue_id, c.id, 'admin', 'connection_disconnected', v_uid::text
  from public.external_channel_connections c where c.id = p_connection_id;

  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.disconnect_external_channel_connection(uuid) from public;
grant execute on function public.disconnect_external_channel_connection(uuid) to authenticated;

-- ------------------------------------------------------------
-- Owner/Admin: request a manual resync. This only flags the connection for
-- the sync edge function (`external-inventory-sync`) to pick up; it does
-- not itself talk to any provider.
-- ------------------------------------------------------------
create or replace function public.request_external_manual_sync(p_connection_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not public.can_manage_external_connection(p_connection_id) then
    return jsonb_build_object('success', false, 'error_code', 'FORBIDDEN');
  end if;

  insert into public.inventory_sync_state (connection_id, sync_status, last_sync_attempt_at)
  values (p_connection_id, 'syncing', now())
  on conflict (connection_id) do update
    set sync_status = 'syncing', last_sync_attempt_at = now(), updated_at = now();

  return jsonb_build_object('success', true, 'status', 'sync_requested');
end;
$$;

revoke all on function public.request_external_manual_sync(uuid) from public;
grant execute on function public.request_external_manual_sync(uuid) to authenticated;

-- ------------------------------------------------------------
-- SERVICE-ROLE ONLY: apply a normalized reservation event from the webhook
-- edge function. Idempotent (unique external_event_id per provider+
-- connection), ordering-aware (provider_version/provider_updated_at), and
-- this is what actually blocks/unblocks local inventory.
-- ------------------------------------------------------------
create or replace function public.apply_external_reservation_event(
  p_connection_id uuid,
  p_external_event_id text,
  p_event_type text,
  p_external_reservation_id text,
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_provider_version bigint default null,
  p_provider_updated_at timestamptz default null,
  p_guest_ref text default null,
  p_raw_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_provider_id uuid;
  v_event_id uuid;
  v_existing_reservation record;
  v_new_status text;
  v_lock_key bigint;
  v_local_booking_id uuid;
  v_venue_id uuid;
  v_slot_venue_id uuid;
  v_slot_mapped boolean;
begin
  select provider_id, venue_id into v_provider_id, v_venue_id
  from public.external_channel_connections
  where id = p_connection_id;

  if v_provider_id is null then
    return jsonb_build_object('success', false, 'error_code', 'UNKNOWN_CONNECTION');
  end if;

  if p_venue_id is not null and p_venue_id is distinct from v_venue_id then
    return jsonb_build_object(
      'success', false, 'error_code', 'VENUE_MISMATCH',
      'message', 'p_venue_id does not match the connection''s own venue; rejected rather than trusted.'
    );
  end if;

  if p_slot_id is not null then
    select venue_id into v_slot_venue_id
    from public.time_slots
    where id = p_slot_id;

    if v_slot_venue_id is null or v_slot_venue_id is distinct from v_venue_id then
      return jsonb_build_object(
        'success', false, 'error_code', 'SLOT_VENUE_MISMATCH',
        'message', 'p_slot_id does not belong to this connection''s venue; rejected rather than trusted.'
      );
    end if;

    select exists (
      select 1 from public.external_room_mappings rm
      where rm.connection_id = p_connection_id
        and rm.local_slot_id = p_slot_id
        and rm.status = 'active'
    ) into v_slot_mapped;

    if not v_slot_mapped then
      return jsonb_build_object(
        'success', false, 'error_code', 'SLOT_NOT_MAPPED',
        'message', 'p_slot_id is not an active room mapping for this connection; rejected rather than trusted.'
      );
    end if;
  end if;

  begin
    insert into public.external_inventory_events (
      connection_id, provider_id, external_event_id, event_type, payload, processing_status
    ) values (
      p_connection_id, v_provider_id, p_external_event_id, p_event_type, p_raw_payload, 'received'
    ) returning id into v_event_id;
  exception when unique_violation then
    return jsonb_build_object('success', true, 'status', 'duplicate_event_ignored');
  end;

  v_lock_key := hashtextextended(v_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  v_new_status := case p_event_type
    when 'reservation.cancelled' then 'cancelled'
    else 'booked'
  end;

  select * into v_existing_reservation
  from public.external_reservations
  where connection_id = p_connection_id and external_reservation_id = p_external_reservation_id
  for update;

  if found then
    if v_existing_reservation.provider_version is not null and p_provider_version is not null
       and p_provider_version <= v_existing_reservation.provider_version then
      update public.external_inventory_events
      set processing_status = 'out_of_order_buffered', processed_at = now()
      where id = v_event_id;
      return jsonb_build_object('success', true, 'status', 'stale_event_ignored');
    end if;

    update public.external_reservations
    set status = v_new_status,
        provider_version = coalesce(p_provider_version, provider_version),
        provider_updated_at = coalesce(p_provider_updated_at, provider_updated_at),
        raw_event_ref = v_event_id,
        updated_at = now(),
        last_synced_at = now()
    where id = v_existing_reservation.id;

    insert into public.inventory_change_log (
      venue_id, slot_id, book_date, connection_id, source, change_type, previous_state, new_state, actor
    ) values (
      v_venue_id, p_slot_id, p_book_date, p_connection_id, 'external',
      case when v_new_status = 'cancelled' then 'released' else 'reserved' end,
      to_jsonb(v_existing_reservation), jsonb_build_object('status', v_new_status), 'webhook'
    );
  else
    insert into public.external_reservations (
      connection_id, provider_id, external_reservation_id, venue_id, slot_id, book_date,
      status, provider_version, provider_updated_at, guest_ref, raw_event_ref
    ) values (
      p_connection_id, v_provider_id, p_external_reservation_id, v_venue_id, p_slot_id, p_book_date,
      v_new_status, p_provider_version, p_provider_updated_at, p_guest_ref, v_event_id
    );

    insert into public.inventory_change_log (
      venue_id, slot_id, book_date, connection_id, source, change_type, previous_state, new_state, actor
    ) values (
      v_venue_id, p_slot_id, p_book_date, p_connection_id, 'external',
      case when v_new_status = 'cancelled' then 'released' else 'reserved' end,
      null, jsonb_build_object('status', v_new_status), 'webhook'
    );
  end if;

  if v_new_status = 'booked' then
    update public.bookings b
    set status = 'external_conflict',
        updated_at = now(),
        metadata = coalesce(b.metadata, '{}'::jsonb) || jsonb_build_object(
          'external_conflict_reservation', p_external_reservation_id,
          'external_conflict_detected_at', now()
        )
    where b.venue_id = v_venue_id
      and b.book_date = p_book_date
      and b.status in ('held', 'pending')
      and (p_slot_id is null or b.slot_id = p_slot_id)
    returning b.id into v_local_booking_id;

    if v_local_booking_id is not null then
      update public.booking_holds h
      set status = 'released'
      where h.id = (select hold_id from public.bookings where id = v_local_booking_id)
        and h.status = 'active';

      insert into public.inventory_change_log (
        venue_id, slot_id, book_date, connection_id, source, change_type, previous_state, new_state, actor
      ) values (
        v_venue_id, p_slot_id, p_book_date, p_connection_id, 'external', 'mismatch_detected',
        jsonb_build_object('local_booking_id', v_local_booking_id),
        jsonb_build_object('status', 'external_conflict'), 'webhook'
      );
    end if;
  end if;

  update public.external_inventory_events
  set processing_status = 'processed', processed_at = now()
  where id = v_event_id;

  update public.external_channel_connections
  set last_synced_at = now(), health = 'healthy', status = 'connected', updated_at = now()
  where id = p_connection_id;

  update public.inventory_sync_state
  set last_success_at = now(), sync_status = 'success', consecutive_failures = 0, updated_at = now()
  where connection_id = p_connection_id;

  return jsonb_build_object('success', true, 'status', v_new_status, 'conflicted_local_booking_id', v_local_booking_id);
end;
$$;

revoke all on function public.apply_external_reservation_event(
  uuid, text, text, text, uuid, uuid, date, bigint, timestamptz, text, jsonb
) from public;
revoke all on function public.apply_external_reservation_event(
  uuid, text, text, text, uuid, uuid, date, bigint, timestamptz, text, jsonb
) from authenticated;

-- ------------------------------------------------------------
-- SERVICE-ROLE ONLY: record a sync pass result (used by
-- external-inventory-sync edge function after a pull/reconciliation
-- attempt, real or BLOCKED_EXTERNAL).
-- ------------------------------------------------------------
create or replace function public.record_external_sync_result(
  p_connection_id uuid,
  p_success boolean,
  p_mismatch_count integer default 0,
  p_error_code text default null,
  p_error_message text default null,
  p_context jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_success then
    update public.inventory_sync_state
    set sync_status = 'success',
        last_success_at = now(),
        last_sync_attempt_at = now(),
        consecutive_failures = 0,
        mismatch_count = p_mismatch_count,
        updated_at = now()
    where connection_id = p_connection_id;

    update public.external_channel_connections
    set last_synced_at = now(), health = 'healthy', updated_at = now()
    where id = p_connection_id;
  else
    update public.inventory_sync_state
    set sync_status = 'error',
        last_sync_attempt_at = now(),
        consecutive_failures = consecutive_failures + 1,
        next_retry_at = now() + (least(power(2, consecutive_failures + 1), 60) * interval '1 minute'),
        updated_at = now()
    where connection_id = p_connection_id;

    update public.external_channel_connections
    set health = 'unavailable', last_error = p_error_message, updated_at = now()
    where id = p_connection_id;

    insert into public.inventory_sync_errors (connection_id, error_code, error_message, context)
    values (p_connection_id, coalesce(p_error_code, 'sync_failed'), coalesce(p_error_message, 'unknown error'), coalesce(p_context, '{}'::jsonb));
  end if;

  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.record_external_sync_result(uuid, boolean, integer, text, text, jsonb) from public;
revoke all on function public.record_external_sync_result(uuid, boolean, integer, text, text, jsonb) from authenticated;

-- ------------------------------------------------------------
-- DOUBLE-BOOKING PROTECTION: teach the CURRENT LIVE acquire_venue_hold
-- about externally-reserved inventory. Body copied verbatim from the
-- live bookmyspace-dev definition, with one additive block inserted.
-- ------------------------------------------------------------
create or replace function public.acquire_venue_hold(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_base_amount numeric,
  p_tax_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_hold_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_slot_label text;
  v_slot_start time;
  v_slot_end time;
  v_total_amount numeric;
  v_hold_id uuid;
  v_booking_id uuid;
  v_booking_ref text;
  v_expires_at timestamptz;
  v_lock_key bigint;
  v_existing_status text;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'authenticated user mismatch' using errcode = '42501';
  end if;

  perform public.expire_stale_holds();

  select label, start_time, end_time into v_slot_label, v_slot_start, v_slot_end
  from public.time_slots
  where id = p_slot_id and venue_id = p_venue_id and is_active = true;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SLOT',
      'message', 'The specified time slot is invalid or inactive.'
    );
  end if;

  select h.id, h.expires_at, h.status, b.id into v_hold_id, v_expires_at, v_existing_status, v_booking_id
  from public.booking_holds h
  left join public.bookings b on b.hold_id = h.id
  where h.idempotency_key = p_idempotency_key;

  if v_hold_id is not null then
    if v_existing_status = 'active' and v_expires_at > now() then
      return jsonb_build_object(
        'success', true,
        'hold_id', v_hold_id,
        'booking_id', v_booking_id,
        'status', 'HELD',
        'expires_at', v_expires_at,
        'message', 'Existing valid hold returned.'
      );
    end if;
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  if exists (
    select 1 from public.venue_blocked_dates
    where venue_id = p_venue_id and blocked_date = p_book_date
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'DATE_BLOCKED',
      'message', 'The venue is unavailable on the selected date.'
    );
  end if;

  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id
      and h.book_date = p_book_date
      and h.status = 'active'
      and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id
          and s.start_time < v_slot_end
          and s.end_time > v_slot_start
      )
  ) or exists (
    select 1 from public.bookings b
    where b.venue_id = p_venue_id
      and b.book_date = p_book_date
      and b.status in ('held', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot_end
      and b.end_time > v_slot_start
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_UNAVAILABLE',
      'message', 'This slot is already held or booked by another customer. Double-booking prevented.'
    );
  end if;

  if exists (
    select 1 from public.external_reservations er
    where er.venue_id = p_venue_id
      and er.book_date = p_book_date
      and er.status <> 'cancelled'
      and (er.slot_id is null or er.slot_id = p_slot_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel and is unavailable.'
    );
  end if;

  v_total_amount := p_base_amount + p_tax_amount - p_discount_amount;
  if v_total_amount < 0 then
    v_total_amount := 0;
  end if;
  v_expires_at := now() + (p_hold_minutes * interval '1 minute');

  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, v_total_amount, v_expires_at, 'active'
  ) returning id into v_hold_id;

  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
    hold_id, status, quantity, amount, tax_amount, discount_amount, total_amount,
    metadata
  ) values (
    v_booking_ref, p_user_id, p_venue_id, p_slot_id, p_book_date, v_slot_start, v_slot_end,
    v_hold_id, 'held', 1, p_base_amount, p_tax_amount, p_discount_amount, v_total_amount,
    jsonb_build_object('hold_expires_at', v_expires_at, 'idempotency_key', p_idempotency_key)
  ) returning id into v_booking_id;

  return jsonb_build_object(
    'success', true,
    'hold_id', v_hold_id,
    'booking_id', v_booking_id,
    'booking_ref', v_booking_ref,
    'status', 'HELD',
    'total_amount', v_total_amount,
    'expires_at', v_expires_at,
    'message', 'Slot successfully held for ' || p_hold_minutes || ' minutes.'
  );
end;
$$;

-- ------------------------------------------------------------
-- FINAL AVAILABILITY VALIDATION at confirm time: teach the CURRENT LIVE
-- confirm_venue_booking about externally-reserved inventory. Body copied
-- verbatim from the live bookmyspace-dev definition, with two additive
-- blocks inserted.
-- ------------------------------------------------------------
create or replace function public.confirm_venue_booking(
  p_booking_id uuid,
  p_user_id uuid,
  p_payment_ref text,
  p_payment_method text default 'UPIRazorpay'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_payment record;
  v_slot record;
  v_lock_key bigint;
  v_receipt_number text;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;

  select * into v_booking from public.bookings b
  where b.id = p_booking_id and b.user_id = p_user_id
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;

  if v_booking.status = 'confirmed' then
    select receipt_number into v_receipt_number
    from public.booking_receipts where booking_id = p_booking_id;
    return jsonb_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'CONFIRMED', 'receipt_number', v_receipt_number, 'idempotent', true);
  end if;

  if v_booking.status = 'external_conflict' then
    return jsonb_build_object('success', false, 'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel. Payment success is not booking success; refund/void required, booking placed in safe failure state.');
  end if;

  if v_booking.status <> 'pending'
     or v_booking.approved_at is null
     or v_booking.approved_by is null then
    return jsonb_build_object('success', false, 'error_code', 'OWNER_APPROVAL_REQUIRED',
      'message', 'Payment cannot confirm a booking before the venue owner approves it.');
  end if;
  if v_booking.payment_expires_at is not null and v_booking.payment_expires_at <= now() then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_WINDOW_EXPIRED');
  end if;
  if p_payment_ref is null or length(trim(p_payment_ref)) = 0 then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_REQUIRED');
  end if;

  select p.* into v_payment from public.payments p
  where p.booking_id = p_booking_id and p.status = 'captured'
    and p.provider_payment_id = p_payment_ref
  order by p.updated_at desc limit 1;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NO_CAPTURED_PAYMENT');
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  select s.id, s.start_time, s.end_time into v_slot
  from public.time_slots s
  where s.id = v_booking.slot_id and s.venue_id = v_booking.venue_id and s.is_active = true;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = v_booking.venue_id and d.blocked_date = v_booking.book_date
  ) or exists (
    select 1 from public.bookings b
    where b.id <> v_booking.id and b.venue_id = v_booking.venue_id
      and b.book_date = v_booking.book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if v_booking.hold_id is null or not exists (
    select 1 from public.booking_holds h
    where h.id = v_booking.hold_id and h.status = 'active' and h.expires_at > now()
  ) then
    return jsonb_build_object('success', false, 'error_code', 'HOLD_EXPIRED');
  end if;

  if exists (
    select 1 from public.external_reservations er
    where er.venue_id = v_booking.venue_id
      and er.book_date = v_booking.book_date
      and er.status <> 'cancelled'
      and (er.slot_id is null or er.slot_id = v_booking.slot_id)
  ) then
    update public.bookings
    set status = 'external_conflict',
        updated_at = now(),
        metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
          'external_conflict_at_confirm', now(),
          'external_conflict_payment_ref', p_payment_ref
        )
    where id = v_booking.id;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (v_booking.user_id, 'booking_external_conflict', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', v_booking.status,
        'to_status', 'external_conflict', 'payment_ref', p_payment_ref, 'payment_id', v_payment.id,
        'reason', 'external_channel_reservation_detected_at_confirmation'));

    return jsonb_build_object('success', false, 'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel while payment was captured. Payment success does not mean booking success; refund/void must be issued for payment ' || p_payment_ref || '. Booking placed in safe external_conflict state.');
  end if;

  v_receipt_number := 'BMS-R-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.booking_receipts (booking_id, payment_id, receipt_number, amount, currency, metadata)
  values (v_booking.id, v_payment.id, v_receipt_number, v_booking.total_amount,
    v_booking.currency, jsonb_build_object('issued_after', 'captured_payment_and_owner_approval'))
  on conflict (booking_id) do nothing;

  update public.booking_holds set status = 'confirmed' where id = v_booking.hold_id;
  update public.bookings
  set status = 'confirmed', confirmed_at = now(), updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref, 'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc')
  where id = v_booking.id and status = 'pending';

  select receipt_number into v_receipt_number
  from public.booking_receipts where booking_id = v_booking.id;
  insert into public.notifications (user_id, title, body, type, data)
  values (v_booking.user_id, 'Booking confirmed',
    'Your owner-approved payment was captured and the booking is confirmed. Your receipt is ready.',
    'booking_confirmed', jsonb_build_object('booking_id', v_booking.id,
      'receipt_number', v_receipt_number));
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (v_booking.user_id, 'booking_confirmed', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'pending',
      'to_status', 'confirmed', 'actor_role', 'payment_webhook',
      'payment_id', v_payment.id, 'receipt_number', v_receipt_number));
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref, 'status', 'CONFIRMED',
    'receipt_number', v_receipt_number, 'confirmed_at', now());
end;
$$;
