-- B11: batch highlights. "New" / "Upcoming" / "Live today" are derived in
-- the app from created_at, starts_on/ends_on and days_of_week.
alter table public.course_batches
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists todays_topic text not null default '',
  add column if not exists highlight_tag text not null default '',
  -- ISO weekdays, 1 = Monday ... 7 = Sunday. Empty = every day.
  add column if not exists days_of_week smallint[] not null default '{}',
  add column if not exists age_group text not null default '',
  add column if not exists skill_level text not null default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'course_batches_days_of_week_check'
  ) then
    alter table public.course_batches
      add constraint course_batches_days_of_week_check
      check (days_of_week <@ array[1,2,3,4,5,6,7]::smallint[]);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'course_batches_skill_level_check'
  ) then
    alter table public.course_batches
      add constraint course_batches_skill_level_check
      check (skill_level in ('', 'beginner', 'intermediate', 'advanced', 'all_levels'));
  end if;
end $$;

-- Rows that existed before this migration are not "new".
update public.course_batches
   set created_at = now() - interval '30 days'
 where created_at > now() - interval '5 minutes'
   and todays_topic = '' and highlight_tag = '';
