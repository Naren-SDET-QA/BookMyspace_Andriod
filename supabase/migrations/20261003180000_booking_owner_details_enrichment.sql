-- ============================================================
-- BookMySpace — Migration 20261003180000:
-- Enrich booking requests and venues with host/owner details and email.
-- ============================================================

-- 1. Helper to retrieve owner and host organization contact for a booking.
create or replace function public.get_booking_owner_details(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_venue record;
  v_org record;
  v_owner record;
  v_profile record;
  v_owner_name text := 'Venue Owner';
  v_owner_email text := '';
  v_owner_phone text := '';
  v_org_name text := '';
begin
  select b.id, b.user_id, b.venue_id, b.booking_ref, b.status, b.approval_expires_at, b.metadata
    into v_booking
    from public.bookings b
   where b.id = p_booking_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Booking not found');
  end if;

  select v.id, v.name as venue_name, v.org_id, v.city
    into v_venue
    from public.venues v
   where v.id = v_booking.venue_id;

  select o.id, o.name as org_name, o.owner_user_id
    into v_org
    from public.organizations o
   where o.id = v_venue.org_id;

  -- Ensure caller is the booking customer, the venue owner, or an administrator
  if auth.uid() is not null
     and auth.uid() is distinct from v_booking.user_id
     and auth.uid() is distinct from v_org.owner_user_id
     and not exists (
       select 1 from public.user_roles r
        where r.user_id = auth.uid()
          and r.role in ('administrator', 'super_administrator')
          and r.revoked_at is null
     ) then
    return jsonb_build_object('success', false, 'message', 'Unauthorized');
  end if;

  if v_org.owner_user_id is not null then
    select op.name, op.email into v_owner
      from public.owner_profiles op
     where op.user_id = v_org.owner_user_id;

    select p.full_name, p.email, p.phone into v_profile
      from public.profiles p
     where p.id = v_org.owner_user_id;

    v_owner_name := coalesce(v_owner.name, v_profile.full_name, v_org.org_name, 'Venue Owner');
    v_owner_email := coalesce(v_owner.email, v_profile.email, '');
    v_owner_phone := coalesce(v_profile.phone, '');
  end if;

  v_org_name := coalesce(v_org.org_name, '');
  if (v_owner_email is null or v_owner_email = '') and (v_booking.metadata->>'owner_email') is not null then
    v_owner_email := v_booking.metadata->>'owner_email';
  end if;
  if (v_owner_name is null or v_owner_name = '' or v_owner_name = 'Venue Owner') and (v_booking.metadata->>'owner_name') is not null then
    v_owner_name := v_booking.metadata->>'owner_name';
  end if;

  return jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref,
    'venue_name', v_venue.venue_name,
    'org_name', v_org_name,
    'owner_name', v_owner_name,
    'owner_email', v_owner_email,
    'owner_phone', v_owner_phone
  );
end;
$$;

revoke all on function public.get_booking_owner_details(uuid) from public, anon;
grant execute on function public.get_booking_owner_details(uuid) to authenticated;

-- 2. Helper to retrieve owner and host organization contact for a venue.
create or replace function public.get_venue_owner_details(p_venue_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue record;
  v_org record;
  v_owner record;
  v_profile record;
  v_owner_name text := 'Venue Owner';
  v_owner_email text := '';
  v_owner_phone text := '';
  v_org_name text := '';
begin
  select v.id, v.name as venue_name, v.org_id, v.city
    into v_venue
    from public.venues v
   where v.id = p_venue_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Venue not found');
  end if;

  select o.id, o.name as org_name, o.owner_user_id
    into v_org
    from public.organizations o
   where o.id = v_venue.org_id;

  if v_org.owner_user_id is not null then
    select op.name, op.email into v_owner
      from public.owner_profiles op
     where op.user_id = v_org.owner_user_id;

    select p.full_name, p.email, p.phone into v_profile
      from public.profiles p
     where p.id = v_org.owner_user_id;

    v_owner_name := coalesce(v_owner.name, v_profile.full_name, v_org.org_name, 'Venue Owner');
    v_owner_email := coalesce(v_owner.email, v_profile.email, '');
    v_owner_phone := coalesce(v_profile.phone, '');
  end if;

  v_org_name := coalesce(v_org.org_name, '');

  return jsonb_build_object(
    'success', true,
    'venue_id', v_venue.id,
    'venue_name', v_venue.venue_name,
    'org_name', v_org_name,
    'owner_name', v_owner_name,
    'owner_email', v_owner_email,
    'owner_phone', v_owner_phone
  );
end;
$$;

revoke all on function public.get_venue_owner_details(uuid) from public, anon;
grant execute on function public.get_venue_owner_details(uuid) to authenticated, anon;

-- 3. Update request_venue_booking to enrich booking metadata and response with owner details.
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
  v_org_name text := '';
  v_owner_name text := 'Venue Owner';
  v_owner_email text := '';
  v_owner_phone text := '';
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
         b.payment_expires_at, b.total_amount, b.metadata
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
      'total_amount', v_existing.total_amount,
      'owner_name', coalesce(v_existing.metadata->>'owner_name', ''),
      'owner_email', coalesce(v_existing.metadata->>'owner_email', ''),
      'org_name', coalesce(v_existing.metadata->>'org_name', ''),
      'idempotent', true
    );
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  perform public.expire_stale_holds();

  select s.id, s.label, s.start_time, s.end_time, v.tax_rate, v.org_id, v.name as venue_name
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

  v_base := public.calculate_venue_base_price(p_venue_id, p_slot_id, p_book_date);
  v_tax := round(v_base * greatest(0, least(coalesce(v_slot.tax_rate, 0), 100)) / 100, 2);
  v_total := greatest(0, v_base + v_tax);
  v_approval_expires_at := v_requested_at +
    (greatest(15, least(coalesce(p_approval_minutes, 120), 1440)) * interval '1 minute');
  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  -- Look up owner details for this venue
  select o.owner_user_id, coalesce(o.name, '') into v_owner_id, v_org_name
    from public.organizations o
   where o.id = v_slot.org_id and o.deleted_at is null;

  if v_owner_id is not null then
    select op.name, op.email into v_owner_name, v_owner_email
      from public.owner_profiles op
     where op.user_id = v_owner_id;

    select p.phone into v_owner_phone
      from public.profiles p
     where p.id = v_owner_id;

    if v_owner_name is null or v_owner_name = '' then
      select p.full_name, p.email into v_owner_name, v_owner_email
        from public.profiles p
       where p.id = v_owner_id;
    end if;
  end if;

  if v_owner_name is null or v_owner_name = '' then
    v_owner_name := coalesce(nullif(v_org_name, ''), 'Venue Owner');
  end if;

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
    jsonb_build_object(
      'approval_mode', 'request_to_book',
      'request_idempotency_key', p_idempotency_key,
      'owner_name', v_owner_name,
      'owner_email', coalesce(v_owner_email, ''),
      'owner_phone', coalesce(v_owner_phone, ''),
      'org_name', coalesce(v_org_name, '')
    )
  ) returning id into v_booking_id;

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
      'to_status', 'awaiting_owner_approval', 'actor_role', 'customer',
      'dynamic_pricing', true,
      'owner_email', v_owner_email)
  );

  return jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'hold_id', v_hold_id,
    'booking_ref', v_booking_ref,
    'status', 'awaiting_owner_approval',
    'approval_expires_at', v_approval_expires_at,
    'total_amount', v_total,
    'owner_name', v_owner_name,
    'owner_email', v_owner_email,
    'owner_phone', v_owner_phone,
    'org_name', v_org_name,
    'message', 'Your request was sent to the venue owner (' || v_owner_name || ') for approval.'
  );
end;
$$;

revoke all on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  from public, anon;
grant execute on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  to authenticated;
