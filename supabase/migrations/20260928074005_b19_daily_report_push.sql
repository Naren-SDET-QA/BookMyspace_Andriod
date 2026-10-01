-- B19: opt-in daily owner report delivered through the existing notification
-- and push outboxes. The scheduler runs every 15 minutes and evaluates each
-- owner's configured timezone, so 21:00 means 21:00 for that owner.

create table if not exists public.daily_report_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  timezone text not null default 'Asia/Kolkata',
  last_report_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_report_delivery_log (
  user_id uuid not null references auth.users(id) on delete cascade,
  report_date date not null,
  notification_id uuid references public.notifications(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, report_date)
);

alter table public.daily_report_preferences enable row level security;
alter table public.daily_report_delivery_log enable row level security;
grant select, insert, update on public.daily_report_preferences to authenticated;
revoke all on public.daily_report_delivery_log from anon, authenticated;

drop policy if exists daily_report_preferences_own on public.daily_report_preferences;
create policy daily_report_preferences_own on public.daily_report_preferences
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.save_daily_report_preference(
  p_enabled boolean,
  p_timezone text default 'Asia/Kolkata'
)
returns public.daily_report_preferences
language plpgsql
security definer
set search_path = public
as $$
declare v_row public.daily_report_preferences;
begin
  if auth.uid() is null then raise exception 'unauthenticated'; end if;
  if not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'invalid_timezone';
  end if;
  insert into public.daily_report_preferences(user_id, enabled, timezone, updated_at)
  values ((select auth.uid()), coalesce(p_enabled, true), p_timezone, now())
  on conflict (user_id) do update set
    enabled = excluded.enabled, timezone = excluded.timezone, updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.enqueue_daily_report_notifications(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pref record;
  v_local timestamp;
  v_report_date date;
  v_start timestamptz;
  v_count integer;
  v_revenue numeric(12,2);
  v_notification_id uuid;
  v_created integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'service_role_required';
  end if;
  for v_pref in
    select p.*
      from public.daily_report_preferences p
      join public.organizations o on o.owner_user_id = p.user_id and o.is_active
     where p.enabled
  loop
    v_local := p_now at time zone v_pref.timezone;
    if extract(hour from v_local) <> 21 or extract(minute from v_local) not between 0 and 14 then
      continue;
    end if;
    v_report_date := v_local::date;
    if v_pref.last_report_date = v_report_date then continue; end if;
    insert into public.daily_report_delivery_log(user_id, report_date)
    values (v_pref.user_id, v_report_date)
    on conflict do nothing;
    if not found then continue; end if;

    v_start := (v_report_date::text || ' 00:00:00')::timestamp at time zone v_pref.timezone;
    select count(*)::integer, coalesce(sum(b.total_amount), 0)
      into v_count, v_revenue
      from public.bookings b
      join public.venues v on v.id = b.venue_id
      join public.organizations o on o.id = v.org_id
     where o.owner_user_id = v_pref.user_id
       and b.created_at >= v_start and b.created_at < v_start + interval '1 day'
       and b.status in ('confirmed', 'completed');

    insert into public.notifications(user_id, title, body, type, data)
    values (v_pref.user_id, 'Your daily BookMySpace report',
      format('%s confirmed bookings · INR %s collected today', v_count, to_char(v_revenue, 'FM9999999990.00')),
      'daily_report', jsonb_build_object('report_date', v_report_date,
        'booking_count', v_count, 'revenue', v_revenue))
    returning id into v_notification_id;
    update public.daily_report_delivery_log
       set notification_id = v_notification_id
     where user_id = v_pref.user_id and report_date = v_report_date;
    update public.daily_report_preferences
       set last_report_date = v_report_date, updated_at = now()
     where user_id = v_pref.user_id;
    v_created := v_created + 1;
  end loop;
  return v_created;
end;
$$;

revoke all on function public.save_daily_report_preference(boolean, text) from public, anon;
revoke all on function public.enqueue_daily_report_notifications(timestamptz) from public, anon, authenticated;
grant execute on function public.save_daily_report_preference(boolean, text) to authenticated;
grant execute on function public.enqueue_daily_report_notifications(timestamptz) to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'bookmyspace-daily-report-push',
      '*/15 * * * *',
      'select public.enqueue_daily_report_notifications(now());'
    );
  end if;
exception when duplicate_object then
  null;
end $$;
