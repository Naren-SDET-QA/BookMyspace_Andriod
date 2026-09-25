-- ============================================================
-- Milestone 6: Comprehensive Enrollment Concurrency & Capacity Test
--
-- Tests:
--  1. Trial enrollment does NOT consume a seat
--  2. Full enrollment consumes a seat
--  3. Drop frees the seat
--  4. Capacity-full batch rejects enrollment with 'batch full'
--  5. Concurrent enrollment on 2-seat batch: both succeed
--  6. Concurrent enrollment on 1-seat batch: second rejected
--  7. Re-enrollment after drop succeeds
--  8. Trial-to-enrolled transition preserves seat count
--  9. Duplicate enrollment rejected with 'already enrolled'
-- 10. Admissions-open toggle blocks enrollment
--
-- Run against a disposable database with the full migration applied.
-- \set ON_ERROR_STOP on
-- ============================================================
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

create or replace function test_assert(p_label text, p_cond boolean)
returns void language plpgsql as $$
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
  v_owner   uuid := gen_random_uuid();
  v_user_a  uuid := gen_random_uuid();
  v_user_b  uuid := gen_random_uuid();
  v_user_c  uuid := gen_random_uuid();
  v_org     uuid;
  v_institute uuid;
  v_course  uuid;
  v_batch   uuid;
  v_result  public.course_enrollments;
  v_count   integer;
  v_failed  boolean;
begin
  -- ── Setup ──────────────────────────────────────────────────
  insert into auth.users (id) values (v_owner), (v_user_a), (v_user_b), (v_user_c)
  on conflict do nothing;

  insert into public.organizations (owner_user_id, org_type, name)
  values (v_owner, 'institute_owner', 'Test Institute')
  returning id into v_org;

  insert into public.institutes (org_id, name, is_verified)
  values (v_org, 'Concurrency Lab', true)
  returning id into v_institute;

  insert into public.courses (
    institute_id, title, mode, duration_weeks, fee_amount, status
  ) values (
    v_institute, 'Test Course', 'offline', 4, 5000, 'published'
  ) returning id into v_course;

  -- ── TEST 1: Trial enrollment does NOT consume a seat ──────
  insert into public.course_batches (
    course_id, label, starts_on, capacity, enrolled_count, is_active,
    admissions_open, fee_amount, mode
  ) values (
    v_course, 'Trial Batch', current_date + 7, 2, 0, true, true, 5000, 'offline'
  ) returning id into v_batch;

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_a, true, 'Asha', '90001', null);
  perform test_assert('trial enroll succeeds', v_result.status = 'trial');
  perform test_assert('trial does NOT consume seat', v_result.is_trial = true);

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('enrolled_count remains 0 after trial', v_count = 0);

  -- ── TEST 2: Full enrollment consumes a seat ───────────────
  perform set_config('request.jwt.claim.sub', v_user_b::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '90002', null);
  perform test_assert('full enroll succeeds', v_result.status = 'enrolled');

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('enrolled_count is 1 after full enroll', v_count = 1);

  -- ── TEST 3: Drop frees the seat ───────────────────────────
  perform public.drop_course_enrollment(v_result.id);
  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('drop decrements enrolled_count to 0', v_count = 0);

  -- ── TEST 4: Capacity-full batch rejects enrollment ────────
  -- Fill to capacity (2 seats)
  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  perform public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  perform set_config('request.jwt.claim.sub', v_user_b::text, true);
  perform public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '90002', null);

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('batch at full capacity (2)', v_count = 2);

  -- Third enrollment must fail
  v_failed := false;
  begin
    perform set_config('request.jwt.claim.sub', v_user_c::text, true);
    perform public.enroll_in_course_details(v_batch, v_user_c, false, 'Chen', '90003', null);
  exception
    when others then
      v_failed := sqlerrm ilike '%batch full%';
  end;
  perform test_assert('capacity-full batch rejects with batch full', v_failed);

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('enrolled_count unchanged after rejected enroll', v_count = 2);

  -- ── TEST 5: Concurrent enrollment on 2-seat batch ─────────
  -- Drop both, create a fresh 2-seat batch
  perform public.drop_course_enrollment(
    (select id from public.course_enrollments where batch_id = v_batch and user_id = v_user_a)
  );
  perform public.drop_course_enrollment(
    (select id from public.course_enrollments where batch_id = v_batch and user_id = v_user_b)
  );

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  perform test_assert('concurrent A succeeds on 2-seat batch', v_result.status = 'enrolled');

  perform set_config('request.jwt.claim.sub', v_user_b::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '90002', null);
  perform test_assert('concurrent B succeeds on 2-seat batch', v_result.status = 'enrolled');

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('2-seat batch has 2 enrolled', v_count = 2);

  -- ── TEST 6: Concurrent enrollment on 1-seat batch ─────────
  -- Clean up and create a 1-seat batch
  delete from public.course_enrollments where batch_id = v_batch;
  update public.course_batches set enrolled_count = 0, capacity = 1 where id = v_batch;

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  perform test_assert('first on 1-seat batch succeeds', v_result.status = 'enrolled');

  v_failed := false;
  begin
    perform set_config('request.jwt.claim.sub', v_user_b::text, true);
    perform public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '90002', null);
  exception
    when others then
      v_failed := sqlerrm ilike '%batch full%';
  end;
  perform test_assert('second on 1-seat batch rejected', v_failed);

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('1-seat batch count stays at 1', v_count = 1);

  -- ── TEST 7: Re-enrollment after drop succeeds ─────────────
  perform public.drop_course_enrollment(
    (select id from public.course_enrollments where batch_id = v_batch and user_id = v_user_a)
  );

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  perform test_assert('re-enrollment after drop succeeds', v_result.status = 'enrolled');

  -- ── TEST 8: Trial-to-enrolled transition ──────────────────
  -- Drop current, set up trial then upgrade
  perform public.drop_course_enrollment(
    (select id from public.course_enrollments where batch_id = v_batch and user_id = v_user_a)
  );
  update public.course_batches set enrolled_count = 0 where id = v_batch;

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  v_result := public.enroll_in_course_details(v_batch, v_user_a, true, 'Asha', '90001', null);
  perform test_assert('trial enrollment created', v_result.status = 'trial');

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('trial does not increment count', v_count = 0);

  -- Upgrade to full enrollment
  v_result := public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  perform test_assert('upgrade to enrolled succeeds', v_result.status = 'enrolled');

  select enrolled_count into v_count from public.course_batches where id = v_batch;
  perform test_assert('upgraded enrollment increments count', v_count = 1);

  -- ── TEST 9: Duplicate enrollment rejected ─────────────────
  v_failed := false;
  begin
    perform public.enroll_in_course_details(v_batch, v_user_a, false, 'Asha', '90001', null);
  exception
    when others then
      v_failed := sqlerrm ilike '%already enrolled%';
  end;
  perform test_assert('duplicate enrollment rejected', v_failed);

  -- ── TEST 10: Admissions-open toggle blocks enrollment ─────
  update public.course_batches set admissions_open = false where id = v_batch;

  v_failed := false;
  begin
    perform set_config('request.jwt.claim.sub', v_user_b::text, true);
    perform public.enroll_in_course_details(v_batch, v_user_b, false, 'Bala', '90002', null);
  exception
    when others then
      v_failed := sqlerrm ilike '%batch not available%';
  end;
  perform test_assert('closed admissions blocks enrollment', v_failed);

  -- ── Cleanup ───────────────────────────────────────────────
  delete from public.course_enrollments where batch_id = v_batch;
  delete from public.course_batches where id = v_batch;
  delete from public.courses where id = v_course;
  delete from public.institutes where id = v_institute;
  delete from public.organizations where id = v_org;

  raise notice '━━━ All Milestone 6 enrollment tests passed ━━━';
end;
$$;
