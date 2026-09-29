-- Platform-admin content edits for Function Halls, Hotel/PG listings,
-- Institutes, Courses, and Hotel room content.
--
-- Row policies cannot hide columns. Deletes are intentionally omitted:
-- deleting a venue cascades to booking_holds and time_slots, and deleting
-- a hotel_room_types row cascades to hotel_room_availability. Holds and
-- availability stay without admin write policies.
--
-- Generated venue columns geog and search_document are omitted from the
-- trigger. Postgres rejects direct writes to GENERATED ALWAYS columns,
-- and it recomputes them after BEFORE triggers.

do $$
declare
  required text[] := array[
    'venues.id', 'venues.org_id', 'venues.avg_rating', 'venues.rating_count',
    'venues.created_at', 'venues.updated_at', 'venues.deleted_at',
    'venues.source', 'venues.source_place_id',
    'venues.cancellation_policy_version', 'venues.is_verified',
    'venues.listing_rejection_reason',
    'venue_images.id', 'venue_images.venue_id', 'venue_images.created_at',
    'venue_images.content_type', 'venue_images.size_bytes',
    'venue_images.processing_status', 'venue_images.upload_key',
    'venue_facilities.id', 'venue_facilities.venue_id',
    'venue_operating_hours.id', 'venue_operating_hours.venue_id',
    'institutes.id', 'institutes.org_id', 'institutes.created_at',
    'institutes.updated_at', 'institutes.is_verified',
    'institute_media.id', 'institute_media.institute_id',
    'institute_media.created_at',
    'institute_faculty.id', 'institute_faculty.institute_id',
    'institute_faculty.created_at',
    'courses.id', 'courses.institute_id', 'courses.created_at',
    'courses.updated_at',
    'course_faculty.id', 'course_faculty.course_id',
    'course_faculty.institute_id', 'course_faculty.faculty_user_id',
    'course_faculty.created_at', 'course_faculty.updated_at',
    'course_batches.id', 'course_batches.course_id',
    'course_batches.branch_id', 'course_batches.created_at',
    'course_batches.enrolled_count', 'course_batches.waitlist_count',
    'hotel_room_types.id', 'hotel_room_types.venue_id',
    'hotel_room_types.created_at', 'hotel_room_types.updated_at',
    'hotel_room_images.id', 'hotel_room_images.room_type_id',
    'hotel_room_images.created_at'
  ];
  item text;
  tbl text;
  col text;
begin
  if to_regclass('public.accommodation_properties') is not null
     or to_regclass('public.accommodation_units') is not null then
    raise exception
      'accommodation tables are present; this migration must not touch them';
  end if;

  foreach item in array required loop
    tbl := split_part(item, '.', 1);
    col := split_part(item, '.', 2);
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = tbl
        and column_name = col
    ) then
      raise exception 'live schema missing %.%', tbl, col;
    end if;
  end loop;

  if to_regprocedure('public.is_platform_admin(uuid)') is null then
    raise exception 'public.is_platform_admin(uuid) is missing';
  end if;
end $$;

create or replace function public.reject_platform_admin_protected_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  col text;
  new_json jsonb := to_jsonb(new);
  old_json jsonb := to_jsonb(old);
  privileged boolean;
begin
  -- Nested writes from an already-checked statement (for example the
  -- course-batch waitlist trigger) are not a second admin edit.
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if auth.uid() is null or not public.is_platform_admin(auth.uid()) then
    return new;
  end if;

  -- Security-definer owner/booking functions run as a bypass role.
  -- Direct API calls run as authenticated and stay guarded.
  select r.rolsuper or r.rolbypassrls
    into privileged
  from pg_catalog.pg_roles r
  where r.rolname = current_user;
  if coalesce(privileged, false) then
    return new;
  end if;

  foreach col in array tg_argv loop
    if (new_json -> col) is distinct from (old_json -> col) then
      raise exception
        'protected column %.% cannot be changed by a platform admin',
        tg_table_name, col
        using errcode = '42501';
    end if;
  end loop;

  return new;
end $$;

comment on function public.reject_platform_admin_protected_columns() is
  'Blocks platform-admin API updates of system columns. Owners and security-definer functions are unchanged.';

-- Venues and listing children. No DELETE: venue delete cascades into holds and slots.
drop policy if exists venues_platform_admin_insert on public.venues;
create policy venues_platform_admin_insert
  on public.venues
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists venues_platform_admin_update on public.venues;
create policy venues_platform_admin_update
  on public.venues
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_venues_protected_columns on public.venues;
create trigger a_guard_venues_protected_columns
  before update on public.venues
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'org_id',
    'avg_rating',
    'rating_count',
    'created_at',
    'updated_at',
    'deleted_at',
    'source',
    'source_place_id',
    'cancellation_policy_version',
    'is_verified',
    'listing_rejection_reason'
  );

drop policy if exists venue_images_platform_admin_insert on public.venue_images;
create policy venue_images_platform_admin_insert
  on public.venue_images
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists venue_images_platform_admin_update on public.venue_images;
create policy venue_images_platform_admin_update
  on public.venue_images
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_venue_images_protected_columns on public.venue_images;
create trigger a_guard_venue_images_protected_columns
  before update on public.venue_images
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'venue_id',
    'created_at',
    'content_type',
    'size_bytes',
    'processing_status',
    'upload_key'
  );

drop policy if exists venue_facilities_platform_admin_insert on public.venue_facilities;
create policy venue_facilities_platform_admin_insert
  on public.venue_facilities
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists venue_facilities_platform_admin_update on public.venue_facilities;
create policy venue_facilities_platform_admin_update
  on public.venue_facilities
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_venue_facilities_protected_columns on public.venue_facilities;
create trigger a_guard_venue_facilities_protected_columns
  before update on public.venue_facilities
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'venue_id'
  );

drop policy if exists venue_operating_hours_platform_admin_insert on public.venue_operating_hours;
create policy venue_operating_hours_platform_admin_insert
  on public.venue_operating_hours
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists venue_operating_hours_platform_admin_update on public.venue_operating_hours;
create policy venue_operating_hours_platform_admin_update
  on public.venue_operating_hours
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_venue_operating_hours_protected_columns on public.venue_operating_hours;
create trigger a_guard_venue_operating_hours_protected_columns
  before update on public.venue_operating_hours
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'venue_id'
  );

-- Existing admin write policies stay. These triggers add the column guard.
drop trigger if exists a_guard_institutes_protected_columns on public.institutes;
create trigger a_guard_institutes_protected_columns
  before update on public.institutes
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'org_id',
    'created_at',
    'updated_at',
    'is_verified'
  );

drop policy if exists institute_media_platform_admin_insert on public.institute_media;
create policy institute_media_platform_admin_insert
  on public.institute_media
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists institute_media_platform_admin_update on public.institute_media;
create policy institute_media_platform_admin_update
  on public.institute_media
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_institute_media_protected_columns on public.institute_media;
create trigger a_guard_institute_media_protected_columns
  before update on public.institute_media
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'institute_id',
    'created_at'
  );

drop policy if exists institute_faculty_platform_admin_insert on public.institute_faculty;
create policy institute_faculty_platform_admin_insert
  on public.institute_faculty
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists institute_faculty_platform_admin_update on public.institute_faculty;
create policy institute_faculty_platform_admin_update
  on public.institute_faculty
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_institute_faculty_protected_columns on public.institute_faculty;
create trigger a_guard_institute_faculty_protected_columns
  before update on public.institute_faculty
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'institute_id',
    'created_at'
  );

drop trigger if exists a_guard_courses_protected_columns on public.courses;
create trigger a_guard_courses_protected_columns
  before update on public.courses
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'institute_id',
    'created_at',
    'updated_at'
  );

drop trigger if exists a_guard_course_faculty_protected_columns on public.course_faculty;
create trigger a_guard_course_faculty_protected_columns
  before update on public.course_faculty
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'course_id',
    'institute_id',
    'faculty_user_id',
    'created_at',
    'updated_at'
  );

drop trigger if exists a_guard_course_batches_protected_columns on public.course_batches;
create trigger a_guard_course_batches_protected_columns
  before update on public.course_batches
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'course_id',
    'branch_id',
    'created_at',
    'enrolled_count',
    'waitlist_count'
  );

-- Room content only. Availability and holds are untouched.
drop policy if exists hotel_room_types_platform_admin_insert on public.hotel_room_types;
create policy hotel_room_types_platform_admin_insert
  on public.hotel_room_types
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists hotel_room_types_platform_admin_update on public.hotel_room_types;
create policy hotel_room_types_platform_admin_update
  on public.hotel_room_types
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_hotel_room_types_protected_columns on public.hotel_room_types;
create trigger a_guard_hotel_room_types_protected_columns
  before update on public.hotel_room_types
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'venue_id',
    'created_at',
    'updated_at'
  );

drop policy if exists hotel_room_images_platform_admin_insert on public.hotel_room_images;
create policy hotel_room_images_platform_admin_insert
  on public.hotel_room_images
  for insert
  to authenticated
  with check (public.is_platform_admin(auth.uid()));

drop policy if exists hotel_room_images_platform_admin_update on public.hotel_room_images;
create policy hotel_room_images_platform_admin_update
  on public.hotel_room_images
  for update
  to authenticated
  using (public.is_platform_admin(auth.uid()))
  with check (public.is_platform_admin(auth.uid()));

drop trigger if exists a_guard_hotel_room_images_protected_columns on public.hotel_room_images;
create trigger a_guard_hotel_room_images_protected_columns
  before update on public.hotel_room_images
  for each row
  execute function public.reject_platform_admin_protected_columns(
    'id',
    'room_type_id',
    'created_at'
  );

-- Storage. Authenticated platform admins only. education-media is unchanged.
drop policy if exists venue_images_platform_admin_insert on storage.objects;
create policy venue_images_platform_admin_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'venue-images'
    and public.is_platform_admin(auth.uid())
  );

drop policy if exists venue_images_platform_admin_update on storage.objects;
create policy venue_images_platform_admin_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'venue-images'
    and public.is_platform_admin(auth.uid())
  )
  with check (
    bucket_id = 'venue-images'
    and public.is_platform_admin(auth.uid())
  );

drop policy if exists venue_images_platform_admin_delete on storage.objects;
create policy venue_images_platform_admin_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'venue-images'
    and public.is_platform_admin(auth.uid())
  );

drop policy if exists category_media_platform_admin_cms_insert on storage.objects;
create policy category_media_platform_admin_cms_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'category-media'
    and public.is_platform_admin(auth.uid())
    and (storage.foldername(name))[1] = 'cms'
  );

drop policy if exists category_media_platform_admin_cms_update on storage.objects;
create policy category_media_platform_admin_cms_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'category-media'
    and public.is_platform_admin(auth.uid())
    and (storage.foldername(name))[1] = 'cms'
  )
  with check (
    bucket_id = 'category-media'
    and public.is_platform_admin(auth.uid())
    and (storage.foldername(name))[1] = 'cms'
  );

drop policy if exists category_media_platform_admin_cms_delete on storage.objects;
create policy category_media_platform_admin_cms_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'category-media'
    and public.is_platform_admin(auth.uid())
    and (storage.foldername(name))[1] = 'cms'
  );
