# Migration Plan — generalize module_* config tables with target_type/target_id

Status: DRAFT FOR REVIEW. Nothing in this plan has been applied to any database.
No destructive statement is proposed anywhere below.

## Why

`module_feature_configs`, `module_form_versions`, `module_document_requirements`,
`module_form_submissions` are currently hard-keyed to `venue_id` (FK to `venues`,
RLS reads `venues -> organizations -> owner_user_id`). Courses/institutes have no
`venue_id` guarantee (`courses.venue_id` is nullable and frequently empty for a
purely-online course), so keying course config off `venue_id` would silently break
for any course that isn't tied to a physical venue. Per your instruction, `target_type`
+ `target_id` replaces the implicit venue-only assumption.

One more finding from reading the RLS/trigger source directly (not assumed): the
`feature_flags` table already has a `validate_feature_flag_config()` trigger whose
CHECK-equivalent logic currently treats `courses` as a **core module that cannot be
disabled** (`new.key in ('payments','notifications','courses') and enabled is false
-> raise exception 'core_module_cannot_be_disabled'`). The new "ADMIN-CONTROLLED
MODULES" spec explicitly requires courses to be disable-able. That trigger function
needs a companion change (drop `courses` from the non-disableable list) — flagging
it here since it's schema-adjacent and easy to miss.

## Approach: additive columns, not a new table

Add nullable `target_type text` and `target_id uuid` to each of the four tables,
**alongside** the existing `venue_id`, not replacing it:

```sql
-- Migration: supabase/migrations/<timestamp>_module_config_generic_target.sql
-- Additive only. venue_id is kept, existing rows are backfilled, nothing is dropped.

alter table public.module_feature_configs
  add column if not exists target_type text,
  add column if not exists target_id uuid;

alter table public.module_form_versions
  add column if not exists target_type text,
  add column if not exists target_id uuid;

alter table public.module_document_requirements
  add column if not exists target_type text,
  add column if not exists target_id uuid;

alter table public.module_form_submissions
  add column if not exists target_type text,
  add column if not exists target_id uuid;

-- Backfill: every existing row is a venue-scoped row today.
update public.module_feature_configs
  set target_type = 'venue', target_id = venue_id
  where target_type is null and venue_id is not null;
update public.module_form_versions
  set target_type = 'venue', target_id = venue_id
  where target_type is null and venue_id is not null;
update public.module_document_requirements
  set target_type = 'venue', target_id = venue_id
  where target_type is null and venue_id is not null;
update public.module_form_submissions
  set target_type = 'venue', target_id = venue_id
  where target_type is null and venue_id is not null;

-- Guard the vocabulary; extend this list, never remove an existing member.
alter table public.module_feature_configs
  add constraint module_feature_configs_target_type_chk
  check (target_type is null or target_type in ('venue','institute','course','batch','demo_registration'));
alter table public.module_form_versions
  add constraint module_form_versions_target_type_chk
  check (target_type is null or target_type in ('venue','institute','course','batch','demo_registration'));
alter table public.module_document_requirements
  add constraint module_document_requirements_target_type_chk
  check (target_type is null or target_type in ('venue','institute','course','batch','demo_registration'));
alter table public.module_form_submissions
  add constraint module_form_submissions_target_type_chk
  check (target_type is null or target_type in ('venue','institute','course','batch','demo_registration'));

-- Consistency: a row must be exactly one kind of target (or legacy venue-only row).
alter table public.module_feature_configs
  add constraint module_feature_configs_target_consistency_chk
  check (
    (target_type is null and target_id is null)
    or (target_type = 'venue' and (target_id is null or target_id = venue_id))
    or (target_type is not null and target_type <> 'venue' and venue_id is null)
  );
-- (same shape repeated for the other three tables)

create index if not exists module_feature_configs_target_idx
  on public.module_feature_configs(target_type, target_id) where target_type is not null;
create index if not exists module_form_versions_target_idx
  on public.module_form_versions(target_type, target_id) where target_type is not null;
create index if not exists module_document_requirements_target_idx
  on public.module_document_requirements(target_type, target_id) where target_type is not null;
create index if not exists module_form_submissions_target_idx
  on public.module_form_submissions(target_type, target_id) where target_type is not null;
```

## RLS impact

Existing venue-scoped policies (`module_features_owner_admin_write`,
`module_features_read`, `module_docs_*`, `module_forms_*`, `module_submissions_*`)
stay **exactly as-is** — they only reference `venue_id`, which is untouched, so
existing venue behavior is not modified. New, additive policies are needed to cover
`target_type in ('institute','course','batch')` rows, mirroring the existing
owner-write / admin-write / published-read shape but joining through
`institutes.org_id -> organizations.owner_user_id` (institute owner) instead of
`venues.org_id`. Example addition (does not touch existing policies):

```sql
drop policy if exists module_features_institute_owner_admin_write on public.module_feature_configs;
create policy module_features_institute_owner_admin_write on public.module_feature_configs
  for all using (
    is_platform_admin((select auth.uid()))
    or (
      target_type = 'course' and exists (
        select 1 from public.courses c
        join public.institutes i on i.id = c.institute_id
        join public.organizations o on o.id = i.org_id
        where c.id = module_feature_configs.target_id
          and o.owner_user_id = (select auth.uid())
      )
    )
    or (
      target_type = 'institute' and exists (
        select 1 from public.institutes i
        join public.organizations o on o.id = i.org_id
        where i.id = module_feature_configs.target_id
          and o.owner_user_id = (select auth.uid())
      )
    )
  );
```
(Repeated per table, matching that table's existing owner/admin policy shape.)

## Companion fix: feature_flags core-module list

```sql
create or replace function public.validate_feature_flag_config()
...
  if new.key in ('payments', 'notifications') and new.enabled is false then
    raise exception 'core_module_cannot_be_disabled';
  end if;
...
```
(Only change: remove `'courses'` from the non-disableable list. Everything else in
the function is unchanged.)

## What this migration deliberately does NOT do

- Does not drop, rename, or make `venue_id` non-nullable/nullable-change on any table.
- Does not touch `feature_flags` rows, `module_manifests.dart`'s existing entries, or
  any existing venue module config.
- Does not create a second config table, second repository, or second admin screen.
- Does not change `courses.venue_id`, `institutes`, or `course_batches` at all.

## Rollback

Every statement is additive (`add column if not exists`, `add constraint`,
`create index if not exists`, new policies). Rollback is:
```sql
drop policy if exists module_features_institute_owner_admin_write on public.module_feature_configs;
-- (repeat per added policy)
alter table public.module_feature_configs drop constraint if exists module_feature_configs_target_consistency_chk;
alter table public.module_feature_configs drop constraint if exists module_feature_configs_target_type_chk;
drop index if exists module_feature_configs_target_idx;
alter table public.module_feature_configs drop column if exists target_type, drop column if exists target_id;
-- (repeat per table)
```
No data loss on rollback: `target_type`/`target_id` are a pure derived overlay of
`venue_id` for existing rows, so dropping them loses nothing that wasn't already in
`venue_id`.

## Affected tables (summary)

| Table | Change | Rows today |
|---|---|---|
| module_feature_configs | +target_type, +target_id, +constraints, +index, +institute/course policies | 2 |
| module_form_versions | same | 0 |
| module_document_requirements | same | 0 |
| module_form_submissions | same | 0 |
| module_registration_payments | no schema change needed — already keyed by `submission_id`, which will transitively resolve to whatever target the submission belongs to | 0 |
| module_submission_documents | no schema change needed — same reasoning | 0 |
| feature_flags | function-only change: drop `courses` from non-disableable key list | — |

Row counts are near-zero today, so backfill risk is effectively nil, but the plan
above is written to be safe at any row count.

## Recommendation

Given the very low current row count (2 rows total across all four tables), this
migration is low-risk to apply once approved. I have NOT applied it — awaiting your
go-ahead before running `apply_migration`.

---

## ADDENDUM — a second, separate RLS gap found while checking write access

Before writing any admin create/edit UI I checked the actual RLS policies on
`institutes`, `courses`, and `course_batches` (queried live via `pg_policy`, not
assumed). Findings:

- `institutes_org_write` and `courses_org_write`: writable only when
  `organizations.owner_user_id = auth.uid()`. There is **no `is_platform_admin(...)`
  branch** on either policy — an administrator who does not personally own the
  organization cannot currently write to `institutes` or `courses` at all.
- `course_batches` has **only one policy**, `batches_public_read` (`is_active` read).
  There is **no write policy of any kind** on `course_batches` — nobody (not even the
  institute's own org owner) can currently insert/update a batch through the client;
  only `service_role` bypassing RLS could.

This blocks two required items directly: "Institute/course/batch create and edit
flows" (batches literally cannot be written today) and "Admin moderation and
publishing" (admin has no write path on any of the three tables). This is a second,
independent, additive RLS change — proposed here for the same review gate as the
target_type migration above, not applied:

```sql
-- Add admin write access to institutes/courses (org-owner access is unchanged).
drop policy if exists institutes_org_write on public.institutes;
create policy institutes_org_write on public.institutes
  for all using (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.organizations o
      where o.id = institutes.org_id and o.owner_user_id = (select auth.uid())
    )
  )
  with check (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.organizations o
      where o.id = institutes.org_id and o.owner_user_id = (select auth.uid())
    )
  );

drop policy if exists courses_org_write on public.courses;
create policy courses_org_write on public.courses
  for all using (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = courses.institute_id and o.owner_user_id = (select auth.uid())
    )
  )
  with check (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = courses.institute_id and o.owner_user_id = (select auth.uid())
    )
  );

-- New: course_batches currently has no write policy at all.
create policy course_batches_org_admin_write on public.course_batches
  for all using (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_batches.course_id and o.owner_user_id = (select auth.uid())
    )
  )
  with check (
    is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_batches.course_id and o.owner_user_id = (select auth.uid())
    )
  );
```

Rollback: `drop policy` the three above and recreate the original
`institutes_org_write`/`courses_org_write` bodies (org-owner-only, no admin branch);
`course_batches` reverts to having no write policy (its original state). No data is
touched by any of this — policy changes only.

This addendum is intentionally separate from the target_type migration above so you
can approve them independently if you want the admin-write fix sooner.
