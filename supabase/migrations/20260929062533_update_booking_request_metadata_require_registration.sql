-- Enforce the booking registration contract at the server boundary.
-- The existing client sends customer_name/customer_phone and full_name/phone;
-- those aliases remain accepted and are normalized to the canonical fields.
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

  v_name := coalesce(
    nullif(btrim(p_metadata->>'full_name'), ''),
    nullif(btrim(p_metadata->>'customer_name'), '')
  );
  v_phone := coalesce(
    nullif(btrim(p_metadata->>'mobile_number'), ''),
    nullif(btrim(p_metadata->>'customer_phone'), ''),
    nullif(btrim(p_metadata->>'phone'), '')
  );

  if v_name is null then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_CUSTOMER_NAME');
  end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_CUSTOMER_NAME');
  end if;

  if v_phone is null then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_CUSTOMER_PHONE');
  end if;
  if v_phone !~ '^[+0-9][0-9 ()-]{6,19}$' then
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

  v_metadata := p_metadata || jsonb_build_object(
    'customer_name', v_name,
    'full_name', v_name,
    'customer_phone', v_phone,
    'phone', v_phone,
    'mobile_number', v_phone
  );

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
