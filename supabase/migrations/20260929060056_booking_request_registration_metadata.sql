-- Store customer-entered booking registration details on an existing request.
-- The booking request and payment state remain server-authoritative; this RPC
-- only lets the authenticated booking owner add registration metadata while
-- the request is still mutable.
create or replace function public.update_booking_request_metadata(
  p_booking_id uuid,
  p_metadata jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking public.bookings;
  v_metadata jsonb;
  v_name text;
  v_phone text;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_METADATA');
  end if;

  v_name := nullif(btrim(coalesce(
    p_metadata->>'customer_name', p_metadata->>'full_name', ''
  )), '');
  v_phone := nullif(btrim(coalesce(
    p_metadata->>'customer_phone', p_metadata->>'phone', ''
  )), '');

  if v_name is not null and (char_length(v_name) < 2 or char_length(v_name) > 120) then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_CUSTOMER_NAME');
  end if;
  if v_phone is not null and v_phone !~ '^[+0-9][0-9 ()-]{6,19}$' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_CUSTOMER_PHONE');
  end if;

  select *
    into v_booking
    from public.bookings
   where id = p_booking_id
     and user_id = auth.uid()
   for update;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;

  if v_booking.status not in ('held', 'awaiting_owner_approval', 'pending') then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_EDITABLE');
  end if;

  v_metadata := p_metadata;
  if v_name is not null then
    v_metadata := v_metadata || jsonb_build_object(
      'customer_name', v_name,
      'full_name', v_name
    );
  end if;
  if v_phone is not null then
    v_metadata := v_metadata || jsonb_build_object(
      'customer_phone', v_phone,
      'phone', v_phone
    );
  end if;

  update public.bookings
     set metadata = coalesce(metadata, '{}'::jsonb) || v_metadata,
         updated_at = now()
   where id = v_booking.id;

  return jsonb_build_object('success', true, 'booking_id', v_booking.id);
end;
$$;

revoke all on function public.update_booking_request_metadata(uuid, jsonb)
  from public, anon;
grant execute on function public.update_booking_request_metadata(uuid, jsonb)
  to authenticated;
