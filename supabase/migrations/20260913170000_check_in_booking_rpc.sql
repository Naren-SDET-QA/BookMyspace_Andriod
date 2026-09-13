-- The QR entry pass has shipped since the check-in screen was built, but the
-- server function it calls was never created. Every scan therefore failed at
-- the RPC boundary, and because the client wrapped the call in a broad catch
-- the failure reached guests as "Invalid QR code or booking reference" — an
-- input error message for a missing backend contract.
--
-- This migration creates the missing transition. The QR payload carries only an
-- identifier; all authority to admit someone lives here, so a replayed,
-- cancelled or tampered pass cannot open the door.

-- Arrival is recorded on the booking itself. A null checked_in_at is the single
-- source of truth for "has not arrived yet".
alter table public.bookings
  add column if not exists checked_in_at timestamptz,
  add column if not exists checked_in_by uuid,
  add column if not exists check_in_method text;

comment on column public.bookings.checked_in_at is
  'Set once, on the first successful check-in. Null means the guest has not arrived.';
comment on column public.bookings.checked_in_by is
  'Authenticated actor who performed the check-in: the guest or the venue owner.';
comment on column public.bookings.check_in_method is
  'How the pass was presented, e.g. qr or manual.';

create or replace function public.check_in_booking(
  p_code text,
  p_method text default 'qr',
  p_venue_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code text;
  v_method text;
  v_booking record;
  v_is_guest boolean := false;
  v_is_host boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHENTICATED',
      'message', 'Sign in before checking in a booking.');
  end if;

  v_code := ltrim(btrim(coalesce(p_code, '')), '#');
  if v_code = '' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_BOOKING_PASS',
      'message', 'The booking pass is empty or invalid.');
  end if;

  v_method := coalesce(nullif(btrim(coalesce(p_method, '')), ''), 'qr');

  -- A pass carries either the booking reference or the booking id. Prefer an
  -- exact id match when both could apply.
  select b.*, v.org_id, o.owner_user_id
  into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  left join public.organizations o on o.id = v.org_id
  where b.booking_ref = v_code
     or b.id::text = v_code
  order by (b.id::text = v_code) desc
  limit 1;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND',
      'message', 'No booking matches this pass.');
  end if;

  v_is_guest := v_booking.user_id = auth.uid();
  v_is_host := v_booking.owner_user_id is not null
    and v_booking.owner_user_id = auth.uid();

  if not (v_is_guest or v_is_host or public.is_platform_admin(auth.uid())) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_AUTHORIZED',
      'message', 'This pass does not belong to your account or your venue.');
  end if;

  -- A scanner posted at the wrong venue must not admit the guest.
  if p_venue_id is not null and p_venue_id <> v_booking.venue_id then
    return jsonb_build_object('success', false, 'error_code', 'WRONG_VENUE',
      'message', 'This pass is for a different venue.');
  end if;

  if v_booking.status = 'cancelled' then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_CANCELLED',
      'message', 'This booking was cancelled and cannot be checked in.');
  end if;

  if v_booking.status = 'refunded' then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_REFUNDED',
      'message', 'This booking was refunded and cannot be checked in.');
  end if;

  -- Replay: a pass that has already admitted someone is reported as used rather
  -- than silently admitting them a second time.
  if v_booking.checked_in_at is not null then
    return jsonb_build_object('success', true, 'booking_id', v_booking.id,
      'status', v_booking.status::text, 'already_checked_in', true,
      'checked_in_at', v_booking.checked_in_at,
      'message', 'This pass has already been used.');
  end if;

  if v_booking.status not in ('confirmed', 'completed') then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS',
      'message', 'Only a confirmed booking can be checked in.');
  end if;

  -- Guarded update: if two scanners race for the same pass, exactly one writes.
  update public.bookings
  set status = 'completed',
      checked_in_at = now(),
      checked_in_by = auth.uid(),
      check_in_method = v_method,
      updated_at = now()
  where id = v_booking.id
    and checked_in_at is null;

  if not found then
    return jsonb_build_object('success', true, 'booking_id', v_booking.id,
      'status', 'completed', 'already_checked_in', true,
      'message', 'This pass has already been used.');
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'booking_checked_in', 'booking', v_booking.id,
    jsonb_build_object(
      'venue_id', v_booking.venue_id,
      'booking_ref', v_booking.booking_ref,
      'from_status', v_booking.status::text,
      'to_status', 'completed',
      'actor_role', case when v_is_host then 'venue_owner' else 'customer' end,
      'method', v_method));

  -- Notify the guest only when someone else admitted them, so a self check-in
  -- does not generate a notification about an action the guest just took.
  if not v_is_guest then
    insert into public.notifications (user_id, title, body, type, data)
    values (v_booking.user_id, 'Checked in',
      'Your entry pass was scanned at the venue and your booking is now checked in.',
      'system', jsonb_build_object('booking_id', v_booking.id, 'checked_in_at', now()));
  end if;

  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'status', 'completed', 'already_checked_in', false, 'checked_in_at', now());
end;
$$;

comment on function public.check_in_booking(text, text, uuid) is
  'Verifies an entry pass and records arrival. Authoritative: the pass carries only an identifier.';

revoke all on function public.check_in_booking(text, text, uuid) from public, anon;
grant execute on function public.check_in_booking(text, text, uuid) to authenticated;
