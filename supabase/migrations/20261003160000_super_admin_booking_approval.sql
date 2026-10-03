-- Request-to-book approval: every booking request in
-- `awaiting_owner_approval` goes to BOTH the venue owner AND the platform
-- administrators (super_administrator / administrator). Either one may approve
-- or decline; only one decision is needed.
--
-- This replaces the two existing RPCs in place (same signatures, same grants)
-- and adds one notification trigger. No new approval tables, states or RPCs
-- are introduced. Everything the previous RPC versions did is preserved:
--   * booking row lock (FOR UPDATE) and venue/date advisory lock
--   * status checks, approval-window and hold expiry handling
--   * slot / blocked-date / overlapping-hold / overlapping-booking checks
--   * external-channel conflict re-check
--   * approval moves the request to `pending` (payment still required);
--     the payment gate, holds and confirmation flow are untouched
--   * notifications and audit_logs rows
--
-- What changes:
--   1. Authorization: the venue owner OR a platform administrator, for every
--      venue category.
--   2. A second approval by a different person returns `ALREADY_PROCESSED`
--      instead of success. The same person repeating the call keeps the
--      previous idempotent-success reply, so the existing owner flow (double
--      taps, retries) is unchanged.
--   3. audit_logs.details.actor_role records `venue_owner`, `super_admin` or
--      `administrator`; admin decisions use the actions
--      `booking_admin_approved` / `booking_admin_rejected`.
--   4. New trigger: when a request is created, every active platform
--      administrator also gets a notification naming the venue, its owner,
--      the customer and the requested date/time. The owner keeps receiving
--      the existing "New booking request" notification from
--      `request_venue_booking`.
--
-- Callers that are not authorized (customers, other owners, anonymous,
-- service role without a user) get the same `NOT_OWNER_OR_NOT_FOUND` code as
-- before, so the RPC does not reveal whether a booking exists.

create or replace function public.approve_venue_booking(
  p_booking_id uuid,
  p_idempotency_key uuid default null,
  p_payment_minutes integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking record;
  v_slot record;
  v_lock_key bigint;
  v_payment_expires_at timestamptz;
  v_is_owner boolean := false;
  v_actor_role text;
  v_approved_action text;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  -- Authorize before taking any row lock.
  select (o.owner_user_id = v_uid and o.deleted_at is null)
  into v_is_owner
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  if coalesce(v_is_owner, false) then
    v_actor_role := 'venue_owner';
  elsif public.has_role(v_uid, 'super_administrator'::public.user_role) then
    v_actor_role := 'super_admin';
  elsif public.has_role(v_uid, 'administrator'::public.user_role) then
    v_actor_role := 'administrator';
  else
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;
  v_approved_action := case when v_actor_role = 'venue_owner'
    then 'booking_owner_approved' else 'booking_admin_approved' end;

  select b.*, v.org_id, o.owner_user_id
  into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id
  for update of b;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  if v_booking.status = 'pending' and v_booking.approved_by is not null then
    if v_booking.approved_by = v_uid then
      return jsonb_build_object('success', true, 'booking_id', p_booking_id,
        'status', 'pending', 'idempotent', true,
        'payment_expires_at', v_booking.payment_expires_at);
    end if;
    return jsonb_build_object('success', false, 'error_code', 'ALREADY_PROCESSED',
      'status', v_booking.status,
      'message', 'This request has already been approved.');
  end if;
  if v_booking.status <> 'awaiting_owner_approval' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS',
      'status', v_booking.status,
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
    values (v_uid, 'booking_approval_expired', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id,
        'from_status', 'awaiting_owner_approval', 'to_status', 'approval_expired',
        'actor_role', v_actor_role, 'reason', 'approval_window_expired'));
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
    values (v_uid, 'booking_approval_expired', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id,
        'from_status', 'awaiting_owner_approval', 'to_status', 'approval_expired',
        'actor_role', v_actor_role, 'reason', 'hold_expired'));
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

  -- External-channel re-check under the same venue/date advisory lock.
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
    values (v_uid, 'booking_external_conflict', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', v_booking.status,
        'to_status', 'external_conflict', 'actor_role', v_actor_role,
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
  set status = 'pending', approved_at = now(), approved_by = v_uid,
      approval_idempotency_key = coalesce(p_idempotency_key, approval_idempotency_key),
      payment_expires_at = v_payment_expires_at, updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('approval_mode', 'request_to_book', 'approved_by', v_uid,
          'approved_by_role', v_actor_role)
  where id = v_booking.id and status = 'awaiting_owner_approval';
  update public.booking_holds
  set expires_at = v_payment_expires_at
  where id = v_booking.hold_id and status = 'active' and expires_at > now();

  insert into public.notifications (user_id, title, body, type, data)
  values (
    v_booking.user_id, 'Booking request accepted',
    case when v_actor_role = 'venue_owner'
      then 'The venue owner accepted your requested date and time. Complete payment before the payment deadline.'
      else 'Your requested date and time was approved. Complete payment before the payment deadline.'
    end,
    'system', jsonb_build_object('booking_id', v_booking.id, 'payment_expires_at', v_payment_expires_at)
  );
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    v_uid, v_approved_action, 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'awaiting_owner_approval',
      'to_status', 'pending', 'actor_role', v_actor_role, 'idempotency_key', p_idempotency_key)
  );
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'status', 'pending', 'payment_expires_at', v_payment_expires_at,
    'actor_role', v_actor_role);
end;
$function$;

create or replace function public.reject_venue_booking(
  p_booking_id uuid,
  p_idempotency_key uuid default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking record;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_is_owner boolean := false;
  v_actor_role text;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  -- Authorize before taking any row lock.
  select (o.owner_user_id = v_uid and o.deleted_at is null)
  into v_is_owner
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  if coalesce(v_is_owner, false) then
    v_actor_role := 'venue_owner';
  elsif public.has_role(v_uid, 'super_administrator'::public.user_role) then
    v_actor_role := 'super_admin';
  elsif public.has_role(v_uid, 'administrator'::public.user_role) then
    v_actor_role := 'administrator';
  else
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  select b.* into v_booking
  from public.bookings b
  where b.id = p_booking_id
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;
  if v_booking.status in ('owner_rejected', 'approval_expired', 'cancelled') then
    return jsonb_build_object('success', true, 'booking_id', v_booking.id,
      'status', v_booking.status, 'idempotent', true);
  end if;
  if v_booking.status <> 'awaiting_owner_approval' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS',
      'status', v_booking.status);
  end if;

  update public.bookings
  set status = 'owner_rejected', rejected_at = now(),
      rejection_reason = coalesce(v_reason, case when v_actor_role = 'venue_owner'
        then 'Declined by venue owner.' else 'Declined by BookMySpace admin.' end),
      updated_at = now(), approval_idempotency_key = coalesce(p_idempotency_key, approval_idempotency_key),
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('rejected_by', v_uid, 'rejected_by_role', v_actor_role)
  where id = v_booking.id and status = 'awaiting_owner_approval';
  update public.booking_holds set status = 'released'
  where id = v_booking.hold_id and status = 'active';
  insert into public.notifications (user_id, title, body, type, data)
  values (v_booking.user_id, 'Booking request declined',
    case when v_actor_role = 'venue_owner'
      then 'The venue owner could not accept the requested date and time. No payment was taken.'
      else 'Your requested date and time could not be accepted. No payment was taken.'
    end,
    'system', jsonb_build_object('booking_id', v_booking.id));
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (v_uid,
    case when v_actor_role = 'venue_owner' then 'booking_owner_rejected' else 'booking_admin_rejected' end,
    'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'awaiting_owner_approval',
      'to_status', 'owner_rejected', 'actor_role', v_actor_role, 'reason', v_reason,
      'idempotency_key', p_idempotency_key));
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'status', 'owner_rejected', 'actor_role', v_actor_role);
end;
$function$;

revoke all on function public.approve_venue_booking(uuid, uuid, integer) from public, anon;
revoke all on function public.reject_venue_booking(uuid, uuid, text) from public, anon;
grant execute on function public.approve_venue_booking(uuid, uuid, integer) to authenticated, service_role;
grant execute on function public.reject_venue_booking(uuid, uuid, text) to authenticated, service_role;

-- Admin notification for every new booking request.
create or replace function public.notify_admins_of_booking_request()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_venue_name text;
  v_owner_id uuid;
  v_owner_label text;
  v_customer_label text;
begin
  select v.name, o.owner_user_id,
         coalesce(nullif(trim(op.name), ''), nullif(trim(pr.full_name), ''),
                  nullif(trim(o.name), ''), 'Venue owner')
  into v_venue_name, v_owner_id, v_owner_label
  from public.venues v
  join public.organizations o on o.id = v.org_id
  left join public.owner_profiles op on op.user_id = o.owner_user_id
  left join public.profiles pr on pr.id = o.owner_user_id
  where v.id = new.venue_id;

  select coalesce(nullif(trim(pr.full_name), ''), 'Customer')
  into v_customer_label
  from public.profiles pr
  where pr.id = new.user_id;

  insert into public.notifications (user_id, title, body, type, data)
  select distinct r.user_id,
    'New booking request',
    format('%s requested %s on %s (%s-%s). Owner: %s. You or the owner can approve.',
      coalesce(v_customer_label, 'A customer'), coalesce(v_venue_name, 'a venue'),
      to_char(new.book_date, 'DD Mon YYYY'),
      left(new.start_time::text, 5), left(new.end_time::text, 5),
      v_owner_label),
    'system',
    jsonb_build_object('booking_id', new.id, 'venue_id', new.venue_id,
      'owner_user_id', v_owner_id, 'audience', 'admin',
      'approval_expires_at', new.approval_expires_at)
  from public.user_roles r
  where r.role in ('administrator'::public.user_role, 'super_administrator'::public.user_role)
    and r.revoked_at is null
    and r.user_id is distinct from v_owner_id;
  return new;
end;
$function$;

revoke all on function public.notify_admins_of_booking_request() from public, anon, authenticated;

create or replace trigger trg_notify_admins_of_booking_request
  after insert on public.bookings
  for each row
  when (new.status = 'awaiting_owner_approval')
  execute function public.notify_admins_of_booking_request();
