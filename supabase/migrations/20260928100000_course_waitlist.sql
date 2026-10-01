-- B1: real per-user waitlist for full course batches.
--
-- Bug fixed: enroll_in_course_details incremented waitlist_count and then
-- raised 'batch full', so the increment was always rolled back and nobody
-- was ever recorded. The waitlist is now its own table; waitlist_count is
-- kept in sync from it. When a seat opens (a drop), the first waiting
-- learner is marked 'offered' and notified. Seats are not held: the
-- offered learner still enrolls through the normal capacity-safe RPC.
-- Idempotent, additive.

create table if not exists public.course_waitlist (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.course_batches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'waiting'
    check (status in ('waiting', 'offered', 'enrolled', 'cancelled')),
  created_at timestamptz not null default now(),
  offered_at timestamptz,
  updated_at timestamptz not null default now()
);

create unique index if not exists course_waitlist_active_uidx
  on public.course_waitlist (batch_id, user_id)
  where status in ('waiting', 'offered');
create index if not exists idx_course_waitlist_batch_queue
  on public.course_waitlist (batch_id, created_at)
  where status = 'waiting';
create index if not exists idx_course_waitlist_user
  on public.course_waitlist (user_id);

alter table public.course_waitlist enable row level security;

drop policy if exists course_waitlist_own_read on public.course_waitlist;
create policy course_waitlist_own_read on public.course_waitlist
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_platform_admin((select auth.uid()))
    or exists (
      select 1
      from public.course_batches b
      join public.courses c on c.id = b.course_id
      join public.institutes i on i.id = c.institute_id
      join public.organizations o on o.id = i.org_id
      where b.id = batch_id
        and o.owner_user_id = (select auth.uid())
    )
  );
-- Writes only through the RPCs below.

create or replace function public.sync_course_waitlist_count(p_batch_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.course_batches b
     set waitlist_count = (
       select count(*) from public.course_waitlist w
       where w.batch_id = p_batch_id and w.status in ('waiting', 'offered')
     )
   where b.id = p_batch_id;
$$;

-- Join the waitlist. Returns the learner's 1-based position.
create or replace function public.join_course_waitlist(p_batch_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_batch public.course_batches;
  v_row public.course_waitlist;
  v_pos integer;
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;

  select * into v_batch from public.course_batches
   where id = p_batch_id for update;
  if v_batch.id is null or not v_batch.is_active then
    raise exception 'batch not available';
  end if;
  if not v_batch.waitlist_enabled then
    raise exception 'waitlist not enabled';
  end if;
  if v_batch.enrolled_count < v_batch.capacity and v_batch.admissions_open then
    raise exception 'seats available';
  end if;
  if exists (
    select 1 from public.course_enrollments
     where batch_id = p_batch_id and user_id = v_uid
       and status in ('enrolled', 'trial', 'pending_approval')
  ) then
    raise exception 'already enrolled';
  end if;

  select * into v_row from public.course_waitlist
   where batch_id = p_batch_id and user_id = v_uid
     and status in ('waiting', 'offered');
  if v_row.id is null then
    insert into public.course_waitlist (batch_id, user_id)
    values (p_batch_id, v_uid)
    returning * into v_row;
    perform public.sync_course_waitlist_count(p_batch_id);
  end if;

  if v_row.status = 'offered' then
    return 0;
  end if;

  select count(*) into v_pos from public.course_waitlist
   where batch_id = p_batch_id and status = 'waiting'
     and created_at <= v_row.created_at;
  return v_pos;
end;
$$;

create or replace function public.leave_course_waitlist(p_batch_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  update public.course_waitlist
     set status = 'cancelled', updated_at = now()
   where batch_id = p_batch_id and user_id = v_uid
     and status in ('waiting', 'offered');
  if found then
    perform public.sync_course_waitlist_count(p_batch_id);
  end if;
end;
$$;

-- My active waitlist entries: batch id, status, position (0 = seat offered).
create or replace function public.my_course_waitlist()
returns table (batch_id uuid, status text, queue_position integer)
language sql
stable
security definer
set search_path = public
as $$
  select w.batch_id,
         w.status,
         case when w.status = 'offered' then 0 else (
           select count(*)::int from public.course_waitlist q
            where q.batch_id = w.batch_id and q.status = 'waiting'
              and q.created_at <= w.created_at
         ) end
    from public.course_waitlist w
   where w.user_id = (select auth.uid())
     and w.status in ('waiting', 'offered');
$$;

-- Offer freed seats to the next waiting learners and notify them.
create or replace function public.promote_course_waitlist(p_batch_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch public.course_batches;
  v_free integer;
  v_offered integer;
  v_title text;
  v_row record;
  v_count integer := 0;
begin
  select * into v_batch from public.course_batches where id = p_batch_id;
  if v_batch.id is null or not v_batch.waitlist_enabled then
    return 0;
  end if;

  select count(*) into v_offered from public.course_waitlist
   where batch_id = p_batch_id and status = 'offered';
  v_free := v_batch.capacity - v_batch.enrolled_count - v_offered;
  if v_free <= 0 then
    return 0;
  end if;

  select c.title into v_title from public.courses c where c.id = v_batch.course_id;

  for v_row in
    select id, user_id from public.course_waitlist
     where batch_id = p_batch_id and status = 'waiting'
     order by created_at
     limit v_free
     for update skip locked
  loop
    update public.course_waitlist
       set status = 'offered', offered_at = now(), updated_at = now()
     where id = v_row.id;

    insert into public.notifications (user_id, type, title, body, data, dedupe_key)
    values (
      v_row.user_id,
      'course_waitlist_seat',
      'A seat opened up',
      'A seat is now available in ' || coalesce(v_title, 'your class')
        || coalesce(' (' || nullif(v_batch.label, '') || ')', '')
        || '. Enroll now to secure it.',
      jsonb_build_object(
        'route', '/courses/' || v_batch.course_id,
        'course_id', v_batch.course_id,
        'batch_id', p_batch_id
      ),
      'waitlist_offer:' || v_row.id
    )
    on conflict do nothing;

    v_count := v_count + 1;
  end loop;

  perform public.sync_course_waitlist_count(p_batch_id);
  return v_count;
end;
$$;

-- Enrollment: 'batch full' now leaves no side effects. An offered learner
-- enrolling marks their waitlist row 'enrolled'.
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
  v_other_offers integer;
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

  if not p_is_trial then
    -- Seats offered to other waitlisted learners are reserved for them.
    select count(*) into v_other_offers from public.course_waitlist
     where batch_id = p_batch_id and status = 'offered'
       and user_id <> p_user_id;
    if v_batch.enrolled_count + v_other_offers >= v_batch.capacity then
      raise exception 'batch full';
    end if;
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
      raise exception 'batch full';
    end if;

    update public.course_waitlist
       set status = 'enrolled', updated_at = now()
     where batch_id = p_batch_id and user_id = p_user_id
       and status in ('waiting', 'offered');
    if found then
      perform public.sync_course_waitlist_count(p_batch_id);
    end if;
  end if;

  return v_result;
end;
$$;

-- Drop: free the seat, then offer it to the waitlist.
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
    perform public.promote_course_waitlist(v_enrollment.batch_id);
  end if;
end;
$$;

-- Owners raising capacity or enabling the waitlist also frees seats.
create or replace function public.course_batches_promote_waitlist_trg()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.waitlist_enabled
     and (new.capacity > old.capacity or not old.waitlist_enabled) then
    perform public.promote_course_waitlist(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists course_batches_promote_waitlist on public.course_batches;
create trigger course_batches_promote_waitlist
  after update of capacity, waitlist_enabled on public.course_batches
  for each row
  when (pg_trigger_depth() < 1)
  execute function public.course_batches_promote_waitlist_trg();

revoke all on function public.sync_course_waitlist_count(uuid) from public, anon, authenticated;
revoke all on function public.promote_course_waitlist(uuid) from public, anon, authenticated;
revoke all on function public.course_batches_promote_waitlist_trg() from public, anon, authenticated;
revoke all on function public.join_course_waitlist(uuid) from public, anon;
revoke all on function public.leave_course_waitlist(uuid) from public, anon;
revoke all on function public.my_course_waitlist() from public, anon;
revoke all on function public.enroll_in_course_details(uuid, uuid, boolean, text, text, date) from public, anon;
revoke all on function public.drop_course_enrollment(uuid) from public, anon;
grant execute on function public.join_course_waitlist(uuid) to authenticated;
grant execute on function public.leave_course_waitlist(uuid) to authenticated;
grant execute on function public.my_course_waitlist() to authenticated;
grant execute on function public.enroll_in_course_details(uuid, uuid, boolean, text, text, date) to authenticated;
grant execute on function public.drop_course_enrollment(uuid) to authenticated;
