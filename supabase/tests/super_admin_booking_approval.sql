-- Security contract for request-to-book approval by the venue owner OR a
-- platform administrator (migration 20261003160000_super_admin_booking_approval.sql).
--
-- Self-contained: creates its own users, organizations, venues, slots,
-- holds and bookings inside one transaction and ROLLS BACK at the end, so it
-- leaves no data behind. Any failed expectation raises an exception.
--
-- Scenarios
--   1  owner approves                         -> success, status pending
--   2  super_administrator approves           -> success, status pending
--   3  administrator approves                 -> success, status pending
--   4  owner rejects                          -> success, owner_rejected
--   5  super_administrator rejects            -> success, owner_rejected
--   6  customer approves / rejects            -> NOT_OWNER_OR_NOT_FOUND
--   7  anonymous approves / rejects           -> NOT_OWNER_OR_NOT_FOUND (+ no anon grant)
--   8  different venue owner                  -> NOT_OWNER_OR_NOT_FOUND
--   9  already approved by someone else       -> ALREADY_PROCESSED
--  10  already rejected                       -> INVALID_STATUS
--  11  cancelled                              -> INVALID_STATUS
--  12  approval window expired                -> APPROVAL_EXPIRED
--  13  owner and admin race                   -> exactly one approval wins
--      (sequential in one session; the real race is serialized by the
--      booking row lock FOR UPDATE taken before the status check)
--  14  other categories (hotel)               -> admin can approve too; owner unchanged
--  15  a new request notifies every admin (not the owner twice, not the customer)
--  16  that notification names the customer, venue, date, time and owner
--  plus: payment gate intact (approved booking is `pending`, not
--  `confirmed`), hold kept active, audit actor_role recorded.

begin;

create or replace function pg_temp.as_user(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('request.jwt.claims',
    case when p_uid is null then '' else json_build_object('sub', p_uid, 'role', 'authenticated')::text end,
    true);
end $$;

create or replace function pg_temp.mk_booking(
  p_venue uuid, p_slot uuid, p_customer uuid, p_day int,
  p_status public.booking_status default 'awaiting_owner_approval',
  p_approval_expires timestamptz default now() + interval '2 hours'
) returns uuid
language plpgsql as $$
declare
  v_hold uuid;
  v_booking uuid;
  v_start time;
  v_end time;
begin
  select start_time, end_time into v_start, v_end from public.time_slots where id = p_slot;
  insert into public.booking_holds (idempotency_key, venue_id, slot_id, book_date, user_id,
    price_amount, expires_at, status)
  values (gen_random_uuid(), p_venue, p_slot, current_date + p_day, p_customer,
    1000, now() + interval '2 hours', 'active')
  returning id into v_hold;
  insert into public.bookings (booking_ref, user_id, venue_id, slot_id, book_date,
    start_time, end_time, amount, total_amount, status, hold_id,
    approval_required, approval_requested_at, approval_expires_at)
  values ('SAT-' || substr(md5(random()::text), 1, 10), p_customer, p_venue, p_slot,
    current_date + p_day, v_start, v_end, 1000, 1000, p_status, v_hold,
    true, now(), p_approval_expires)
  returning id into v_booking;
  return v_booking;
end $$;

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_other_owner uuid := gen_random_uuid();
  v_super uuid := gen_random_uuid();
  v_admin uuid := gen_random_uuid();
  v_customer uuid := gen_random_uuid();
  v_fh_cat uuid;
  v_hotel_cat uuid;
  v_org uuid;
  v_other_org uuid;
  v_fh_venue uuid;
  v_hotel_venue uuid;
  v_other_venue uuid;
  v_fh_slot uuid;
  v_hotel_slot uuid;
  v_b uuid;
  r jsonb;
  r2 jsonb;
  v_status text;
  v_role text;
  v_hold_status text;
begin
  insert into auth.users (id, email) values
    (v_owner, 'sat_owner_' || v_owner || '@test.invalid'),
    (v_other_owner, 'sat_other_' || v_other_owner || '@test.invalid'),
    (v_super, 'sat_super_' || v_super || '@test.invalid'),
    (v_admin, 'sat_admin_' || v_admin || '@test.invalid'),
    (v_customer, 'sat_cust_' || v_customer || '@test.invalid');
  insert into public.user_roles (user_id, role) values
    (v_owner, 'venue_owner'), (v_other_owner, 'venue_owner'),
    (v_super, 'super_administrator'), (v_admin, 'administrator'),
    (v_customer, 'customer')
  on conflict do nothing;

  insert into public.venue_categories (slug, name, parent_section)
  values ('function_hall', 'Function Hall', 'function_halls')
  on conflict (slug) do nothing;
  insert into public.venue_categories (slug, name, parent_section)
  values ('hotel', 'Hotel', 'lodge_rooms')
  on conflict (slug) do nothing;
  select id into v_fh_cat from public.venue_categories where slug = 'function_hall';
  select id into v_hotel_cat from public.venue_categories where slug = 'hotel';

  insert into public.organizations (owner_user_id, org_type, name)
  values (v_owner, 'venue_owner', 'SAT Owner Org') returning id into v_org;
  insert into public.organizations (owner_user_id, org_type, name)
  values (v_other_owner, 'venue_owner', 'SAT Other Org') returning id into v_other_org;

  insert into public.venues (org_id, name, latitude, longitude, category_id, is_active)
  values (v_org, 'SAT Function Hall', 17.38, 78.48, v_fh_cat, true) returning id into v_fh_venue;
  insert into public.venues (org_id, name, latitude, longitude, category_id, is_active)
  values (v_org, 'SAT Hotel', 17.38, 78.48, v_hotel_cat, true) returning id into v_hotel_venue;
  insert into public.venues (org_id, name, latitude, longitude, category_id, is_active)
  values (v_other_org, 'SAT Other Hall', 17.38, 78.48, v_fh_cat, true) returning id into v_other_venue;

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount, is_active)
  values (v_fh_venue, 'Evening', '18:00', '22:00', 1000, true) returning id into v_fh_slot;
  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount, is_active)
  values (v_hotel_venue, 'Night', '14:00', '23:00', 1000, true) returning id into v_hotel_slot;

  -- 7: no anonymous grant at all
  if has_function_privilege('anon', 'public.approve_venue_booking(uuid,uuid,integer)', 'execute')
     or has_function_privilege('anon', 'public.reject_venue_booking(uuid,uuid,text)', 'execute') then
    raise exception '7: anon must not be able to execute approval RPCs';
  end if;

  -- 1: owner approves -> pending (payment gate intact), hold kept, audit role
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 10);
  perform pg_temp.as_user(v_owner);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'pending' then
    raise exception '1: owner approve failed: % / %', r, v_status;
  end if;
  select h.status::text into v_hold_status from public.booking_holds h
    join public.bookings b on b.hold_id = h.id where b.id = v_b;
  if v_hold_status <> 'active' then
    raise exception '1: hold must stay active until payment, got %', v_hold_status;
  end if;
  select details->>'actor_role' into v_role from public.audit_logs
    where entity_id = v_b and action = 'booking_owner_approved' order by created_at desc limit 1;
  if v_role is distinct from 'venue_owner' then
    raise exception '1: audit actor_role expected venue_owner, got %', v_role;
  end if;
  -- same owner repeating keeps the old idempotent success
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if (r->>'success')::boolean is not true or (r->>'idempotent')::boolean is not true then
    raise exception '1: owner repeat must stay idempotent success: %', r;
  end if;
  -- 9: a different authorized person approving afterwards is refused
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if r->>'error_code' is distinct from 'ALREADY_PROCESSED' then
    raise exception '9: second approver must get ALREADY_PROCESSED: %', r;
  end if;

  -- 2: super admin approves
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 11);
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'pending' then
    raise exception '2: super admin approve failed: % / %', r, v_status;
  end if;
  select details->>'actor_role' into v_role from public.audit_logs
    where entity_id = v_b and action = 'booking_admin_approved' order by created_at desc limit 1;
  if v_role is distinct from 'super_admin' then
    raise exception '2: audit actor_role expected super_admin, got %', v_role;
  end if;
  -- owner afterwards sees it processed
  perform pg_temp.as_user(v_owner);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if r->>'error_code' is distinct from 'ALREADY_PROCESSED' then
    raise exception '2: owner after admin must get ALREADY_PROCESSED: %', r;
  end if;
  r := public.reject_venue_booking(v_b, gen_random_uuid(), 'late');
  if r->>'error_code' is distinct from 'INVALID_STATUS' then
    raise exception '2: owner reject after admin approval must get INVALID_STATUS: %', r;
  end if;

  -- 3: administrator approves
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 12);
  perform pg_temp.as_user(v_admin);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'pending' or r->>'actor_role' <> 'administrator' then
    raise exception '3: administrator approve failed: % / %', r, v_status;
  end if;

  -- 4: owner rejects
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 13);
  perform pg_temp.as_user(v_owner);
  r := public.reject_venue_booking(v_b, gen_random_uuid(), 'Owner busy');
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'owner_rejected' then
    raise exception '4: owner reject failed: % / %', r, v_status;
  end if;
  -- 10: approving a rejected request is refused
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if r->>'error_code' is distinct from 'INVALID_STATUS' then
    raise exception '10: approve after reject must get INVALID_STATUS: %', r;
  end if;

  -- 5: super admin rejects; hold released; reason stored; audit role
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 14);
  perform pg_temp.as_user(v_super);
  r := public.reject_venue_booking(v_b, gen_random_uuid(), 'Policy');
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'owner_rejected' then
    raise exception '5: super admin reject failed: % / %', r, v_status;
  end if;
  select h.status::text into v_hold_status from public.booking_holds h
    join public.bookings b on b.hold_id = h.id where b.id = v_b;
  if v_hold_status <> 'released' then
    raise exception '5: hold must be released on reject, got %', v_hold_status;
  end if;
  select details->>'actor_role' into v_role from public.audit_logs
    where entity_id = v_b and action = 'booking_admin_rejected' order by created_at desc limit 1;
  if v_role is distinct from 'super_admin' then
    raise exception '5: audit actor_role expected super_admin, got %', v_role;
  end if;

  -- 6, 7, 8: customer, anonymous, different owner are refused and nothing changes
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 15);
  perform pg_temp.as_user(v_customer);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  r2 := public.reject_venue_booking(v_b, gen_random_uuid(), 'x');
  if r->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND'
     or r2->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND' then
    raise exception '6: customer must be refused: % / %', r, r2;
  end if;
  perform pg_temp.as_user(null);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  r2 := public.reject_venue_booking(v_b, gen_random_uuid(), 'x');
  if r->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND'
     or r2->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND' then
    raise exception '7: anonymous must be refused: % / %', r, r2;
  end if;
  perform pg_temp.as_user(v_other_owner);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  r2 := public.reject_venue_booking(v_b, gen_random_uuid(), 'x');
  if r->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND'
     or r2->>'error_code' is distinct from 'NOT_OWNER_OR_NOT_FOUND' then
    raise exception '8: different owner must be refused: % / %', r, r2;
  end if;
  select status::text into v_status from public.bookings where id = v_b;
  if v_status <> 'awaiting_owner_approval' then
    raise exception '6-8: refused callers must not change the booking, got %', v_status;
  end if;

  -- 11: cancelled
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 16, 'cancelled');
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if r->>'error_code' is distinct from 'INVALID_STATUS' then
    raise exception '11: approve of cancelled must get INVALID_STATUS: %', r;
  end if;

  -- 12: expired approval window
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 17,
    'awaiting_owner_approval', now() - interval '1 minute');
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if r->>'error_code' is distinct from 'APPROVAL_EXPIRED' or v_status <> 'approval_expired' then
    raise exception '12: expired must get APPROVAL_EXPIRED: % / %', r, v_status;
  end if;

  -- 13: owner vs admin, both directions: exactly one approval recorded
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 18);
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  perform pg_temp.as_user(v_owner);
  r2 := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if (r->>'success')::boolean is not true or r2->>'error_code' is distinct from 'ALREADY_PROCESSED' then
    raise exception '13a: admin-then-owner race: % / %', r, r2;
  end if;
  if (select count(*) from public.audit_logs where entity_id = v_b
        and action in ('booking_owner_approved', 'booking_admin_approved')) <> 1 then
    raise exception '13a: exactly one approval audit row expected';
  end if;
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 19);
  perform pg_temp.as_user(v_owner);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  perform pg_temp.as_user(v_admin);
  r2 := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  if (r->>'success')::boolean is not true or r2->>'error_code' is distinct from 'ALREADY_PROCESSED' then
    raise exception '13b: owner-then-admin race: % / %', r, r2;
  end if;
  if (select count(*) from public.notifications where user_id = v_customer
        and data->>'booking_id' = v_b::text and title = 'Booking request accepted') <> 1 then
    raise exception '13b: customer must get exactly one acceptance notification';
  end if;

  -- 14: other categories: admin may approve/decline too, owner unchanged
  v_b := pg_temp.mk_booking(v_hotel_venue, v_hotel_slot, v_customer, 20);
  perform pg_temp.as_user(v_super);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'pending' then
    raise exception '14: admin approval of hotel booking failed: % / %', r, v_status;
  end if;
  v_b := pg_temp.mk_booking(v_hotel_venue, v_hotel_slot, v_customer, 21);
  perform pg_temp.as_user(v_admin);
  r := public.reject_venue_booking(v_b, gen_random_uuid(), 'Not available');
  if (r->>'success')::boolean is not true then
    raise exception '14: admin decline of hotel booking failed: %', r;
  end if;
  v_b := pg_temp.mk_booking(v_hotel_venue, v_hotel_slot, v_customer, 22);
  perform pg_temp.as_user(v_owner);
  r := public.approve_venue_booking(v_b, gen_random_uuid(), 60);
  select status::text into v_status from public.bookings where id = v_b;
  if (r->>'success')::boolean is not true or v_status <> 'pending' then
    raise exception '14: owner approval of hotel booking must work as before: % / %', r, v_status;
  end if;

  -- 15: a new request notifies each admin once; owner/customer not via trigger
  v_b := pg_temp.mk_booking(v_fh_venue, v_fh_slot, v_customer, 23);
  if (select count(*) from public.notifications where data->>'booking_id' = v_b::text
        and data->>'audience' = 'admin' and user_id in (v_super, v_admin)) <> 2 then
    raise exception '15: both admins must get exactly one request notification';
  end if;
  if exists (select 1 from public.notifications where data->>'booking_id' = v_b::text
        and data->>'audience' = 'admin' and user_id in (v_owner, v_customer, v_other_owner)) then
    raise exception '15: admin notification must not go to owner/customer';
  end if;
  if not exists (select 1 from public.notifications where data->>'booking_id' = v_b::text
        and user_id = v_super and body like '%SAT Function Hall%' and body like '%Owner:%') then
    raise exception '15: admin notification must name the venue and owner';
  end if;

  -- 16: the admin notification names customer, venue, date, time and owner
  insert into public.profiles (id, full_name) values (v_customer, 'Ravi Kumar')
  on conflict (id) do update set full_name = excluded.full_name;
  insert into public.profiles (id, full_name) values (v_owner, 'Lakshmi Rao')
  on conflict (id) do update set full_name = excluded.full_name;
  v_b := pg_temp.mk_booking(v_hotel_venue, v_hotel_slot, v_customer, 24);
  select n.body into v_status from public.notifications n
   where n.user_id = v_admin and n.data->>'booking_id' = v_b::text
     and n.data->>'audience' = 'admin';
  if v_status is distinct from format(
       'Ravi Kumar requested SAT Hotel on %s (14:00-23:00). Owner: Lakshmi Rao. You or the owner can approve.',
       to_char(current_date + 24, 'DD Mon YYYY')) then
    raise exception '16: unexpected admin notification body: %', v_status;
  end if;

  raise notice 'super_admin_booking_approval: all scenarios passed';
end $$;

rollback;
