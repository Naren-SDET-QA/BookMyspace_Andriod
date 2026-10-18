-- B5: per-venue payment policy. Defaults preserve the current online-only
-- checkout, while owners may explicitly enable pay-at-venue and disable a
-- payment method without changing the app or trusting the client.

alter table public.venues
  add column if not exists allow_pay_at_venue boolean not null default false,
  add column if not exists disabled_payment_methods text[] not null default '{}';

alter table public.venues
  drop constraint if exists venues_disabled_payment_methods_check;
alter table public.venues
  add constraint venues_disabled_payment_methods_check
  check (disabled_payment_methods <@ array['razorpay', 'pay_at_venue']::text[]);

create or replace function public.get_venue_payment_rules(p_venue_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_venue public.venues;
begin
  select * into v_venue
    from public.venues
   where id = p_venue_id and is_active = true and deleted_at is null;
  if not found then
    raise exception 'venue_not_found' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'allow_pay_at_venue', v_venue.allow_pay_at_venue
      and not ('pay_at_venue' = any(v_venue.disabled_payment_methods)),
    'online_enabled', not ('razorpay' = any(v_venue.disabled_payment_methods)),
    'disabled_payment_methods', to_jsonb(v_venue.disabled_payment_methods)
  );
end;
$$;

revoke all on function public.get_venue_payment_rules(uuid) from public, anon;
grant execute on function public.get_venue_payment_rules(uuid) to authenticated;

-- Keep the existing pay-at-venue transition server-authoritative and add the
-- venue-level policy check. The operation remains idempotent.
create or replace function public.select_pay_at_venue(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  v public.venues;
  existing_payment public.payments;
  new_payment public.payments;
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  select * into b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;
  select * into v from public.venues where id = b.venue_id;
  if not found or not v.allow_pay_at_venue
     or 'pay_at_venue' = any(v.disabled_payment_methods) then
    raise exception 'pay_at_venue_disabled' using errcode = '55000';
  end if;

  select * into existing_payment from public.payments
   where booking_id = p_booking_id and provider = 'pay_at_venue'
   order by created_at desc limit 1;
  if found then
    return jsonb_build_object(
      'status', b.status, 'booking_id', b.id,
      'payment_id', existing_payment.id, 'idempotent', true
    );
  end if;

  if b.status <> 'pending' then
    raise exception 'invalid_booking_state' using errcode = '55000';
  end if;
  if exists (select 1 from public.payments where booking_id = p_booking_id) then
    raise exception 'payment_in_progress' using errcode = '55000';
  end if;

  insert into public.payments (
    booking_id, user_id, provider, amount, currency, status, method,
    is_refundable, metadata
  ) values (
    p_booking_id, auth.uid(), 'pay_at_venue', b.total_amount, b.currency,
    'authorized', 'pay_at_venue', false,
    jsonb_build_object('pay_at_venue', true)
  ) returning * into new_payment;

  update public.bookings
     set status = 'pending_owner_approval', updated_at = now()
   where id = p_booking_id and status = 'pending';

  return jsonb_build_object(
    'status', 'pending_owner_approval', 'booking_id', b.id,
    'payment_id', new_payment.id
  );
end;
$$;

revoke all on function public.select_pay_at_venue(uuid) from public, anon;
grant execute on function public.select_pay_at_venue(uuid) to authenticated;
