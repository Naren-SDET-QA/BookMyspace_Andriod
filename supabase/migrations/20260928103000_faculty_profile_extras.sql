-- B12: structured faculty extras (replaces the "Philosophy:" bio line and
-- ";"-separated qualification workaround). Owners edit them through the
-- existing course_faculty_org_write policy.
alter table public.course_faculty
  add column if not exists certifications text[] not null default '{}',
  add column if not exists awards text[] not null default '{}',
  add column if not exists students_trained integer
    check (students_trained is null or students_trained >= 0),
  add column if not exists teaching_philosophy text not null default '';
