-- BookMySpace: server-authoritative owner approval and module configuration.
--
-- The booking lifecycle is deliberately approve-first:
--   awaiting_owner_approval -> pending -> confirmed
-- The payment webhook may only confirm the middle state after an owner
-- approval and a captured payment have both been recorded.
--
-- This migration is additive and must be applied only after the deployed
-- booking/hold tables are present. It does not grant roles or create users.

do $$
begin
  if to_regclass('public.bookings') is null
     or to_regclass('public.booking_holds') is null then
    raise exception 'owner approval migration requires public.bookings and public.booking_holds';
  end if;
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'booking_status'
  ) then
    raise exception 'owner approval migration requires public.booking_status';
  end if;
end $$;

alter table public.bookings
  add column if not exists approval_required boolean not null default true,
  add column if not exists approval_requested_at timestamptz,
  add column if not exists approval_expires_at timestamptz,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references auth.users(id),
  add column if not exists rejected_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists payment_expires_at timestamptz,
  add column if not exists request_idempotency_key uuid,
  add column if not exists approval_idempotency_key uuid;

create unique index if not exists bookings_request_idempotency_key_idx
  on public.bookings(request_idempotency_key)
  where request_idempotency_key is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'bookings'
      and c.conname = 'bookings_no_overlap'
  ) then
    alter table public.bookings add constraint bookings_no_overlap
      exclude using gist (
        venue_id with =,
        book_date with =,
        tsrange((book_date + start_time), (book_date + end_time), '[)') with &&
      ) where (status in (
        'held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed'
      ));
  end if;
end $$;

create index if not exists bookings_owner_approval_expiry_idx
  on public.bookings(status, approval_expires_at)
  where status = 'awaiting_owner_approval';

create index if not exists bookings_payment_expiry_idx
  on public.bookings(status, payment_expires_at)
  where status = 'pending';

-- Keep the legacy hold entry point safe for already-released clients. An
-- expired legacy draft is cancelled with its hold; it can never be confirmed
-- through this compatibility path.
create or replace function public.expire_stale_holds()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expired integer := 0;
begin
  update public.booking_holds
  set status = 'expired'
  where status = 'active' and expires_at <= now();
  get diagnostics v_expired = row_count;

  update public.bookings b
  set status = 'cancelled',
      cancelled_at = coalesce(b.cancelled_at, now()),
      updated_at = now(),
      metadata = coalesce(b.metadata, '{}'::jsonb) ||
        jsonb_build_object('expired_by', 'hold_expiry')
  where b.status = 'held'
    and b.hold_id in (
      select h.id from public.booking_holds h where h.status = 'expired'
    );
  return v_expired;
end;
$$;

revoke all on function public.expire_stale_holds() from public, anon, authenticated;
grant execute on function public.expire_stale_holds() to service_role;

-- The customer picker is advisory only, but it must reflect the same active
-- states as the transactional request/approve/confirm functions.
create or replace function public.available_time_slots(
  p_venue_id uuid,
  p_book_date date
)
returns table (
  slot_id uuid,
  label text,
  start_time time,
  end_time time,
  price_amount numeric,
  is_available boolean,
  reason text
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select
    s.id,
    s.label,
    s.start_time,
    s.end_time,
    s.price_amount,
    (
      s.is_active
      and not exists (
        select 1 from public.venue_blocked_dates d
        where d.venue_id = p_venue_id and d.blocked_date = p_book_date
      )
      and not exists (
        select 1 from public.booking_holds h
        where h.venue_id = p_venue_id
          and h.book_date = p_book_date
          and h.status = 'active'
          and h.expires_at > now()
          and exists (
            select 1 from public.time_slots hs
            where hs.id = h.slot_id
              and hs.start_time < s.end_time
              and hs.end_time > s.start_time
          )
      )
      and not exists (
        select 1 from public.bookings b
        where b.venue_id = p_venue_id
          and b.book_date = p_book_date
          and b.status::text in (
            'held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed'
          )
          and b.start_time < s.end_time
          and b.end_time > s.start_time
      )
    ) as is_available,
    case
      when not s.is_active then 'inactive'
      when exists (
        select 1 from public.venue_blocked_dates d
        where d.venue_id = p_venue_id and d.blocked_date = p_book_date
      ) then 'blocked'
      when exists (
        select 1 from public.booking_holds h
        where h.venue_id = p_venue_id
          and h.book_date = p_book_date
          and h.status = 'active'
          and h.expires_at > now()
          and exists (
            select 1 from public.time_slots hs
            where hs.id = h.slot_id
              and hs.start_time < s.end_time
              and hs.end_time > s.start_time
          )
      ) then 'held'
      when exists (
        select 1 from public.bookings b
        where b.venue_id = p_venue_id
          and b.book_date = p_book_date
          and b.status::text in (
            'held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed'
          )
          and b.start_time < s.end_time
          and b.end_time > s.start_time
      ) then 'booked'
      else 'available'
    end as reason
  from public.time_slots s
  where s.venue_id = p_venue_id
  order by s.start_time;
$$;

revoke all on function public.available_time_slots(uuid, date) from public;
grant execute on function public.available_time_slots(uuid, date) to anon, authenticated;

-- A receipt is created in the same transaction as confirmation. There is no
-- client-side receipt or receipt row for a rejected/expired/unpaid booking.
create table if not exists public.booking_receipts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict,
  receipt_number text not null unique,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'INR',
  issued_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

alter table public.booking_receipts enable row level security;
drop policy if exists booking_receipts_read on public.booking_receipts;
create policy booking_receipts_read on public.booking_receipts
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (
          b.user_id = auth.uid()
          or exists (
            select 1
            from public.venues v
            join public.organizations o on o.id = v.org_id
            where v.id = b.venue_id and o.owner_user_id = auth.uid()
          )
          or public.has_role(auth.uid(), 'administrator')
          or public.has_role(auth.uid(), 'super_administrator')
        )
    )
  );

revoke all on public.booking_receipts from public, anon;
grant select on public.booking_receipts to authenticated;

-- Prevent customers from manufacturing a pending booking. Customer writes
-- now enter through request_venue_booking, which locks and checks inventory.
drop policy if exists "bookings_user_insert" on public.bookings;
drop policy if exists "bookings_user_update_own" on public.bookings;
drop policy if exists bookings_customer_cancel on public.bookings;
create policy bookings_customer_cancel on public.bookings
  for update using (
    auth.uid() = user_id
    and status in ('held', 'awaiting_owner_approval', 'pending')
  )
  with check (auth.uid() = user_id and status = 'cancelled');

-- Mark stale inventory before every state transition. The scheduled call
-- below handles users who never reopen the app; these calls handle races.
create or replace function public.expire_owner_booking_requests(
  p_limit integer default 100
)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_count integer := 0;
begin
  if current_user not in ('postgres', 'service_role')
     and coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    return 0;
  end if;

  for v_booking in
    select b.id, b.user_id, b.venue_id, b.hold_id, b.status
    from public.bookings b
    where (
      b.status = 'awaiting_owner_approval'
      and b.approval_expires_at is not null
      and b.approval_expires_at <= now()
    ) or (
      b.status = 'pending'
      and b.payment_expires_at is not null
      and b.payment_expires_at <= now()
      and not exists (
        select 1 from public.payments p
        where p.booking_id = b.id and p.status = 'captured'
      )
    )
    order by b.created_at
    limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  loop
    if v_booking.status = 'awaiting_owner_approval' then
      update public.bookings
      set status = 'approval_expired',
          rejected_at = coalesce(rejected_at, now()),
          rejection_reason = coalesce(rejection_reason, 'Owner approval window expired.'),
          updated_at = now(),
          metadata = coalesce(metadata, '{}'::jsonb) ||
            jsonb_build_object('expired_by', 'server_scheduler')
      where id = v_booking.id and status = 'awaiting_owner_approval';
    else
      update public.bookings
      set status = 'cancelled',
          cancelled_at = coalesce(cancelled_at, now()),
          updated_at = now(),
          metadata = coalesce(metadata, '{}'::jsonb) ||
            jsonb_build_object('expired_by', 'payment_window_scheduler')
      where id = v_booking.id and status = 'pending';
    end if;

    if v_booking.hold_id is not null then
      update public.booking_holds
      set status = 'released'
      where id = v_booking.hold_id and status = 'active';
    end if;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      v_booking.user_id,
      case when v_booking.status = 'awaiting_owner_approval'
        then 'booking_approval_expired' else 'booking_payment_window_expired' end,
      'booking', v_booking.id,
      jsonb_build_object(
        'venue_id', v_booking.venue_id,
        'from_status', v_booking.status,
        'to_status', case when v_booking.status = 'awaiting_owner_approval'
          then 'approval_expired' else 'cancelled' end,
        'actor_role', 'server_scheduler'
      )
    );

    insert into public.notifications (user_id, title, body, type, data)
    values (
      v_booking.user_id,
      case when v_booking.status = 'awaiting_owner_approval'
        then 'Booking request expired' else 'Payment window expired' end,
      case when v_booking.status = 'awaiting_owner_approval'
        then 'The venue did not respond before the approval deadline. The slot was released.'
        else 'Payment was not completed before the payment deadline. The slot was released.' end,
      'system',
      jsonb_build_object('booking_id', v_booking.id)
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Customer entry point. Amounts from the client are deliberately ignored for
-- pricing; the active slot and venue tax are read while the inventory lock is
-- held. Coupon integration can be added later as another server-side rule.
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

  -- Serialize concurrent retries using the same customer/key pair before
  -- looking up or inserting the booking row.
  v_request_lock_key := hashtextextended(
    'booking-request:' || p_user_id::text || ':' || p_idempotency_key::text, 0
  );
  perform pg_advisory_xact_lock(v_request_lock_key);

  select b.id, b.hold_id, b.booking_ref, b.status, b.approval_expires_at,
         b.payment_expires_at, b.total_amount
  into v_existing
  from public.bookings b
  where b.user_id = p_user_id
    and b.request_idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'success', true,
      'booking_id', v_existing.id,
      'hold_id', v_existing.hold_id,
      'booking_ref', v_existing.booking_ref,
      'status', v_existing.status,
      'approval_expires_at', v_existing.approval_expires_at,
      'payment_expires_at', v_existing.payment_expires_at,
      'total_amount', v_existing.total_amount,
      'idempotent', true
    );
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  perform public.expire_stale_holds();

  select s.id, s.label, s.start_time, s.end_time, s.price_amount,
         v.tax_rate, v.org_id
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
      'success', false,
      'error_code', 'SLOT_UNAVAILABLE',
      'message', 'The selected venue, date, and time slot is no longer available.'
    );
  end if;

  v_base := round(coalesce(v_slot.price_amount, 0)::numeric, 2);
  v_tax := round(v_base * greatest(0, least(coalesce(v_slot.tax_rate, 0), 100)) / 100, 2);
  v_total := greatest(0, v_base + v_tax);
  v_approval_expires_at := v_requested_at +
    (greatest(15, least(coalesce(p_approval_minutes, 120), 1440)) * interval '1 minute');
  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

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
    jsonb_build_object('approval_mode', 'request_to_book', 'request_idempotency_key', p_idempotency_key)
  ) returning id into v_booking_id;

  select o.owner_user_id into v_owner_id
  from public.organizations o
  where o.id = v_slot.org_id and o.deleted_at is null;
  if v_owner_id is not null then
    insert into public.notifications (user_id, title, body, type, data)
    values (
      v_owner_id,
      'New booking request',
      'A customer requested your venue. Review the exact date and time before the approval deadline.',
      'system',
      jsonb_build_object('booking_id', v_booking_id, 'venue_id', p_venue_id,
        'approval_expires_at', v_approval_expires_at)
    );
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    p_user_id, 'booking_requested', 'booking', v_booking_id,
    jsonb_build_object('venue_id', p_venue_id, 'slot_id', p_slot_id,
      'book_date', p_book_date, 'from_status', null,
      'to_status', 'awaiting_owner_approval', 'actor_role', 'customer')
  );

  return jsonb_build_object(
    'success', true, 'booking_id', v_booking_id, 'hold_id', v_hold_id,
    'booking_ref', v_booking_ref, 'status', 'awaiting_owner_approval',
    'approval_expires_at', v_approval_expires_at, 'total_amount', v_total,
    'message', 'Your request was sent to the venue owner for approval.'
  );
end;
$$;

create or replace function public.approve_venue_booking(
  p_booking_id uuid,
  p_idempotency_key uuid default null,
  p_payment_minutes integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_slot record;
  v_lock_key bigint;
  v_payment_expires_at timestamptz;
begin
  select b.*, v.org_id, o.owner_user_id
  into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id and o.owner_user_id = auth.uid() and o.deleted_at is null
  for update of b;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  if v_booking.status = 'pending' and v_booking.approved_by is not null then
    return jsonb_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'pending', 'idempotent', true,
      'payment_expires_at', v_booking.payment_expires_at);
  end if;
  if v_booking.status <> 'awaiting_owner_approval' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS',
      'message', 'This request is no longer awaiting owner approval.');
  end if;
  if v_booking.approval_expires_at is null or v_booking.approval_expires_at <= now() then
    update public.bookings
    set status = 'approval_expired', rejected_at = now(),
        rejection_reason = 'Owner approval window expired.', updated_at = now()
    where id = p_booking_id and status = 'awaiting_owner_approval';
    update public.booking_holds set status = 'released'
    where id = v_booking.hold_id and status = 'active';
    return jsonb_build_object('success', false, 'error_code', 'APPROVAL_EXPIRED');
  end if;

  if v_booking.hold_id is null or not exists (
    select 1
    from public.booking_holds h
    where h.id = v_booking.hold_id
      and h.status = 'active'
      and h.expires_at > now()
  ) then
    update public.bookings
    set status = 'approval_expired', rejected_at = now(),
        rejection_reason = 'The booking hold expired before owner approval.',
        updated_at = now()
    where id = p_booking_id and status = 'awaiting_owner_approval';
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (auth.uid(), 'booking_approval_expired', 'booking', v_booking.id,
      jsonb_build_object('venue_id', v_booking.venue_id,
        'from_status', 'awaiting_owner_approval', 'to_status', 'approval_expired',
        'actor_role', 'venue_owner', 'reason', 'hold_expired'));
    insert into public.notifications (user_id, title, body, type, data)
    values (v_booking.user_id, 'Booking request expired',
      'The slot hold expired before the venue owner could approve the request. No payment was taken.',
      'system', jsonb_build_object('booking_id', v_booking.id));
    return jsonb_build_object('success', false, 'error_code', 'APPROVAL_EXPIRED');
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  select s.id, s.start_time, s.end_time
  into v_slot
  from public.time_slots s
  where s.id = v_booking.slot_id and s.venue_id = v_booking.venue_id and s.is_active = true;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'The selected time slot is no longer active.');
  end if;
  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = v_booking.venue_id and d.blocked_date = v_booking.book_date
  ) or exists (
    select 1 from public.booking_holds h
    where h.venue_id = v_booking.venue_id and h.book_date = v_booking.book_date
      and h.id <> v_booking.hold_id and h.status = 'active' and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id and s.start_time < v_slot.end_time and s.end_time > v_slot.start_time
      )
  ) or exists (
    select 1 from public.bookings b
    where b.id <> v_booking.id and b.venue_id = v_booking.venue_id
      and b.book_date = v_booking.book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'Availability changed. This request cannot be approved.');
  end if;

  v_payment_expires_at := now() +
    (greatest(15, least(coalesce(p_payment_minutes, 60), 1440)) * interval '1 minute');
  update public.bookings
  set status = 'pending', approved_at = now(), approved_by = auth.uid(),
      approval_idempotency_key = coalesce(p_idempotency_key, approval_idempotency_key),
      payment_expires_at = v_payment_expires_at, updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('approval_mode', 'request_to_book', 'approved_by', auth.uid())
  where id = v_booking.id and status = 'awaiting_owner_approval';
  update public.booking_holds
  set expires_at = v_payment_expires_at
  where id = v_booking.hold_id and status = 'active' and expires_at > now();

  insert into public.notifications (user_id, title, body, type, data)
  values (
    v_booking.user_id, 'Booking request accepted',
    'The venue owner accepted your requested date and time. Complete payment before the payment deadline.',
    'system', jsonb_build_object('booking_id', v_booking.id, 'payment_expires_at', v_payment_expires_at)
  );
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'booking_owner_approved', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'awaiting_owner_approval',
      'to_status', 'pending', 'actor_role', 'venue_owner', 'idempotency_key', p_idempotency_key)
  );
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'status', 'pending', 'payment_expires_at', v_payment_expires_at);
end;
$$;

create or replace function public.reject_venue_booking(
  p_booking_id uuid,
  p_idempotency_key uuid default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  select b.* into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id and o.owner_user_id = auth.uid() and o.deleted_at is null
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;
  if v_booking.status in ('owner_rejected', 'approval_expired', 'cancelled') then
    return jsonb_build_object('success', true, 'booking_id', v_booking.id,
      'status', v_booking.status, 'idempotent', true);
  end if;
  if v_booking.status <> 'awaiting_owner_approval' then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS');
  end if;

  update public.bookings
  set status = 'owner_rejected', rejected_at = now(), rejection_reason = coalesce(v_reason, 'Declined by venue owner.'),
      updated_at = now(), approval_idempotency_key = coalesce(p_idempotency_key, approval_idempotency_key)
  where id = v_booking.id and status = 'awaiting_owner_approval';
  update public.booking_holds set status = 'released'
  where id = v_booking.hold_id and status = 'active';
  insert into public.notifications (user_id, title, body, type, data)
  values (v_booking.user_id, 'Booking request declined',
    'The venue owner could not accept the requested date and time. No payment was taken.',
    'system', jsonb_build_object('booking_id', v_booking.id));
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'booking_owner_rejected', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'awaiting_owner_approval',
      'to_status', 'owner_rejected', 'actor_role', 'venue_owner', 'reason', v_reason,
      'idempotency_key', p_idempotency_key));
  return jsonb_build_object('success', true, 'booking_id', v_booking.id, 'status', 'owner_rejected');
end;
$$;

create or replace function public.cancel_venue_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
begin
  select b.* into v_booking from public.bookings b
  where b.id = p_booking_id and b.user_id = auth.uid()
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;
  if v_booking.status not in ('held', 'awaiting_owner_approval', 'pending') then
    return jsonb_build_object('success', false, 'error_code', 'CANNOT_CANCEL');
  end if;
  if exists (select 1 from public.payments p where p.booking_id = p_booking_id and p.status = 'captured') then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_ALREADY_CAPTURED');
  end if;

  update public.bookings
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  where id = p_booking_id;
  update public.booking_holds set status = 'released'
  where id = v_booking.hold_id and status = 'active';
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'booking_cancelled', 'booking', p_booking_id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', v_booking.status,
      'to_status', 'cancelled', 'actor_role', 'customer'));
  return jsonb_build_object('success', true, 'booking_id', p_booking_id, 'status', 'cancelled');
end;
$$;

-- Confirmation is intentionally payment + approval + live availability.
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
  v_payment record;
  v_slot record;
  v_lock_key bigint;
  v_receipt_number text;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;

  select * into v_booking from public.bookings b
  where b.id = p_booking_id and b.user_id = p_user_id
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  end if;
  if v_booking.status = 'confirmed' then
    select receipt_number into v_receipt_number
    from public.booking_receipts where booking_id = p_booking_id;
    return jsonb_build_object('success', true, 'booking_id', p_booking_id,
      'status', 'CONFIRMED', 'receipt_number', v_receipt_number, 'idempotent', true);
  end if;
  if v_booking.status <> 'pending'
     or v_booking.approved_at is null
     or v_booking.approved_by is null then
    return jsonb_build_object('success', false, 'error_code', 'OWNER_APPROVAL_REQUIRED',
      'message', 'Payment cannot confirm a booking before the venue owner approves it.');
  end if;
  if v_booking.payment_expires_at is not null and v_booking.payment_expires_at <= now() then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_WINDOW_EXPIRED');
  end if;
  if p_payment_ref is null or length(trim(p_payment_ref)) = 0 then
    return jsonb_build_object('success', false, 'error_code', 'PAYMENT_REQUIRED');
  end if;

  select p.* into v_payment from public.payments p
  where p.booking_id = p_booking_id and p.status = 'captured'
    and p.provider_payment_id = p_payment_ref
  order by p.updated_at desc limit 1;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'NO_CAPTURED_PAYMENT');
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  select s.id, s.start_time, s.end_time into v_slot
  from public.time_slots s
  where s.id = v_booking.slot_id and s.venue_id = v_booking.venue_id and s.is_active = true;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = v_booking.venue_id and d.blocked_date = v_booking.book_date
  ) or exists (
    select 1 from public.bookings b
    where b.id <> v_booking.id and b.venue_id = v_booking.venue_id
      and b.book_date = v_booking.book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object('success', false, 'error_code', 'SLOT_UNAVAILABLE');
  end if;
  if v_booking.hold_id is null or not exists (
    select 1 from public.booking_holds h
    where h.id = v_booking.hold_id and h.status = 'active' and h.expires_at > now()
  ) then
    return jsonb_build_object('success', false, 'error_code', 'HOLD_EXPIRED');
  end if;

  v_receipt_number := 'BMS-R-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.booking_receipts (booking_id, payment_id, receipt_number, amount, currency, metadata)
  values (v_booking.id, v_payment.id, v_receipt_number, v_booking.total_amount,
    v_booking.currency, jsonb_build_object('issued_after', 'captured_payment_and_owner_approval'))
  on conflict (booking_id) do nothing;

  update public.booking_holds set status = 'confirmed' where id = v_booking.hold_id;
  update public.bookings
  set status = 'confirmed', confirmed_at = now(), updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref, 'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc')
  where id = v_booking.id and status = 'pending';

  select receipt_number into v_receipt_number
  from public.booking_receipts where booking_id = v_booking.id;
  insert into public.notifications (user_id, title, body, type, data)
  values (v_booking.user_id, 'Booking confirmed',
    'Your owner-approved payment was captured and the booking is confirmed. Your receipt is ready.',
    'booking_confirmed', jsonb_build_object('booking_id', v_booking.id,
      'receipt_number', v_receipt_number));
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (v_booking.user_id, 'booking_confirmed', 'booking', v_booking.id,
    jsonb_build_object('venue_id', v_booking.venue_id, 'from_status', 'pending',
      'to_status', 'confirmed', 'actor_role', 'payment_webhook',
      'payment_id', v_payment.id, 'receipt_number', v_receipt_number));
  return jsonb_build_object('success', true, 'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref, 'status', 'CONFIRMED',
    'receipt_number', v_receipt_number, 'confirmed_at', now());
end;
$$;

revoke all on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) from public, anon;
revoke all on function public.approve_venue_booking(uuid, uuid, integer) from public, anon;
revoke all on function public.reject_venue_booking(uuid, uuid, text) from public, anon;
revoke all on function public.cancel_venue_booking(uuid) from public, anon;
revoke all on function public.confirm_venue_booking(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.expire_owner_booking_requests(integer) from public, anon, authenticated;
grant execute on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) to authenticated;
grant execute on function public.approve_venue_booking(uuid, uuid, integer) to authenticated;
grant execute on function public.reject_venue_booking(uuid, uuid, text) to authenticated;
grant execute on function public.cancel_venue_booking(uuid) to authenticated;
grant execute on function public.confirm_venue_booking(uuid, uuid, text, text) to service_role;
grant execute on function public.expire_owner_booking_requests(integer) to service_role;

-- The old two-argument helper predates captured-payment verification and
-- could otherwise confirm a pending row from a client RPC. Keep it only for
-- trusted server-side legacy jobs; all client confirmation uses the guarded
-- confirm_venue_booking function above.
revoke all on function public.confirm_booking(uuid, text) from public, anon, authenticated;
grant execute on function public.confirm_booking(uuid, text) to service_role;

-- Supabase projects with pg_cron get automatic server-side expiry. Projects
-- without it can invoke the same service-role RPC from their scheduler.
do $$
declare
  v_job record;
begin
  if to_regnamespace('cron') is not null then
    begin
      for v_job in
        select jobid from cron.job
        where jobname = 'bookmyspace-expire-owner-requests'
      loop
        perform cron.unschedule(v_job.jobid);
      end loop;
      perform cron.schedule(
        'bookmyspace-expire-owner-requests',
        '*/5 * * * *',
        'select public.expire_owner_booking_requests(100);'
      );
    exception when others then
      -- An existing job is harmless; the RPC remains available to the
      -- configured scheduler and all user-triggered transitions still expire.
      null;
    end;
  end if;
end $$;

-- -------------------------------------------------------------------------
-- Plug-and-play module configuration. This extends the existing feature_flags
-- table; it does not create a parallel flag or authorization system.
-- -------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.feature_flags') is not null then
    alter table public.feature_flags
      add column if not exists updated_by uuid references auth.users(id);
  end if;
end $$;

insert into public.feature_flags (key, enabled, platforms, config)
values
  ('analytics', true, array['ios', 'android', 'web'], '{}'::jsonb),
  ('integrations', true, array['ios', 'android', 'web'], '{}'::jsonb),
  ('referrals', false, array['ios', 'android', 'web'], '{}'::jsonb)
on conflict (key) do nothing;

-- Customer and owner clients can react to server transitions without polling.
-- Realtime is added only when the standard Supabase publication exists.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_rel pr
       join pg_class c on c.oid = pr.prrelid
       join pg_namespace n on n.oid = c.relnamespace
       join pg_publication p on p.oid = pr.prpubid
       where p.pubname = 'supabase_realtime'
         and n.nspname = 'public'
         and c.relname = 'bookings'
     ) then
    alter publication supabase_realtime add table public.bookings;
  end if;
end $$;

create or replace function public.validate_feature_flag_config()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_platform text;
begin
  if new.key not in (
    'gps', 'pin_search', 'offers', 'events', 'courses', 'reviews', 'favorites',
    'payments', 'notifications', 'support', 'analytics', 'integrations', 'referrals'
  ) then
    raise exception 'unsupported_module';
  end if;
  if new.key in ('payments', 'notifications', 'courses') and new.enabled is false then
    raise exception 'core_module_cannot_be_disabled';
  end if;
  if new.platforms is null or cardinality(new.platforms) = 0 then
    raise exception 'module_requires_platform';
  end if;
  foreach v_platform in array new.platforms loop
    if v_platform not in ('ios', 'android', 'web') then
      raise exception 'unsupported_module_platform';
    end if;
  end loop;
  if new.config is null or jsonb_typeof(new.config) <> 'object' then
    raise exception 'module_config_must_be_object';
  end if;
  if new.config ? 'display_title' and
     (jsonb_typeof(new.config->'display_title') <> 'string'
      or length(new.config->>'display_title') not between 1 and 80) then
    raise exception 'invalid_display_title';
  end if;
  if new.config ? 'max_items' and
     (jsonb_typeof(new.config->'max_items') <> 'number'
      or (new.config->>'max_items')::numeric not between 1 and 100
      or (new.config->>'max_items')::numeric <> trunc((new.config->>'max_items')::numeric)) then
    raise exception 'invalid_max_items';
  end if;
  if new.config ? 'reward_amount' and
     (jsonb_typeof(new.config->'reward_amount') <> 'number'
      or (new.config->>'reward_amount')::numeric not between 0 and 100000) then
    raise exception 'invalid_reward_amount';
  end if;
  if new.config ? 'expiry_days' and
     (jsonb_typeof(new.config->'expiry_days') <> 'number'
      or (new.config->>'expiry_days')::numeric not between 1 and 365
      or (new.config->>'expiry_days')::numeric <> trunc((new.config->>'expiry_days')::numeric)) then
    raise exception 'invalid_expiry_days';
  end if;
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

create or replace function public.audit_feature_flag_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null then
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(), 'feature_flag_updated', 'feature_flag', null,
      jsonb_build_object('key', new.key, 'enabled', new.enabled,
        'platforms', new.platforms, 'config', new.config)
    );
  end if;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.feature_flags') is not null then
    drop trigger if exists feature_flags_validate_config on public.feature_flags;
    create trigger feature_flags_validate_config
      before insert or update on public.feature_flags
      for each row execute function public.validate_feature_flag_config();
    drop trigger if exists feature_flags_audit_change on public.feature_flags;
    create trigger feature_flags_audit_change
      after insert or update on public.feature_flags
      for each row execute function public.audit_feature_flag_change();
  end if;
end $$;
