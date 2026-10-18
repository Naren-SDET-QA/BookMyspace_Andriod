-- Preserve an existing trial enrollment when the learner upgrades to a paid seat.
-- Historical migration 20260928100000 rejected every active row before reaching
-- its existing update-in-place path, making the trial-to-enrolled transition
-- unreachable. This forward-only replacement allows only that transition.
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
     and (
       v_existing.status in ('enrolled', 'pending_approval')
       or (v_existing.status = 'trial' and p_is_trial)
     ) then
    raise exception 'already enrolled';
  end if;

  if not p_is_trial then
    select count(*) into v_other_offers
    from public.course_waitlist
    where batch_id = p_batch_id
      and status = 'offered'
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
    where batch_id = p_batch_id
      and user_id = p_user_id
      and status in ('waiting', 'offered');

    if found then
      perform public.sync_course_waitlist_count(p_batch_id);
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function public.enroll_in_course_details(uuid, uuid, boolean, text, text, date) from public, anon;
grant execute on function public.enroll_in_course_details(uuid, uuid, boolean, text, text, date) to authenticated;
