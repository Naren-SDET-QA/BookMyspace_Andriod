-- ============================================================
-- BookMySpace — Gap closure: analytics RLS, support resolve,
-- storage, availability tables, and authorized RPCs.
--
-- Idempotent against the hosted schema. Does not disable RLS.
-- SECURITY DEFINER functions set a safe search_path and check
-- the caller's actual user_roles row.
-- ============================================================

-- ------------------------------------------------------------
-- Ensure availability tables exist (hosted may already have them)
-- ------------------------------------------------------------
create table if not exists public.time_slots (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  label text not null,
  start_time time not null,
  end_time time not null,
  price_amount numeric(12,2) not null default 0 check (price_amount >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time > start_time)
);

create index if not exists idx_time_slots_venue on public.time_slots(venue_id, is_active);

create table if not exists public.venue_blocked_dates (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  blocked_date date not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (venue_id, blocked_date)
);

create index if not exists idx_blocked_dates_venue
  on public.venue_blocked_dates(venue_id, blocked_date);

alter table public.venue_blocked_dates
  add column if not exists reason text;

alter table public.venue_images
  add column if not exists media_kind text;

alter table public.audit_logs
  add column if not exists actor_id uuid;

alter table public.support_tickets
  add column if not exists admin_id uuid references auth.users(id);

alter table public.support_tickets
  add column if not exists admin_reply text;

alter table public.analytics_events enable row level security;
alter table public.time_slots enable row level security;
alter table public.venue_blocked_dates enable row level security;
alter table public.support_tickets enable row level security;
alter table public.audit_logs enable row level security;
alter table public.crash_reports enable row level security;

-- ------------------------------------------------------------
-- Staff / owner helpers (invoker; used by RLS and definer RPCs)
-- ------------------------------------------------------------
create or replace function public.is_platform_admin(uid uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select public.has_role(uid, 'administrator'::public.user_role)
      or public.has_role(uid, 'super_administrator'::public.user_role);
$$;

create or replace function public.is_support_staff(uid uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select public.is_platform_admin(uid)
      or public.has_role(uid, 'support_agent'::public.user_role);
$$;

create or replace function public.owns_venue(uid uuid, p_venue_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.venues v
    join public.organizations o on o.id = v.org_id
    where v.id = p_venue_id
      and o.owner_user_id = uid
      and o.deleted_at is null
      and v.deleted_at is null
  );
$$;

revoke all on function public.is_platform_admin(uuid) from public;
revoke all on function public.is_support_staff(uuid) from public;
revoke all on function public.owns_venue(uuid, uuid) from public;
grant execute on function public.is_platform_admin(uuid) to authenticated;
grant execute on function public.is_support_staff(uuid) to authenticated;
grant execute on function public.owns_venue(uuid, uuid) to authenticated;

-- ------------------------------------------------------------
-- Analytics: replace owner_profiles-based read with role + ownership
-- ------------------------------------------------------------
drop policy if exists "analytics_admin_read" on public.analytics_events;
drop policy if exists "analytics_owner_read" on public.analytics_events;
drop policy if exists "analytics_insert_own" on public.analytics_events;

create policy "analytics_insert_own" on public.analytics_events
  for insert
  with check (auth.uid() is not null and auth.uid() = user_id);

create policy "analytics_admin_read" on public.analytics_events
  for select
  using (public.is_platform_admin(auth.uid()));

create policy "analytics_owner_read" on public.analytics_events
  for select
  using (
    public.has_role(auth.uid(), 'venue_owner'::public.user_role)
    and (
      user_id = auth.uid()
      or (
        properties ? 'venue_id'
        and (properties->>'venue_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        and public.owns_venue(auth.uid(), (properties->>'venue_id')::uuid)
      )
    )
  );

drop policy if exists "crash_reports_admin_read" on public.crash_reports;
create policy "crash_reports_admin_read" on public.crash_reports
  for select
  using (public.is_platform_admin(auth.uid()));

create or replace function public.list_authorized_analytics_events(p_limit integer default 50)
returns setof public.analytics_events
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if public.is_platform_admin(v_uid) then
    return query
      select e.*
      from public.analytics_events e
      order by e.created_at desc
      limit v_limit;
    return;
  end if;

  if public.has_role(v_uid, 'venue_owner'::public.user_role) then
    return query
      select e.*
      from public.analytics_events e
      where e.user_id = v_uid
         or (
           e.properties ? 'venue_id'
           and (e.properties->>'venue_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
           and public.owns_venue(v_uid, (e.properties->>'venue_id')::uuid)
         )
      order by e.created_at desc
      limit v_limit;
    return;
  end if;

  raise exception 'not authorized' using errcode = '42501';
end;
$$;

revoke all on function public.list_authorized_analytics_events(integer) from public;
grant execute on function public.list_authorized_analytics_events(integer) to authenticated;

-- ------------------------------------------------------------
-- Support tickets: staff read via user_roles; resolve via RPC
-- ------------------------------------------------------------
drop policy if exists "tickets_admin_read" on public.support_tickets;
drop policy if exists "tickets_admin_write" on public.support_tickets;
drop policy if exists "tickets_staff_read" on public.support_tickets;

create policy "tickets_staff_read" on public.support_tickets
  for select
  using (public.is_support_staff(auth.uid()));

drop policy if exists "audit_admin_read" on public.audit_logs;
drop policy if exists "audit_admin_insert" on public.audit_logs;

create policy "audit_admin_read" on public.audit_logs
  for select
  using (public.is_platform_admin(auth.uid()));

drop function if exists public.mark_ticket_resolved(uuid);

create or replace function public.mark_ticket_resolved(p_ticket_id uuid)
returns public.support_tickets
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.support_tickets;
  v_updated public.support_tickets;
  v_previous_status text;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if not public.is_support_staff(v_uid) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_ticket_id is null then
    raise exception 'ticket id required' using errcode = '22023';
  end if;

  select * into v_existing
  from public.support_tickets
  where id = p_ticket_id;

  if not found then
    raise exception 'ticket not found' using errcode = 'P0001';
  end if;

  v_previous_status := v_existing.status::text;

  if v_previous_status in ('resolved', 'closed') then
    return v_existing;
  end if;

  update public.support_tickets
  set
    status = 'resolved',
    resolved_at = now(),
    updated_at = now(),
    admin_id = coalesce(admin_id, v_uid)
  where id = p_ticket_id
  returning * into v_updated;

  insert into public.audit_logs (
    user_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    details
  ) values (
    v_uid,
    v_uid,
    'support_ticket_resolved',
    'support_ticket',
    p_ticket_id,
    jsonb_build_object(
      'previous_status', v_previous_status,
      'new_status', 'resolved'
    )
  );

  return v_updated;
end;
$$;

revoke all on function public.mark_ticket_resolved(uuid) from public;
grant execute on function public.mark_ticket_resolved(uuid) to authenticated;

-- ------------------------------------------------------------
-- available_time_slots: create only if missing so hosted RPC is preserved
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'available_time_slots'
  ) then
    execute $fn$
      create function public.available_time_slots(p_venue_id uuid, p_book_date date)
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
      stable
      security invoker
      set search_path = public, pg_temp
      as $body$
        select
          s.id,
          s.label,
          s.start_time,
          s.end_time,
          s.price_amount,
          case
            when exists (
              select 1 from public.venue_blocked_dates b
              where b.venue_id = p_venue_id and b.blocked_date = p_book_date
            ) then false
            when exists (
              select 1 from public.bookings b
              where b.venue_id = p_venue_id
                and b.book_date = p_book_date
                and b.status::text in ('held', 'pending', 'confirmed', 'completed')
                and b.start_time < s.end_time
                and b.end_time > s.start_time
            ) then false
            when exists (
              select 1 from public.booking_holds h
              where h.venue_id = p_venue_id
                and h.book_date = p_book_date
                and h.status = 'active'
                and h.expires_at > now()
                and exists (
                  select 1 from public.time_slots held
                  where held.id = h.slot_id
                    and held.start_time < s.end_time
                    and held.end_time > s.start_time
                )
            ) then false
            else true
          end,
          case
            when exists (
              select 1 from public.venue_blocked_dates b
              where b.venue_id = p_venue_id and b.blocked_date = p_book_date
            ) then 'blocked'
            when exists (
              select 1 from public.bookings b
              where b.venue_id = p_venue_id
                and b.book_date = p_book_date
                and b.status::text in ('held', 'pending', 'confirmed', 'completed')
                and b.start_time < s.end_time
                and b.end_time > s.start_time
            ) then 'booked'
            when exists (
              select 1 from public.booking_holds h
              where h.venue_id = p_venue_id
                and h.book_date = p_book_date
                and h.status = 'active'
                and h.expires_at > now()
                and exists (
                  select 1 from public.time_slots held
                  where held.id = h.slot_id
                    and held.start_time < s.end_time
                    and held.end_time > s.start_time
                )
            ) then 'held'
            else 'available'
          end
        from public.time_slots s
        where s.venue_id = p_venue_id
          and s.is_active = true
        order by s.start_time
      $body$;
    $fn$;
    execute 'grant execute on function public.available_time_slots(uuid, date) to anon, authenticated';
  end if;
end $$;

-- ------------------------------------------------------------
-- Storage: venue-images bucket scoped to the owner's organization
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'venue-images',
  'venue-images',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

drop policy if exists "venue_images_public_read" on storage.objects;
drop policy if exists "venue_images_owner_insert" on storage.objects;
drop policy if exists "venue_images_owner_update" on storage.objects;
drop policy if exists "venue_images_owner_delete" on storage.objects;

create policy "venue_images_public_read"
  on storage.objects
  for select
  using (bucket_id = 'venue-images');

create policy "venue_images_owner_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'venue-images'
    and exists (
      select 1
      from public.organizations o
      where o.owner_user_id = auth.uid()
        and o.deleted_at is null
        and o.is_active = true
        and (storage.foldername(name))[1] = o.id::text
    )
  );

create policy "venue_images_owner_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'venue-images'
    and exists (
      select 1
      from public.organizations o
      where o.owner_user_id = auth.uid()
        and o.deleted_at is null
        and (storage.foldername(name))[1] = o.id::text
    )
  )
  with check (
    bucket_id = 'venue-images'
    and exists (
      select 1
      from public.organizations o
      where o.owner_user_id = auth.uid()
        and o.deleted_at is null
        and (storage.foldername(name))[1] = o.id::text
    )
  );

create policy "venue_images_owner_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'venue-images'
    and exists (
      select 1
      from public.organizations o
      where o.owner_user_id = auth.uid()
        and o.deleted_at is null
        and (storage.foldername(name))[1] = o.id::text
    )
  );
