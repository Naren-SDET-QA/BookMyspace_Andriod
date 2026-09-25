-- Capacity-safe enrollment: lock rejects a second seat on a 1-seat batch.
-- Run against a disposable database. Does not invent occupancy.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

create or replace function test_assert(p_label text, p_cond boolean) returns void
language plpgsql as $$
begin
  if p_cond then
    raise notice 'PASS: %', p_label;
  else
    raise exception 'FAIL: %', p_label;
  end if;
end;
$$;

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_org uuid;
  v_institute uuid;
  v_course uuid;
  v_batch uuid;
  v_first public.course_enrollments;
  v_second_failed boolean := false;
  v_count integer;
begin
  insert into auth.users (id) values (v_owner), (v_user_a), (v_user_b)
  on conflict do nothing;

  insert into public.organizations (owner_user_id, org_type, name)
  values (v_owner, 'institute_owner', 'Concurrency Institute')
  returning id into v_org;

  insert into public.institutes (org_id, name, is_verified)
  values (v_org, 'Lock Lab', true)
  returning id into v_institute;

  insert into public.courses (
    institute_id, title, mode, duration_weeks, fee_amount, status
  ) values (
    v_institute, 'Capacity Course', 'offline', 4, 1000, 'published'
  ) returning id into v_course;

  insert into public.course_batches (
    course_id, label, starts_on, capacity, enrolled_count, is_active,
    admissions_open, fee_amount, mode
  ) values (
    v_course, 'One Seat', current_date + 7, 1, 0, true, true, 1000, 'offline'
  ) returning id into v_batch;

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_first := public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '9000000001', null);
  perform test_assert('first enroll succeeds', v_first.status = 'enrolled');

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('enrolled_count is 1', v_count = 1);

  begin
    perform set_config('request.jwt.claim.sub', v_user_b::text, true);
    perform public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '9000000002', null);
  exception
    when others then
      v_second_failed := sqlerrm ilike '%batch full%';
  end;
  perform test_assert('second enroll is rejected as batch full', v_second_failed);

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('capacity not exceeded after rejected enroll', v_count = 1);

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  perform public.drop_course_enrollment(v_first.id);
  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('drop frees the seat', v_count = 0);

  perform set_config('request.jwt.claim.sub', v_user_b::text, true);
  v_first := public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '9000000002', null);
  perform test_assert('freed seat can be taken', v_first.status = 'enrolled');

  delete from public.course_enrollments where batch_id = v_batch;
  delete from public.course_batches where id = v_batch;
  delete from public.courses where id = v_course;
  delete from public.institutes where id = v_institute;
  delete from public.organizations where id = v_org;
end;
$$;
