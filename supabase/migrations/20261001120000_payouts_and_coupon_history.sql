-- ============================================================
-- BookMySpace: Customer Coupon History & Owner Settlement Policies
--
-- 1. Adds RLS policies for reading redeemed booking coupons:
--    - Customers can read coupons attached to their own bookings
--    - Administrators can read all coupon redemptions
-- 2. Adds RPC `get_customer_coupon_history` to securely return
--    the authenticated customer's redeemed promo codes and savings.
-- 3. Adds RLS insert policy for owners on `public.payouts` so
--    authenticated venue owners can submit settlement requests.
-- ============================================================

-- 1. booking_coupons RLS policies
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'booking_coupons'
      and policyname = 'booking_coupons_read_own'
  ) then
    create policy "booking_coupons_read_own" on public.booking_coupons
      for select
      using (
        exists (
          select 1 from public.bookings b
          where b.id = booking_coupons.booking_id
            and b.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'booking_coupons'
      and policyname = 'booking_coupons_admin_read'
  ) then
    create policy "booking_coupons_admin_read" on public.booking_coupons
      for select
      using (
        public.has_role(auth.uid(), 'administrator')
        or public.has_role(auth.uid(), 'super_administrator')
      );
  end if;
end
$$;

-- 2. Customer Coupon History RPC
create or replace function public.get_customer_coupon_history()
returns table (
  booking_id uuid,
  coupon_code text,
  coupon_description text,
  discount_amount numeric(12,2),
  total_amount numeric(12,2),
  venue_name text,
  booking_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  return query
  select
    b.id as booking_id,
    coalesce(c.code, 'PROMO') as coupon_code,
    coalesce(c.description, 'Promotional discount') as coupon_description,
    bc.discount_amount,
    b.total_amount,
    coalesce(v.name, 'BookMySpace Venue') as venue_name,
    b.status as booking_status,
    b.created_at
  from public.booking_coupons bc
  join public.bookings b on b.id = bc.booking_id
  left join public.coupons c on c.id = bc.coupon_id
  left join public.venues v on v.id = b.venue_id
  where b.user_id = auth.uid()
  order by b.created_at desc;
end;
$$;

revoke all on function public.get_customer_coupon_history() from public, anon;
grant execute on function public.get_customer_coupon_history() to authenticated, service_role;

-- 3. Owner Payouts RLS policies
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payouts'
      and policyname = 'payouts_owner_insert'
  ) then
    create policy "payouts_owner_insert" on public.payouts
      for insert
      with check (
        exists (
          select 1 from public.organizations o
          where o.id = org_id and o.owner_user_id = auth.uid()
        )
        and status = 'requested'
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'payouts'
      and policyname = 'payouts_admin_all'
  ) then
    create policy "payouts_admin_all" on public.payouts
      for all
      using (
        public.has_role(auth.uid(), 'administrator')
        or public.has_role(auth.uid(), 'super_administrator')
      );
  end if;
end
$$;
