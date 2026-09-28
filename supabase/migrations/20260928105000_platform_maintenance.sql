-- B8: maintenance mode + broadcast banner.
--
-- Settings live in the existing global module_feature_configs row
-- module_key = 'platform_status' (venue_id null; public read, admin write):
--   metadata.maintenance_enabled  bool
--   metadata.maintenance_message  text
--   metadata.broadcast_enabled    bool
--   metadata.broadcast_message    text
--   metadata.broadcast_severity   'info' | 'warning' | 'critical'
--
-- While maintenance is on, new booking holds / bookings are refused on the
-- server (the app also disables checkout). Platform admins are exempt so
-- they can test.

create or replace function public.platform_maintenance_active()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select (m.metadata ->> 'maintenance_enabled')::boolean
      from public.module_feature_configs m
     where m.module_key = 'platform_status' and m.venue_id is null
     order by m.updated_at desc nulls last
     limit 1
  ), false);
$$;

create or replace function public.block_checkout_during_maintenance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.platform_maintenance_active()
     and not coalesce(public.is_platform_admin(auth.uid()), false) then
    raise exception 'platform under maintenance'
      using errcode = 'P0001',
            hint = 'Bookings are paused while BookMySpace is under maintenance.';
  end if;
  return new;
end;
$$;

drop trigger if exists booking_holds_maintenance_guard on public.booking_holds;
create trigger booking_holds_maintenance_guard
  before insert on public.booking_holds
  for each row execute function public.block_checkout_during_maintenance();

drop trigger if exists bookings_maintenance_guard on public.bookings;
create trigger bookings_maintenance_guard
  before insert on public.bookings
  for each row execute function public.block_checkout_during_maintenance();

drop trigger if exists course_enrollments_maintenance_guard on public.course_enrollments;
create trigger course_enrollments_maintenance_guard
  before insert on public.course_enrollments
  for each row execute function public.block_checkout_during_maintenance();

revoke all on function public.block_checkout_during_maintenance() from public, anon, authenticated;
grant execute on function public.platform_maintenance_active() to anon, authenticated;

insert into public.module_feature_configs (module_key, venue_id, metadata)
select 'platform_status', null, jsonb_build_object(
  'maintenance_enabled', false,
  'maintenance_message', '',
  'broadcast_enabled', false,
  'broadcast_message', '',
  'broadcast_severity', 'info'
)
where not exists (
  select 1 from public.module_feature_configs
   where module_key = 'platform_status' and venue_id is null
);
