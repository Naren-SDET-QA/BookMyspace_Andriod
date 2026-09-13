-- Late owner actions must produce the same customer-visible expiry records as
-- the scheduler. Without this override, clicking Accept after the approval
-- deadline changed the booking and released the hold but silently omitted the
-- required audit entry and customer notification.

create or replace function public.approve_venue_booking(
  p_booking_id uuid,
  p_idempotency_key uuid default null,
  p_payment_minutes integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
$$;

revoke all on function public.approve_venue_booking(uuid, uuid, integer)
  from public, anon;
grant execute on function public.approve_venue_booking(uuid, uuid, integer)
  to authenticated;
