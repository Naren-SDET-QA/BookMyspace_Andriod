-- Admin Payment Operations: read-only Payment Health + Transaction Ledger RPCs.
-- Strictly additive, read-only, SECURITY DEFINER, gated by public.is_platform_admin(auth.uid()).
-- Does NOT modify Razorpay checkout, webhook verification, booking confirmation,
-- payment capture, or owner approval logic. Observability only.

-- 1. Aggregate payment-health metrics for a date range.
CREATE OR REPLACE FUNCTION public.admin_get_payment_health(
  p_from timestamptz DEFAULT (now() - interval '30 days'),
  p_to timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_result jsonb;
begin
  if not public.is_platform_admin(auth.uid()) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;

  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid_date_range' using errcode = '22023';
  end if;

  if p_to - p_from > interval '366 days' then
    raise exception 'date_range_too_large' using errcode = '22023';
  end if;

  select jsonb_build_object(
    'range_from', p_from,
    'range_to', p_to,
    'total_transactions', count(*),
    'captured_count', count(*) filter (where p.status = 'captured'),
    'pending_count', count(*) filter (where p.status in ('pending', 'authorized')),
    'failed_count', count(*) filter (where p.status = 'failed'),
    'refunded_count', count(*) filter (where p.status in ('refunded', 'partially_refunded')),
    'captured_amount', coalesce(sum(p.amount) filter (where p.status = 'captured'), 0),
    'pending_amount', coalesce(sum(p.amount) filter (where p.status in ('pending', 'authorized')), 0),
    'success_rate', case
      when count(*) filter (where p.status in ('captured', 'failed')) > 0
        then round(
          100.0 * count(*) filter (where p.status = 'captured')
          / count(*) filter (where p.status in ('captured', 'failed')),
          2
        )
      else null
    end,
    'reconciliation_exceptions', (
      select count(*)
      from public.payments p2
      join public.bookings b2 on b2.id = p2.booking_id
      where p2.created_at >= p_from and p2.created_at <= p_to
        and (
          (p2.status = 'captured' and b2.status not in ('confirmed', 'completed'))
          or (p2.status = 'failed' and b2.status in ('confirmed', 'completed'))
        )
    ),
    'webhook_missing_count', (
      select count(*)
      from public.payments p3
      where p3.created_at >= p_from and p3.created_at <= p_to
        and p3.status = 'captured'
        and not exists (
          select 1 from public.webhook_events w
          where w.payload -> 'payment' -> 'entity' ->> 'order_id' = p3.provider_order_id
        )
    )
  )
  into v_result
  from public.payments p
  where p.created_at >= p_from and p.created_at <= p_to;

  return v_result;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_get_payment_health(timestamptz, timestamptz) FROM public;
REVOKE ALL ON FUNCTION public.admin_get_payment_health(timestamptz, timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_get_payment_health(timestamptz, timestamptz) TO authenticated;

-- 2. Paginated, filterable transaction ledger.
CREATE OR REPLACE FUNCTION public.admin_list_payment_transactions(
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_from timestamptz DEFAULT NULL,
  p_to timestamptz DEFAULT NULL,
  p_payment_status text DEFAULT NULL,
  p_booking_status text DEFAULT NULL,
  p_venue_id uuid DEFAULT NULL,
  p_search text DEFAULT NULL
)
RETURNS TABLE (
  payment_id uuid,
  booking_id uuid,
  booking_reference text,
  venue_id uuid,
  venue_name text,
  amount numeric,
  currency text,
  payment_status text,
  booking_status text,
  approval_status text,
  provider_order_id text,
  provider_payment_id text,
  webhook_received boolean,
  reconciliation_flag text,
  payment_created_at timestamptz,
  payment_updated_at timestamptz,
  booking_created_at timestamptz,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset integer := (v_page - 1) * v_page_size;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin(auth.uid()) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;

  if p_payment_status is not null
     and p_payment_status not in ('pending', 'authorized', 'captured', 'failed', 'refunded', 'partially_refunded') then
    raise exception 'invalid_payment_status' using errcode = '22023';
  end if;

  if p_booking_status is not null
     and p_booking_status not in (
       'held', 'pending', 'confirmed', 'completed', 'cancelled', 'refunded',
       'no_show', 'awaiting_owner_approval', 'owner_rejected', 'approval_expired'
     ) then
    raise exception 'invalid_booking_status' using errcode = '22023';
  end if;

  return query
  select
    p.id as payment_id,
    b.id as booking_id,
    b.booking_ref as booking_reference,
    b.venue_id,
    v.name as venue_name,
    p.amount,
    p.currency,
    p.status::text as payment_status,
    b.status::text as booking_status,
    case
      when b.approved_at is not null then 'approved'
      when b.rejected_at is not null then 'rejected'
      when b.approval_required then 'awaiting'
      else 'not_required'
    end as approval_status,
    p.provider_order_id,
    p.provider_payment_id,
    exists(
      select 1 from public.webhook_events w
      where w.payload -> 'payment' -> 'entity' ->> 'order_id' = p.provider_order_id
    ) as webhook_received,
    case
      when p.status = 'captured' and b.status not in ('confirmed', 'completed') then 'captured_not_confirmed'
      when p.status = 'failed' and b.status in ('confirmed', 'completed') then 'failed_but_confirmed'
      when p.status in ('pending', 'authorized') and b.status in ('confirmed', 'completed') then 'confirmed_payment_pending'
      else 'ok'
    end as reconciliation_flag,
    p.created_at as payment_created_at,
    p.updated_at as payment_updated_at,
    b.created_at as booking_created_at,
    count(*) over() as total_count
  from public.payments p
  join public.bookings b on b.id = p.booking_id
  left join public.venues v on v.id = b.venue_id
  where (p_from is null or p.created_at >= p_from)
    and (p_to is null or p.created_at <= p_to)
    and (p_payment_status is null or p.status::text = p_payment_status)
    and (p_booking_status is null or b.status::text = p_booking_status)
    and (p_venue_id is null or b.venue_id = p_venue_id)
    and (
      v_search is null
      or b.booking_ref ilike '%' || v_search || '%'
      or p.provider_order_id ilike '%' || v_search || '%'
      or p.provider_payment_id ilike '%' || v_search || '%'
    )
  order by p.created_at desc
  limit v_page_size offset v_offset;
end;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_payment_transactions(
  integer, integer, timestamptz, timestamptz, text, text, uuid, text
) FROM public;
REVOKE ALL ON FUNCTION public.admin_list_payment_transactions(
  integer, integer, timestamptz, timestamptz, text, text, uuid, text
) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_list_payment_transactions(
  integer, integer, timestamptz, timestamptz, text, text, uuid, text
) TO authenticated;
