-- B4: optional advance payment plans. Full payment remains the default.

alter table public.venues
  add column if not exists advance_payment_enabled boolean not null default false,
  add column if not exists advance_percentage numeric(5,2) not null default 100,
  add column if not exists minimum_advance_amount numeric(12,2) not null default 200;

alter table public.venues
  drop constraint if exists venues_advance_percentage_check;
alter table public.venues
  add constraint venues_advance_percentage_check
  check (advance_percentage > 0 and advance_percentage <= 100);

alter table public.venues
  drop constraint if exists venues_minimum_advance_amount_check;
alter table public.venues
  add constraint venues_minimum_advance_amount_check
  check (minimum_advance_amount >= 0);

alter table public.bookings
  add column if not exists payment_plan text not null default 'full',
  add column if not exists advance_percentage numeric(5,2),
  add column if not exists advance_amount numeric(12,2) not null default 0,
  add column if not exists balance_due numeric(12,2) not null default 0,
  add column if not exists balance_collected_at timestamptz,
  add column if not exists balance_collected_by uuid references auth.users(id);

alter table public.bookings
  drop constraint if exists bookings_payment_plan_check;
alter table public.bookings
  add constraint bookings_payment_plan_check
  check (payment_plan in ('full', 'advance'));

create or replace function public.calculate_booking_payment_quote(
  p_booking_id uuid,
  p_payment_plan text default 'full'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  v public.venues;
  v_plan text := lower(coalesce(trim(p_payment_plan), 'full'));
  v_advance numeric(12,2);
  v_total numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if v_plan not in ('full', 'advance') then
    raise exception 'invalid_payment_plan' using errcode = '22023';
  end if;

  select * into b from public.bookings where id = p_booking_id;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  select * into v from public.venues where id = b.venue_id;
  if not found then raise exception 'venue_not_found' using errcode = 'P0002'; end if;
  if b.user_id is distinct from auth.uid()
     and not exists (
       select 1 from public.organizations o
        where o.id = v.org_id and o.owner_user_id = auth.uid()
     )
     and not (public.has_role(auth.uid(), 'administrator')
       or public.has_role(auth.uid(), 'super_administrator')) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_total := round(greatest(0, b.total_amount), 2);
  if v_plan = 'advance' then
    if not v.advance_payment_enabled then
      raise exception 'advance_payment_disabled' using errcode = '55000';
    end if;
    v_advance := greatest(
      round(v_total * v.advance_percentage / 100, 2),
      v.minimum_advance_amount
    );
    v_advance := least(v_total, v_advance);
  else
    v_advance := v_total;
  end if;

  return jsonb_build_object(
    'booking_id', b.id,
    'currency', b.currency,
    'payment_plan', v_plan,
    'full_amount', v_total,
    'advance_percentage', case when v_plan = 'advance' then v.advance_percentage else 100 end,
    'advance_amount', v_advance,
    'balance_due', greatest(0, round(v_total - v_advance, 2)),
    'advance_enabled', v.advance_payment_enabled,
    'minimum_advance_amount', v.minimum_advance_amount
  );
end;
$$;

revoke all on function public.calculate_booking_payment_quote(uuid, text)
  from public, anon;
grant execute on function public.calculate_booking_payment_quote(uuid, text)
  to authenticated;

create or replace function public.mark_booking_balance_collected(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  v public.venues;
  v_balance numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  select * into v from public.venues where id = b.venue_id;
  if not found or not exists (
    select 1 from public.organizations o
     where o.id = v.org_id and o.owner_user_id = auth.uid()
  ) then
    raise exception 'owner_required' using errcode = '42501';
  end if;
  if b.status not in ('confirmed', 'completed') then
    raise exception 'booking_not_confirmed' using errcode = '55000';
  end if;
  v_balance := greatest(0, coalesce(b.balance_due, 0));
  update public.bookings
     set balance_due = 0,
         balance_collected_at = coalesce(balance_collected_at, now()),
         balance_collected_by = coalesce(balance_collected_by, auth.uid()),
         updated_at = now()
   where id = b.id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'booking_balance_collected', 'booking', b.id,
    jsonb_build_object('amount', v_balance, 'currency', b.currency));
  return jsonb_build_object('booking_id', b.id, 'collected_amount', v_balance);
end;
$$;

revoke all on function public.mark_booking_balance_collected(uuid) from public, anon;
grant execute on function public.mark_booking_balance_collected(uuid) to authenticated;
