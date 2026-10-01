-- B9: platform commission. The admin-set percent lives in the global
-- module_feature_configs row 'platform_finance' (metadata.commission_percent).
-- When a booking becomes confirmed the commission is written once to
-- platform_commissions at the rate in force at that moment; a later
-- cancellation or refund marks it reversed (the row is kept for audit).

alter table public.platform_commissions
  add column if not exists reversed_at timestamptz,
  add column if not exists base_amount numeric(12,2);

create unique index if not exists platform_commissions_booking_uidx
  on public.platform_commissions (booking_id);

create or replace function public.platform_commission_percent()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select greatest(0, least(100, coalesce((
    select (m.metadata ->> 'commission_percent')::numeric
      from public.module_feature_configs m
     where m.module_key = 'platform_finance' and m.venue_id is null
     order by m.updated_at desc nulls last
     limit 1
  ), 0)));
$$;

create or replace function public.record_platform_commission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rate numeric;
  v_org uuid;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    v_rate := public.platform_commission_percent();
    select v.org_id into v_org from public.venues v where v.id = new.venue_id;
    insert into public.platform_commissions (
      booking_id, org_id, commission_rate, commission_amount, base_amount
    ) values (
      new.id,
      v_org,
      v_rate,
      round(coalesce(new.total_amount, 0) * v_rate / 100, 2),
      coalesce(new.total_amount, 0)
    )
    on conflict (booking_id) do nothing;
  elsif new.status in ('cancelled', 'refunded')
        and old.status is distinct from new.status then
    update public.platform_commissions
       set reversed_at = coalesce(reversed_at, now())
     where booking_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_record_platform_commission on public.bookings;
create trigger bookings_record_platform_commission
  after update of status on public.bookings
  for each row execute function public.record_platform_commission();

revoke all on function public.record_platform_commission() from public, anon, authenticated;
grant execute on function public.platform_commission_percent() to authenticated;

-- Admin summary: commission earned net of reversals in a date range.
create or replace function public.admin_commission_summary(
  p_from timestamptz default now() - interval '30 days',
  p_to timestamptz default now()
)
returns table (bookings bigint, gross numeric, commission numeric, reversed numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin(auth.uid()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return query
    select count(*) filter (where c.reversed_at is null),
           coalesce(sum(c.base_amount) filter (where c.reversed_at is null), 0),
           coalesce(sum(c.commission_amount) filter (where c.reversed_at is null), 0),
           coalesce(sum(c.commission_amount) filter (where c.reversed_at is not null), 0)
      from public.platform_commissions c
     where c.created_at >= p_from and c.created_at < p_to;
end;
$$;

revoke all on function public.admin_commission_summary(timestamptz, timestamptz) from public, anon;
grant execute on function public.admin_commission_summary(timestamptz, timestamptz) to authenticated;

insert into public.module_feature_configs (module_key, venue_id, metadata)
select 'platform_finance', null, jsonb_build_object('commission_percent', 0)
where not exists (
  select 1 from public.module_feature_configs
   where module_key = 'platform_finance' and venue_id is null
);
