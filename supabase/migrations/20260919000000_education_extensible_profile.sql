-- ============================================================
-- EDUCATION EXTENSIBLE PROFILE (additive)
-- ============================================================
-- Extends the existing institutes / courses schema (0006) with the
-- profile, demo, discount, faculty, feedback, demo-registration and
-- invoice support the Flutter education flow reads. Everything here is
-- ADDITIVE and IDEMPOTENT: `add column if not exists` / `create table
-- if not exists` / `create or replace function`. The Dart layer attempts
-- the extended shape first and degrades to the base shape when a column
-- or relation is missing, so applying (or not applying) this migration
-- never breaks the running app.
--
-- NOTE: this file must NOT be applied to the shared dev Supabase project
-- without explicit approval (shared-state change).
-- ============================================================

-- ------------------------------------------------------------
-- INSTITUTES: profile, location, contact, delivery, media
-- ------------------------------------------------------------
alter table public.institutes
  add column if not exists institute_type text
    not null default 'other'
    check (institute_type in
      ('private', 'state_government', 'central_government', 'university', 'ngo', 'other'));
alter table public.institutes add column if not exists category_id uuid;
alter table public.institutes add column if not exists address text;
alter table public.institutes add column if not exists city text;
alter table public.institutes add column if not exists latitude double precision;
alter table public.institutes add column if not exists longitude double precision;
alter table public.institutes add column if not exists phone text;
alter table public.institutes add column if not exists email text;
alter table public.institutes add column if not exists whatsapp text;
alter table public.institutes add column if not exists website text;
alter table public.institutes add column if not exists mode public.course_mode;
alter table public.institutes add column if not exists timings text;
alter table public.institutes add column if not exists images text[] not null default '{}';

create index if not exists idx_institutes_category on public.institutes(category_id);
create index if not exists idx_institutes_city on public.institutes(city);

-- ------------------------------------------------------------
-- COURSES: category, discount, demo methods & media, contact
-- ------------------------------------------------------------
alter table public.courses add column if not exists category_id uuid;
alter table public.courses
  add column if not exists discount_amount numeric(12,2) not null default 0
  check (discount_amount >= 0);
alter table public.courses add column if not exists demo_methods text[] not null default '{}';
alter table public.courses add column if not exists demo_video_url text;
alter table public.courses add column if not exists demo_thumbnail_url text;
alter table public.courses add column if not exists brochure_url text;
alter table public.courses add column if not exists external_registration_url text;
alter table public.courses add column if not exists contact_phone text;

create index if not exists idx_courses_category on public.courses(category_id);

-- ------------------------------------------------------------
-- COURSE FACULTY (structured instructor profiles)
-- ------------------------------------------------------------
create table if not exists public.course_faculty (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  name text not null,
  role text,
  bio text,
  photo_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_course_faculty_course on public.course_faculty(course_id);

-- ------------------------------------------------------------
-- COURSE DEMO REGISTRATIONS (internal demo-class requests)
-- ------------------------------------------------------------
create table if not exists public.course_demo_registrations (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  student_name text not null,
  mobile text not null,
  email text,
  preferred_batch text,
  note text,
  status text not null default 'pending'
    check (status in ('pending', 'contacted', 'attended', 'cancelled')),
  created_at timestamptz not null default now()
);

create index if not exists idx_demo_registrations_course on public.course_demo_registrations(course_id);
create index if not exists idx_demo_registrations_user on public.course_demo_registrations(user_id);

-- ------------------------------------------------------------
-- COURSE FEEDBACK (post-enrollment rating & comment)
-- ------------------------------------------------------------
create table if not exists public.course_feedback (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  author_name text,
  created_at timestamptz not null default now(),
  unique (course_id, user_id)
);

create index if not exists idx_course_feedback_course on public.course_feedback(course_id);

-- ------------------------------------------------------------
-- EDUCATION INVOICES (server-side invoice entity)
-- ------------------------------------------------------------
-- The Flutter app currently composes an invoice client-side from the
-- enrollment + fee breakdown because no server invoice existed. This
-- table gives enrollments a durable, owner/admin-readable invoice row.
create table if not exists public.education_invoices (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.course_enrollments(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  number text not null unique,
  student_name text,
  fee_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  net_amount numeric(12,2) not null default 0,
  status text not null default 'paid' check (status in ('due', 'paid', 'refunded')),
  issued_at timestamptz not null default now()
);

create index if not exists idx_education_invoices_user on public.education_invoices(user_id);
create index if not exists idx_education_invoices_course on public.education_invoices(course_id);

-- ------------------------------------------------------------
-- ENROLLMENT RPCs
-- ------------------------------------------------------------
-- `enroll_in_course` / `drop_course_enrollment` are invoked by
-- SupabaseCourseRepository but were never defined in a migration. Their
-- error messages are matched by the Dart layer ('batch full',
-- 'batch not available', 'already enrolled'), so the wording below is
-- load-bearing and must stay in sync.
create or replace function public.enroll_in_course(p_batch_id uuid, p_user_id uuid)
returns public.course_enrollments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch public.course_batches;
  v_result public.course_enrollments;
begin
  if auth.uid() is distinct from p_user_id and not public.is_platform_admin(auth.uid()) then
    raise exception 'not authorized';
  end if;

  select * into v_batch from public.course_batches where id = p_batch_id;
  if v_batch is null or not v_batch.is_active then
    raise exception 'batch not available';
  end if;
  if v_batch.enrolled_count >= v_batch.capacity then
    raise exception 'batch full';
  end if;

  begin
    insert into public.course_enrollments (batch_id, user_id, status)
    values (p_batch_id, p_user_id, 'enrolled')
    returning * into v_result;
  exception
    when unique_violation then
      raise exception 'already enrolled';
  end;

  update public.course_batches
    set enrolled_count = enrolled_count + 1
    where id = p_batch_id;

  return v_result;
end;
$$;

create or replace function public.drop_course_enrollment(p_batch_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enrollment public.course_enrollments;
begin
  if auth.uid() is distinct from p_user_id and not public.is_platform_admin(auth.uid()) then
    raise exception 'not authorized';
  end if;

  select * into v_enrollment
  from public.course_enrollments
  where batch_id = p_batch_id and user_id = p_user_id and status = 'enrolled';

  if v_enrollment is null then
    return;
  end if;

  update public.course_enrollments set status = 'dropped' where id = v_enrollment.id;
  update public.course_batches
    set enrolled_count = greatest(enrolled_count - 1, 0)
    where id = p_batch_id;
end;
$$;

-- ------------------------------------------------------------
-- FEEDBACK ENROLLMENT GUARD
-- ------------------------------------------------------------
-- The Dart layer maps a 42501 / 'not enrolled' failure to a friendly
-- message, so feedback is only accepted from learners with an active
-- enrollment in the course.
create or replace function public.enforce_course_feedback_enrollment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_platform_admin(new.user_id) then
    return new;
  end if;
  if not exists (
    select 1
    from public.course_enrollments e
    join public.course_batches b on b.id = e.batch_id
    where e.user_id = new.user_id
      and b.course_id = new.course_id
      and e.status = 'enrolled'
  ) then
    raise exception 'not enrolled' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists course_feedback_enrollment_guard on public.course_feedback;
create trigger course_feedback_enrollment_guard
  before insert on public.course_feedback
  for each row execute function public.enforce_course_feedback_enrollment();

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.course_faculty enable row level security;
alter table public.course_demo_registrations enable row level security;
alter table public.course_feedback enable row level security;
alter table public.education_invoices enable row level security;

-- Faculty: public read for published courses; owner write via institute org.
drop policy if exists "course_faculty_public_read" on public.course_faculty;
create policy "course_faculty_public_read" on public.course_faculty for select using (
  exists (select 1 from public.courses c where c.id = course_id and c.status = 'published')
);
drop policy if exists "course_faculty_org_write" on public.course_faculty;
create policy "course_faculty_org_write" on public.course_faculty for all using (
  exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
);

-- Demo registrations: submitter may insert/read their own; owner/admin read all for their courses.
drop policy if exists "demo_registrations_insert_own" on public.course_demo_registrations;
create policy "demo_registrations_insert_own" on public.course_demo_registrations for insert
  with check (auth.uid() = user_id or user_id is null);
drop policy if exists "demo_registrations_own_read" on public.course_demo_registrations;
create policy "demo_registrations_own_read" on public.course_demo_registrations for select using (
  auth.uid() = user_id
  or public.is_platform_admin(auth.uid())
  or exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
);
drop policy if exists "demo_registrations_org_update" on public.course_demo_registrations;
create policy "demo_registrations_org_update" on public.course_demo_registrations for update using (
  public.is_platform_admin(auth.uid())
  or exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
);

-- Feedback: public read; own insert/update (enrollment enforced by trigger).
drop policy if exists "course_feedback_public_read" on public.course_feedback;
create policy "course_feedback_public_read" on public.course_feedback for select using (true);
drop policy if exists "course_feedback_insert_own" on public.course_feedback;
create policy "course_feedback_insert_own" on public.course_feedback for insert
  with check (auth.uid() = user_id);
drop policy if exists "course_feedback_update_own" on public.course_feedback;
create policy "course_feedback_update_own" on public.course_feedback for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Invoices: owner of the invoice reads it; platform admin reads all; owner org manages.
drop policy if exists "education_invoices_own_read" on public.education_invoices;
create policy "education_invoices_own_read" on public.education_invoices for select using (
  auth.uid() = user_id
  or public.is_platform_admin(auth.uid())
  or exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
);
drop policy if exists "education_invoices_org_write" on public.education_invoices;
create policy "education_invoices_org_write" on public.education_invoices for all using (
  public.is_platform_admin(auth.uid())
  or exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
) with check (
  public.is_platform_admin(auth.uid())
  or exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- GRANTS
-- ------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.enroll_in_course(uuid, uuid) to authenticated;
    grant execute on function public.drop_course_enrollment(uuid, uuid) to authenticated;
  end if;
end $$;

revoke all on function public.enforce_course_feedback_enrollment() from public;
