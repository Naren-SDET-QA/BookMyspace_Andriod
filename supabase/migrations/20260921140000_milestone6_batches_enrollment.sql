-- Milestone 6: additive course-batch fields, capacity-safe enrollment,
-- trial admissions, owner batch policies. Idempotent.

-- ------------------------------------------------------------
-- BATCH COLUMNS (keep label/starts_on/capacity; add requested fields)
-- ------------------------------------------------------------
alter table public.course_batches
  add column if not exists timing text not null default '',
  add column if not exists ends_on date,
  add column if not exists fee_amount numeric(12,2) not null default 0
    check (fee_amount >= 0),
  add column if not exists mode public.course_mode,
  add column if not exists waitlist_enabled boolean not null default false,
  add column if not exists waitlist_count integer not null default 0
    check (waitlist_count >= 0),
  add column if not exists admissions_open boolean not null default true,
  add column if not exists subject text not null default '',
  add column if not exists category_slug text not null default '';

update public.course_batches b
set
  fee_amount = coalesce(nullif(b.fee_amount, 0), c.fee_amount, 0),
  mode = coalesce(b.mode, c.mode),
  timing = case
    when b.timing <> '' then b.timing
    when b.timetable is not null then coalesce(b.timetable->>'label', b.timetable->>'timing', '')
    else ''
  end
from public.courses c
where c.id = b.course_id;

create index if not exists idx_course_batches_mode on public.course_batches (mode);
create index if not exists idx_course_batches_starts on public.course_batches (starts_on);
create index if not exists idx_course_batches_category on public.course_batches (category_slug);

-- ------------------------------------------------------------
-- ENROLLMENT COLUMNS
-- ------------------------------------------------------------
alter table public.course_enrollments
  drop constraint if exists course_enrollments_status_check;

alter table public.course_enrollments
  add column if not exists is_trial boolean not null default false,
  add column if not exists student_name text not null default '',
  add column if not exists contact_phone text not null default '',
  add column if not exists preferred_start date,
  add column if not exists admission_code text;

alter table public.course_enrollments
  add constraint course_enrollments_status_check
  check (status in (
    'enrolled', 'dropped', 'completed', 'trial', 'pending_approval', 'rejected'
  ));

create unique index if not exists course_enrollments_admission_code_uidx
  on public.course_enrollments (admission_code)
  where admission_code is not null;

-- ------------------------------------------------------------
-- INSTITUTE AMENITIES
-- ------------------------------------------------------------
alter table public.institutes
  add column if not exists amenities jsonb not null default '[]'::jsonb;

-- ------------------------------------------------------------
-- OWNER / ADMIN BATCH WRITE (live project may already have these names)
-- ------------------------------------------------------------
drop policy if exists course_batches_owner_insert on public.course_batches;
create policy course_batches_owner_insert on public.course_batches
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_id
        and o.owner_user_id = (select auth.uid())
        and i.is_verified
    )
    or public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );

drop policy if exists course_batches_owner_update on public.course_batches;
create policy course_batches_owner_update on public.course_batches
  for update to authenticated
  using (
    exists (
      select 1
      from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_id
        and (
          o.owner_user_id = (select auth.uid())
          or public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        )
    )
  )
  with check (
    exists (
      select 1
      from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_id
        and (
          (o.owner_user_id = (select auth.uid()) and i.is_verified)
          or public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        )
    )
  );

drop policy if exists course_batches_owner_delete on public.course_batches;
create policy course_batches_owner_delete on public.course_batches
  for delete to authenticated
  using (
    exists (
      select 1
      from public.courses c
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where c.id = course_id
        and (
          o.owner_user_id = (select auth.uid())
          or public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        )
    )
  );

-- Owners may read enrollments for their own batches (Approve/Reject).
drop policy if exists enrollments_owner_read on public.course_enrollments;
create policy enrollments_owner_read on public.course_enrollments
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1
      from public.course_batches b
      join public.courses c on c.id = b.course_id
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where b.id = batch_id
        and o.owner_user_id = (select auth.uid())
    )
    or public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );

drop policy if exists enrollments_owner_update on public.course_enrollments;
create policy enrollments_owner_update on public.course_enrollments
  for update to authenticated
  using (
    exists (
      select 1
      from public.course_batches b
      join public.courses c on c.id = b.course_id
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where b.id = batch_id
        and o.owner_user_id = (select auth.uid())
    )
    or public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );

-- ------------------------------------------------------------
-- ATOMIC ENROLL / DROP
-- ------------------------------------------------------------
create or replace function public.enroll_in_course_details(
  p_batch_id uuid,
  p_user_id uuid,
  p_is_trial boolean,
  p_student_name text,
  p_contact_phone text,
  p_preferred_start date
)
returns public.course_enrollments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch public.course_batches;
  v_existing public.course_enrollments;
  v_result public.course_enrollments;
  v_code text;
begin
  if (select auth.uid()) is distinct from p_user_id
     and not public.has_role((select auth.uid()), 'administrator')
     and not public.has_role((select auth.uid()), 'super_administrator') then
    raise exception 'not authorized';
  end if;

  select * into v_batch
  from public.course_batches
  where id = p_batch_id
  for update;

  if v_batch is null or not v_batch.is_active or not v_batch.admissions_open then
    raise exception 'batch not available';
  end if;

  select * into v_existing
  from public.course_enrollments
  where batch_id = p_batch_id
    and user_id = p_user_id
  for update;

  if v_existing.id is not null
     and v_existing.status in ('enrolled', 'trial', 'pending_approval') then
    raise exception 'already enrolled';
  end if;

  if not p_is_trial and v_batch.enrolled_count >= v_batch.capacity then
    if v_batch.waitlist_enabled then
      update public.course_batches
        set waitlist_count = waitlist_count + 1
        where id = p_batch_id;
      raise exception 'batch full';
    end if;
    raise exception 'batch full';
  end if;

  v_code := 'ADM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  if v_existing.id is not null then
    update public.course_enrollments
    set
      status = case when p_is_trial then 'trial' else 'enrolled' end,
      is_trial = p_is_trial,
      student_name = coalesce(nullif(p_student_name, ''), student_name),
      contact_phone = coalesce(nullif(p_contact_phone, ''), contact_phone),
      preferred_start = coalesce(p_preferred_start, preferred_start),
      admission_code = coalesce(admission_code, v_code)
    where id = v_existing.id
    returning * into v_result;
  else
    insert into public.course_enrollments (
      batch_id, user_id, status, is_trial, student_name, contact_phone,
      preferred_start, admission_code
    ) values (
      p_batch_id,
      p_user_id,
      case when p_is_trial then 'trial' else 'enrolled' end,
      p_is_trial,
      coalesce(p_student_name, ''),
      coalesce(p_contact_phone, ''),
      p_preferred_start,
      v_code
    )
    returning * into v_result;
  end if;

  if not p_is_trial then
    update public.course_batches
      set enrolled_count = enrolled_count + 1
      where id = p_batch_id
        and enrolled_count < capacity;
    if not found then
      update public.course_enrollments
        set status = 'dropped'
        where id = v_result.id and status = 'enrolled';
      raise exception 'batch full';
    end if;
  end if;

  return v_result;
end;
$$;

create or replace function public.enroll_in_course(p_batch_id uuid, p_user_id uuid)
returns public.course_enrollments
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.enroll_in_course_details(
    p_batch_id, p_user_id, false, '', '', null
  );
end;
$$;

create or replace function public.drop_course_enrollment(p_enrollment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enrollment public.course_enrollments;
begin
  select * into v_enrollment
  from public.course_enrollments
  where id = p_enrollment_id
  for update;

  if v_enrollment is null then
    return;
  end if;

  if (select auth.uid()) is distinct from v_enrollment.user_id
     and not public.has_role((select auth.uid()), 'administrator')
     and not public.has_role((select auth.uid()), 'super_administrator') then
    raise exception 'not authorized';
  end if;

  if v_enrollment.status not in ('enrolled', 'trial', 'pending_approval') then
    return;
  end if;

  update public.course_enrollments
    set status = 'dropped'
    where id = v_enrollment.id;

  if v_enrollment.status = 'enrolled' then
    update public.course_batches
      set enrolled_count = greatest(enrolled_count - 1, 0)
      where id = v_enrollment.batch_id;
  end if;
end;
$$;

create or replace function public.drop_course_enrollment(p_batch_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is distinct from p_user_id
     and not public.has_role((select auth.uid()), 'administrator')
     and not public.has_role((select auth.uid()), 'super_administrator') then
    raise exception 'not authorized';
  end if;

  select id into v_id
  from public.course_enrollments
  where batch_id = p_batch_id
    and user_id = p_user_id
    and status in ('enrolled', 'trial', 'pending_approval')
  for update;

  if v_id is null then
    return;
  end if;

  perform public.drop_course_enrollment(v_id);
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.enroll_in_course(uuid, uuid) to authenticated;
    grant execute on function public.enroll_in_course_details(uuid, uuid, boolean, text, text, date) to authenticated;
    grant execute on function public.drop_course_enrollment(uuid, uuid) to authenticated;
    grant execute on function public.drop_course_enrollment(uuid) to authenticated;
  end if;
end $$;
