-- The following migration protects updated_at as a system-managed column
-- on course_faculty. Add the missing base column before that guard is set up.
alter table public.course_faculty
  add column if not exists updated_at timestamptz not null default now();
