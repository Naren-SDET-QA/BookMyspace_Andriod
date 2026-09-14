-- ============================================================
-- BookMySpace — External Channel: correctness hardening batch 2
--
-- Adds, purely additively, on top of the CURRENT LIVE booking/
-- external-channel functions (verified via pg_get_functiondef
-- against bookmyspace-dev immediately before writing this file):
--
--   1. Owner-approval re-check: approve_venue_booking() now
--      re-checks external_reservations under the same venue/date
--      advisory lock it already takes, and refuses to move a
--      booking to 'pending' (owner-accepted / awaiting payment) if
--      the slot was booked externally in the meantime.
--   2. External-conflict recovery: apply_external_reservation_event()
--      now reacts to a 'reservation.cancelled' event by moving any
--      local booking(s) it previously pushed into 'external_conflict'
--      for that venue/date/slot into a new terminal state,
--      'availability_reopened', with notification + audit — never
--      auto-confirming, charging, or resurrecting the booking.
--   3. Provider-version ordering: apply_external_reservation_event()
--      now also rejects a versionless incoming event when the
--      existing local reservation record is already versioned (so an
--      unknown-ordering event cannot blindly clobber known-newer
--      state), and falls back to provider_updated_at ordering when
--      neither side carries a version.
--
-- Every change here is additive on top of the exact live function
-- bodies pulled via pg_get_functiondef immediately before writing
-- this migration. No existing behavior (owner authorization, hold
-- handling, availability checks, audit logging, notifications,
-- booking-state transitions, idempotency-by-external_event_id) is
-- removed or altered.
-- ============================================================

-- New terminal booking_status value for the safe recovery path.
-- Never auto-transitions a booking back into a bookable/payable
-- state — it is a dead-end status that tells the customer and
-- owner a new request/approval/payment cycle is required.
alter type public.booking_status add value if not exists 'availability_reopened';


-- ------------------------------------------------------------
-- approve_venue_booking: additive external-conflict re-check
-- ------------------------------------------------------------
create or replace function public.approve_venue_booking(p_booking_id uuid, p_idempotency_key uuid DEFAULT NULL::uuid, p_payment_minutes integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_booking record;
  v_slot record;
  v_lock_key bigint;
  v_payment_expires_at timestamptz;
begin
  select b.*, v.org_id, o.owner_user_id
  into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id and o.owner_user_id = auth.uid() and o.deleted_at is null
  for update of b;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  if v_booking.status = 'pending' and v_booking.approved_by is not null then
    return jsonb_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'pending', 'idempotent', true,
      'payment_expires_at', v_booking.payment_expires_at);
  end if;
  if v_booking.status <> 'awaiting_owner_approval' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS',
      'message', 'This request is no longer awaiting owner approval.');
  end if;
  if v_booking.approval_expires_at is null or v_booking.approval_expires_at <= now() then
    update public.bookings
    set status = 'approval_expired', rejected_at = now(),
        rejection_reason = 'Owner approval window expired.', updated_at = now()
    where id = p_booking_id and status = 'awaiting_owner_approval';
    update public.booking_holds set status = 'released'
    where id = v_booking.hold_id and status = 'active';
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'booking_approval_expired', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id,
        'from_status', 'awaiting_owner_approval', 'to_status', 'approval_expired',
        'actor_role', 'venue_owner', 'reason', 'approval_window_expired'));
    insert into public.notifications (user_id, title, body, type, data)
    values (v_booking.user_id, 'Booking request expired',
      'The venue did not respond before the approval deadline. The slot was released and no payment was taken.',
      'system', jsonb_build_object('booking_id', v_booking.id));
    return jsonb_build_object('success', false, 'error_code', 'APPROVAL_EXPIRED');
  end if;

  if v_booking.hold_id is null or not exists (
    select 1
    from public.booking_holds h
    where h.id = v_booking.hold_id
      and h.status = 'active'
      and h.expires_at > now()
  ) then
    update public.bookings
    set status = 'approval_expired', rejected_at = now(),
        rejection_reason = 'The booking hold expired before owner approval.',
        updated_at = now()
    where id = p_booking_id and status = 'awaiting_owner_approval';
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'booking_approval_expired', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id,
        'from_status', 'awaiting_owner_approval', 'to_status', 'approval_expired',
        'actor_role', 'venue_owner', 'reason', 'hold_expired'));
    insert into public.notifications (user_id, title, body, type, data)
    values (v_booking.user_id, 'Booking request expired',
      'The slot hold expired before the venue owner could approve the request. No payment was taken.',
      'system', jsonb_build_object('booking_id', v_booking.id));
    return jsonb_build_object('success', false, 'error_code', 'APPROVAL_EXPIRED');
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  select s.id, s.start_time, s.end_time
  into v_slot
  from public.time_slots s
  where s.id = v_booking.slot_id and s.venue_id = v_booking.venue_id and s.is_active = true;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'The selected time slot is no longer active.');
  end if;
  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = v_booking.venue_id and d.blocked_date = v_booking.book_date
  ) or exists (
    select 1 from public.booking_holds h
    where h.venue_id = v_booking.venue_id and h.book_date = v_booking.book_date
      and h.id <> v_booking.hold_id and h.status = 'active' and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id and s.start_time < v_slot.end_time and s.end_time > v_slot.start_time
      )
  ) or exists (
    select 1 from public.bookings b
    where b.id <> v_booking.id and b.venue_id = v_booking.venue_id
      and b.book_date = v_booking.book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'Availability changed. This request cannot be approved.');
  end if;

  -- NEW: external-channel re-check, under the same venue/date advisory
  -- lock already held above. If this inventory was booked through an
  -- external channel in the meantime, do NOT transition to
  -- owner-accepted ('pending'); fail deterministically instead.
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
          'external_conflict_at_approval', now()
        )
    where id = v_booking.id;

    update public.booking_holds set status = 'released'
    where id = v_booking.hold_id and status = 'active';

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'booking_external_conflict', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', v_booking.status,
        'to_status', 'external_conflict', 'actor_role', 'venue_owner',
        'reason', 'external_channel_reservation_detected_at_owner_approval'));

    insert into public.notifications (user_id, title, body, type, data)
    values (v_booking.user_id, 'Booking request unavailable',
      'This date/time was booked through an external channel before the venue owner could accept your request. No payment was taken.',
      'system', jsonb_build_object('booking_id', v_booking.id));

    return jsonb_build_object('success', false, 'error_code', 'EXTERNALLY_BOOKED',
      'message', 'This inventory was booked through an external channel; the request cannot be accepted.');
  end if;

  v_payment_expires_at := now() +
    (greatest(15, least(coalesce(p_payment_minutes, 60), 1440)) * interval '1 minute');
  update public.bookings
  set status = 'pending', approved_at = now(), approved_by = auth.uid(),
      approval_idempotency_key = coalesce(p_idempotency_key, approval_idempotency_key),
      payment_expires_at = v_payment_expires_at, updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('approval_mode', 'request_to_book', 'approved_by', auth.uid())
  where id = v_booking.id and status = 'awaiting_owner_approval';
  update public.booking_holds
  set expires_at = v_payment_expires_at
  where id = v_booking.hold_id and status = 'active' and expires_at > now();

  insert into public.notifications (user_id, title, body, type, data)
  values (
    v_booking.user_id, 'Booking request accepted',
    'The venue owner accepted your requested date and time. Complete payment before the payment deadline.',
    'system', jsonb_build_object('booking_id', v_booking.id, 'payment_expires_at', v_payment_expires_at)
  );
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking_owner_approved', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'awaiting_owner_approval',
      'to_status', 'pending', 'actor_role', 'venue_owner', 'idempotency_key', p_idempotency_key)
  );
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'status', 'pending', 'payment_expires_at', v_payment_expires_at);
end;
$function$;


-- ------------------------------------------------------------
-- apply_external_reservation_event: additive stale-event ordering
-- + external-conflict recovery on cancellation
-- ------------------------------------------------------------
create or replace function public.apply_external_reservation_event(p_connection_id uuid, p_external_event_id text, p_event_type text, p_external_reservation_id text, p_venue_id uuid, p_slot_id uuid, p_book_date date, p_provider_version bigint DEFAULT NULL::bigint, p_provider_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_guest_ref text DEFAULT NULL::text, p_raw_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    -- NEW: deterministic ordering, tightened beyond the original
    -- "both versioned, non-increasing" check. This only ever ADDS
    -- reasons to treat an incoming event as stale — it never accepts
    -- anything the original check would have rejected.
    if (
      -- both versioned: strictly non-increasing provider_version is stale (original rule)
      v_existing_reservation.provider_version is not null and p_provider_version is not null
      and p_provider_version <= v_existing_reservation.provider_version
    ) or (
      -- incoming is versionless but the existing local record is versioned:
      -- an unknown-ordering event must not blindly overwrite known-newer state
      p_provider_version is null and v_existing_reservation.provider_version is not null
    ) or (
      -- both versionless: fall back to provider_updated_at ordering when both are known
      p_provider_version is null and v_existing_reservation.provider_version is null
      and p_provider_updated_at is not null and v_existing_reservation.provider_updated_at is not null
      and p_provider_updated_at < v_existing_reservation.provider_updated_at
    ) then
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
  elsif v_new_status = 'cancelled' then
    -- NEW: external-conflict recovery. The external reservation that
    -- previously blocked this venue/date/slot has been cancelled.
    -- Reopen availability for any local booking(s) this connection
    -- pushed into 'external_conflict' for the same venue/date/slot —
    -- WITHOUT auto-confirming, charging, or resurrecting them. They
    -- land in the terminal 'availability_reopened' state; the
    -- customer/owner must start a fresh request/approval/payment
    -- flow if they still want the slot. Idempotent: once a booking
    -- leaves 'external_conflict' this loop's WHERE clause no longer
    -- matches it on replay.
    for v_local_booking_id in
      select b.id from public.bookings b
      where b.venue_id = v_venue_id
        and b.book_date = p_book_date
        and b.status = 'external_conflict'
        and (p_slot_id is null or b.slot_id = p_slot_id)
      for update
    loop
      update public.bookings
      set status = 'availability_reopened',
          updated_at = now(),
          metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
            'external_conflict_recovered_at', now(),
            'external_conflict_recovery_reservation', p_external_reservation_id
          )
      where id = v_local_booking_id and status = 'external_conflict';

      insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
      values (null, 'booking_external_conflict_recovered', 'booking', v_local_booking_id,
        jsonb_build_object('venue_id', v_venue_id, 'slot_id', p_slot_id, 'book_date', p_book_date,
          'from_status', 'external_conflict', 'to_status', 'availability_reopened',
          'connection_id', p_connection_id, 'external_reservation_id', p_external_reservation_id,
          'reason', 'external_channel_reservation_cancelled'));

      insert into public.notifications (user_id, title, body, type, data)
      select b.user_id, 'Availability reopened',
        'The external booking that blocked your requested date/time has been cancelled. Availability has reopened; please start a new booking or approval request if you still want this slot.',
        'system', jsonb_build_object('booking_id', b.id)
      from public.bookings b where b.id = v_local_booking_id;
    end loop;
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
$function$;
