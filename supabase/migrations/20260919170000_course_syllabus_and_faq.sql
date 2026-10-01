-- ============================================================
-- COURSE SYLLABUS + FAQ (additive)
-- ============================================================
-- "What you'll learn" outcome bullets on courses, plus a course_faqs
-- table. Mirrors the course_faculty pattern: public read for published
-- courses, owner write via institute -> organization ownership.
--
-- Applied to bookmyspace-dev (zykxneztahxbjduagutv) on 2026-09-19 via
-- the Supabase MCP tool, with the user's explicit approval.

alter table public.courses
  add column if not exists syllabus_points text[] not null default '{}';

create table if not exists public.course_faqs (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  question text not null,
  answer text not null,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_course_faqs_course on public.course_faqs(course_id, display_order);

alter table public.course_faqs enable row level security;

drop policy if exists "course_faqs_public_read" on public.course_faqs;
create policy "course_faqs_public_read" on public.course_faqs for select using (
  exists (select 1 from public.courses c where c.id = course_id and c.status = 'published')
);

drop policy if exists "course_faqs_org_write" on public.course_faqs;
create policy "course_faqs_org_write" on public.course_faqs for all using (
  exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
  or public.is_platform_admin(auth.uid())
) with check (
  exists (
    select 1 from public.courses c
    join public.institutes i on i.id = c.institute_id
    join public.organizations o on o.id = i.org_id
    where c.id = course_id and o.owner_user_id = auth.uid()
  )
  or public.is_platform_admin(auth.uid())
);
