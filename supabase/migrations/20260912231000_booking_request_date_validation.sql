-- Reject impossible booking requests at the server boundary. The client date
-- picker is only a convenience and cannot be the authority for this check.
create or replace function public.request_venue_booking(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_base_amount numeric default 0,
  p_tax_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_approval_minutes integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_slot record;
  v_existing record;
  v_hold_id uuid;
  v_booking_id uuid;
  v_booking_ref text;
  v_requested_at timestamptz := now();
  v_approval_expires_at timestamptz;
  v_lock_key bigint;
  v_request_lock_key bigint;
  v_base numeric(12,2);
  v_tax numeric(12,2);
  v_total numeric(12,2);
  v_owner_id uuid;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if p_idempotency_key is null then
    return jsonb_build_object('success', false, 'error_code', 'MISSING_IDEMPOTENCY_KEY');
  end if;
  if p_book_date < current_date then
    return jsonb_build_object('success', false, 'error_code', 'DATE_IN_PAST');
  end if;

  v_request_lock_key := hashtextextended(
    'booking-request:' || p_user_id::text || ':' || p_idempotency_key::text, 0
  );
  perform pg_advisory_xact_lock(v_request_lock_key);

  select b.id, b.hold_id, b.booking_ref, b.status, b.approval_expires_at,
         b.payment_expires_at, b.total_amount
  into v_existing
  from public.bookings b
  where b.user_id = p_user_id
    and b.request_idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'success', true, 'booking_id', v_existing.id, 'hold_id', v_existing.hold_id,
      'booking_ref', v_existing.booking_ref, 'status', v_existing.status,
      'approval_expires_at', v_existing.approval_expires_at,
      'payment_expires_at', v_existing.payment_expires_at,
      'total_amount', v_existing.total_amount, 'idempotent', true
    );
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  perform public.expire_stale_holds();

  select s.id, s.label, s.start_time, s.end_time, s.price_amount,
         v.tax_rate, v.org_id
  into v_slot
  from public.time_slots s
  join public.venues v on v.id = s.venue_id
  where s.id = p_slot_id
    and s.venue_id = p_venue_id
    and s.is_active = true
    and v.is_active = true
    and v.deleted_at is null;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_SLOT');
  end if;

  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = p_venue_id and d.blocked_date = p_book_date
  ) then
    return jsonb_build_object('success', false, 'error_code', 'DATE_BLOCKED');
  end if;

  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id and h.book_date = p_book_date
      and h.status = 'active' and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id
          and s.start_time < v_slot.end_time
          and s.end_time > v_slot.start_time
      )
  ) or exists (
    select 1 from public.bookings b
    where b.venue_id = p_venue_id and b.book_date = p_book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object(
      'success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'The selected venue, date, and time slot is no longer available.'
    );
  end if;

  v_base := round(coalesce(v_slot.price_amount, 0)::numeric, 2);
  v_tax := round(v_base * greatest(0, least(coalesce(v_slot.tax_rate, 0), 100)) / 100, 2);
  v_total := greatest(0, v_base + v_tax);
  v_approval_expires_at := v_requested_at +
    (greatest(15, least(coalesce(p_approval_minutes, 120), 1440)) * interval '1 minute');
  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, v_total,
    v_approval_expires_at, 'active'
  ) returning id into v_hold_id;

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
    hold_id, status, quantity, amount, tax_amount, discount_amount, total_amount,
    currency, request_idempotency_key, approval_required, approval_requested_at,
    approval_expires_at, metadata
  ) values (
    v_booking_ref, p_user_id, p_venue_id, p_slot_id, p_book_date,
    v_slot.start_time, v_slot.end_time, v_hold_id, 'awaiting_owner_approval', 1,
    v_base, v_tax, 0, v_total, 'INR', p_idempotency_key, true, v_requested_at,
    v_approval_expires_at,
    jsonb_build_object('approval_mode', 'request_to_book', 'request_idempotency_key', p_idempotency_key)
  ) returning id into v_booking_id;

  select o.owner_user_id into v_owner_id
  from public.organizations o
  where o.id = v_slot.org_id and o.deleted_at is null;
  if v_owner_id is not null then
    insert into public.notifications (user_id, title, body, type, data)
    values (
      v_owner_id, 'New booking request',
      'A customer requested your venue. Review the exact date and time before the approval deadline.',
      'system', jsonb_build_object('booking_id', v_booking_id, 'venue_id', p_venue_id,
        'approval_expires_at', v_approval_expires_at)
    );
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    p_user_id, 'booking_requested', 'booking', v_booking_id,
    jsonb_build_object('venue_id', p_venue_id, 'slot_id', p_slot_id,
      'book_date', p_book_date, 'from_status', null,
      'to_status', 'awaiting_owner_approval', 'actor_role', 'customer')
  );

  return jsonb_build_object(
    'success', true, 'booking_id', v_booking_id, 'hold_id', v_hold_id,
    'booking_ref', v_booking_ref, 'status', 'awaiting_owner_approval',
    'approval_expires_at', v_approval_expires_at, 'total_amount', v_total,
    'message', 'Your request was sent to the venue owner for approval.'
  );
end;
$$;

revoke all on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  from public, anon;
grant execute on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  to authenticated;
