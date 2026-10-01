-- Keep the confirmation implementation compatible with older deployments,
-- but never preserve a payment-only bypass. Every booking, including legacy
-- pending rows, must carry a real owner approval before confirmation.
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

revoke all on function public.confirm_venue_booking(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.confirm_venue_booking(uuid, uuid, text, text)
  to service_role;
