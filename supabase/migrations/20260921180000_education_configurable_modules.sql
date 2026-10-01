-- ============================================================
-- EDUCATION CONFIGURABLE MODULES (additive, not applied live)
-- ============================================================
-- Reuses institutes / courses / course_faculty / course_enrollments.
-- Adds JSON config (no second CMS), branches, sensitive enrollment
-- storage, and extra faculty profile columns. Idempotent.
--
-- Do NOT apply to the shared dev Supabase project without approval.
-- Flutter degrades when these columns/tables are missing.
-- ============================================================

-- ------------------------------------------------------------
-- INSTITUTES: module toggles, registration form, extra profile
-- ------------------------------------------------------------
alter table public.institutes
  add column if not exists module_config jsonb not null default '{}'::jsonb;
alter table public.institutes
  add column if not exists registration_form jsonb not null default '{}'::jsonb;
alter table public.institutes
  add column if not exists profile jsonb not null default '{}'::jsonb;

comment on column public.institutes.module_config is
  'Owner toggles (registration, faculty, demo, aadhaar, ...). Platform feature_flags still gate the product.';
comment on column public.institutes.registration_form is
  'Draft/published configurable field schema. No HTML or executable code.';
comment on column public.institutes.profile is
  'Optional profile extras: established_year, cover, social, policies.';

-- ------------------------------------------------------------
-- COURSES: optional per-course module overlay + extra content
-- ------------------------------------------------------------
alter table public.courses
  add column if not exists module_config jsonb not null default '{}'::jsonb;
alter table public.courses
  add column if not exists content jsonb not null default '{}'::jsonb;

-- ------------------------------------------------------------
-- BRANCHES (institute-level; courses/batches may point at one)
-- ------------------------------------------------------------
create table if not exists public.institute_branches (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references public.institutes(id) on delete cascade,
  name text not null default 'Main branch',
  address text not null default '',
  landmark text not null default '',
  city text not null default '',
  district text not null default '',
  state text not null default '',
  pin_code text not null default '',
  latitude double precision,
  longitude double precision,
  maps_url text not null default '',
  is_primary boolean not null default false,
  is_active boolean not null default true,
  is_online_only boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_institute_branches_institute
  on public.institute_branches (institute_id);

alter table public.course_batches
  add column if not exists branch_id uuid references public.institute_branches(id)
    on delete set null;

-- ------------------------------------------------------------
-- FACULTY: extra profile fields; optional institute scope
-- ------------------------------------------------------------
alter table if exists public.course_faculty
  add column if not exists institute_id uuid references public.institutes(id)
    on delete cascade;
alter table if exists public.course_faculty add column if not exists designation text not null default '';
alter table if exists public.course_faculty add column if not exists department text not null default '';
alter table if exists public.course_faculty add column if not exists qualification text not null default '';
alter table if exists public.course_faculty add column if not exists specialization text not null default '';
alter table if exists public.course_faculty add column if not exists experience_text text not null default '';
alter table if exists public.course_faculty add column if not exists skills text[] not null default '{}';
alter table if exists public.course_faculty add column if not exists languages text[] not null default '{}';
alter table if exists public.course_faculty add column if not exists demo_url text not null default '';
alter table if exists public.course_faculty add column if not exists resume_url text not null default '';
alter table if exists public.course_faculty add column if not exists display_order integer not null default 0;
alter table if exists public.course_faculty add column if not exists is_active boolean not null default true;
alter table if exists public.course_faculty add column if not exists faculty_user_id uuid
  references auth.users(id) on delete set null;

-- Allow institute-level faculty (course_id nullable) once institute_id is set.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'course_faculty'
      and column_name = 'course_id'
      and is_nullable = 'NO'
  ) then
    alter table public.course_faculty alter column course_id drop not null;
  end if;
end $$;

-- ------------------------------------------------------------
-- ENROLLMENT ANSWERS + SENSITIVE STORE
-- ------------------------------------------------------------
alter table public.course_enrollments
  add column if not exists form_answers jsonb not null default '{}'::jsonb;

create table if not exists public.enrollment_sensitive_fields (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.course_enrollments(id) on delete cascade,
  field_key text not null,
  value text not null,
  created_at timestamptz not null default now(),
  unique (enrollment_id, field_key)
);

create index if not exists idx_enrollment_sensitive_enrollment
  on public.enrollment_sensitive_fields (enrollment_id);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.institute_branches enable row level security;
alter table public.enrollment_sensitive_fields enable row level security;

drop policy if exists institute_branches_public_read on public.institute_branches;
create policy institute_branches_public_read on public.institute_branches
  for select using (
    is_active = true
    and exists (
      select 1 from public.institutes i
      where i.id = institute_id
    )
  );

drop policy if exists institute_branches_owner_write on public.institute_branches;
create policy institute_branches_owner_write on public.institute_branches
  for all using (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1
      from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id
        and o.owner_user_id = auth.uid()
    )
  ) with check (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1
      from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id
        and o.owner_user_id = auth.uid()
    )
  );

-- Students never read full Aadhaar / ID values. Owner + admin only.
drop policy if exists enrollment_sensitive_owner_read on public.enrollment_sensitive_fields;
create policy enrollment_sensitive_owner_read on public.enrollment_sensitive_fields
  for select using (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1
      from public.course_enrollments e
      join public.course_batches b on b.id = e.batch_id
      join public.courses c on c.id = b.course_id
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where e.id = enrollment_id
        and o.owner_user_id = auth.uid()
    )
  );

drop policy if exists enrollment_sensitive_insert_own on public.enrollment_sensitive_fields;
create policy enrollment_sensitive_insert_own on public.enrollment_sensitive_fields
  for insert with check (
    exists (
      select 1 from public.course_enrollments e
      where e.id = enrollment_id and e.user_id = auth.uid()
    )
    or public.is_platform_admin(auth.uid())
  );

-- Faculty: keep public read of published-course faculty; owners write.
drop policy if exists "course_faculty_public_read" on public.course_faculty;
create policy "course_faculty_public_read" on public.course_faculty
  for select using (
    is_active = true
    and (
      course_id is null
      or exists (
        select 1 from public.courses c
        where c.id = course_id and c.status = 'published'
      )
    )
  );

drop policy if exists "course_faculty_org_write" on public.course_faculty;
create policy "course_faculty_org_write" on public.course_faculty
  for all using (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1 from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_faculty.course_id and o.owner_user_id = auth.uid()
    )
    or exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = course_faculty.institute_id and o.owner_user_id = auth.uid()
    )
  ) with check (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1 from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_faculty.course_id and o.owner_user_id = auth.uid()
    )
    or exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = course_faculty.institute_id and o.owner_user_id = auth.uid()
    )
  );

-- Future faculty login: a linked user may update their own profile only.
drop policy if exists course_faculty_self_update on public.course_faculty;
create policy course_faculty_self_update on public.course_faculty
  for update using (faculty_user_id = auth.uid())
  with check (faculty_user_id = auth.uid());
