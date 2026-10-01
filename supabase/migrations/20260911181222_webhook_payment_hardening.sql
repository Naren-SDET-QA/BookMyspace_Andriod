-- BookMySpace — Payment webhook hardening.
--
-- This migration is intentionally not applied by this batch. It is required
-- before deploying the matching Edge Function changes.

-- The webhook has no end-user JWT. Allow only the internal service-role
-- execution path to pass the user ID supplied from the service-side payment
-- row; normal authenticated callers must still match auth.uid().
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
  v_lock_key bigint;
  v_service_role boolean :=
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role';
begin
  if not v_service_role and (
    auth.uid() is null or p_user_id is distinct from auth.uid()
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'UNAUTHORIZED',
      'message', 'Authenticated user mismatch.'
    );
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and user_id = p_user_id;
  if not found then
    return jsonb_build_object(
      'success', false,
      'error_code', 'BOOKING_NOT_FOUND',
      'message', 'Booking record not found or unauthorized.'
    );
  end if;

  if v_booking.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'booking_id', v_booking.id,
      'booking_ref', v_booking.booking_ref,
      'status', 'CONFIRMED',
      'message', 'Booking is already confirmed.'
    );
  end if;

  if v_booking.status not in ('held', 'pending') then
    return jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATUS',
      'message', 'Booking cannot be confirmed from status: ' || v_booking.status
    );
  end if;

  v_lock_key := hashtextextended(
    v_booking.venue_id::text || ':' || v_booking.book_date::text,
    0
  );
  perform pg_advisory_xact_lock(v_lock_key);

  if v_booking.hold_id is not null then
    if exists (
      select 1 from public.booking_holds
      where id = v_booking.hold_id and status = 'expired'
    ) then
      return jsonb_build_object(
        'success', false,
        'error_code', 'HOLD_EXPIRED',
        'message', 'The booking hold expired prior to payment confirmation.'
      );
    end if;

    update public.booking_holds
    set status = 'confirmed'
    where id = v_booking.hold_id;
  end if;

  update public.bookings
  set status = 'confirmed',
      confirmed_at = now(),
      updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref,
        'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc'
      )
  where id = p_booking_id and user_id = p_user_id;

  return jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref,
    'status', 'CONFIRMED',
    'confirmed_at', now(),
    'message', 'Booking confirmed successfully.'
  );
end;
$$;

-- A failed webhook must remain retryable. A processed event remains a
-- duplicate, while an existing unprocessed event is refreshed and retried.
create or replace function public.register_webhook_event(
  p_provider text,
  p_event_id text,
  p_event_type text,
  p_payload jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_processed boolean;
begin
  select processed into v_processed
  from public.webhook_events
  where provider = p_provider and event_id = p_event_id
  for update;

  if found then
    if v_processed then
      return false;
    end if;

    update public.webhook_events
    set event_type = p_event_type, payload = p_payload
    where provider = p_provider and event_id = p_event_id;
    return true;
  end if;

  insert into public.webhook_events (provider, event_id, event_type, payload)
  values (p_provider, p_event_id, p_event_type, p_payload);
  return true;
end;
$$;
