-- Transactional fixtures. Run on a disposable database after migrations.
-- No source records are deleted; all fixtures and temporary policies roll back.
begin;

insert into auth.users(id,email) values
  ('ae000000-0000-4000-8000-000000000001','marketplace-fixture@example.invalid');
insert into public.organizations(id,owner_user_id,org_type,name) values
  ('ae000000-0000-4000-8000-000000000002','ae000000-0000-4000-8000-000000000001','venue_owner','Marketplace Test Org');
insert into public.venues(id,org_id,name,city,latitude,longitude,pricing_base_amount,is_active,is_verified) values
  ('ae000000-0000-4000-8000-000000000003','ae000000-0000-4000-8000-000000000002','Catalog music studio','Marketplace QA City',17,78,300,true,true),
  ('ae000000-0000-4000-8000-000000000004','ae000000-0000-4000-8000-000000000002','Catalog inactive','Marketplace QA City',17,78,100,false,true);
insert into public.events(id,org_id,venue_id,category,title,starts_at,ends_at,capacity,ticket_price,is_free,status) values
  ('ae000000-0000-4000-8000-000000000005','ae000000-0000-4000-8000-000000000002','ae000000-0000-4000-8000-000000000003','workshop','Catalog music evening',now()+interval '1 day',now()+interval '2 days',10,500,false,'published'),
  ('ae000000-0000-4000-8000-000000000006','ae000000-0000-4000-8000-000000000002','ae000000-0000-4000-8000-000000000003','workshop','Catalog private draft',now()+interval '1 day',now()+interval '2 days',10,500,false,'draft');
insert into public.institutes(id,org_id,name,city) values
  ('ae000000-0000-4000-8000-000000000007','ae000000-0000-4000-8000-000000000002','Catalog Institute','Marketplace QA City');
insert into public.courses(id,institute_id,title,mode,duration_weeks,fee_amount,status) values
  ('ae000000-0000-4000-8000-000000000008','ae000000-0000-4000-8000-000000000007','Catalog music class','offline',4,900,'published');
insert into public.course_batches(course_id,label,starts_on,capacity) values
  ('ae000000-0000-4000-8000-000000000008','Catalog Batch',current_date+3,10);
insert into public.venue_images(id,venue_id,url,is_cover,sort_order) values
  ('ae000000-0000-4000-8000-000000000009','ae000000-0000-4000-8000-000000000003','https://example.invalid/catalog.png',true,0);

-- Test fixtures should be published even on schemas with an owner workflow.
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='venues' and column_name='listing_status') then
    execute 'update public.venues set listing_status = ''published'' where id = ''ae000000-0000-4000-8000-000000000003''';
  end if;
end $$;

-- Keep optional module state deterministic inside this rolled-back test only.
insert into public.feature_flags(key,enabled,platforms) values
  ('events',true,array['ios','android','web']), ('courses',true,array['ios','android','web'])
on conflict(key) do update set enabled=true,platforms=excluded.platforms;

do $$
declare n integer; first_id uuid; second_id uuid;
begin
  select count(*) into n from public.marketplace_search(p_city=>'Marketplace QA City');
  if n <> 3 then raise exception 'Expected three published catalog fixtures, got %', n; end if;
  select count(*) into n from public.marketplace_search(p_query=>'music',p_city=>'Marketplace QA City',p_category=>'events');
  if n <> 1 then raise exception 'Full-text/category filter failed'; end if;
  select count(*) into n from public.marketplace_search(p_city=>'Marketplace QA City',p_max_price=>500);
  if n <> 2 then raise exception 'Price filter failed'; end if;
  select count(*) into n from public.marketplace_search(p_city=>'Marketplace QA City',p_from=>now());
  if n <> 2 then raise exception 'Date filtering must exclude unscheduled venues'; end if;
  select id into first_id from public.marketplace_search(p_city=>'Marketplace QA City',p_sort=>'price_low',p_limit=>1);
  select id into second_id from public.marketplace_search(p_city=>'Marketplace QA City',p_sort=>'price_low',p_limit=>1,p_offset=>1);
  if first_id <> 'ae000000-0000-4000-8000-000000000003' or second_id <> 'ae000000-0000-4000-8000-000000000005' then
    raise exception 'Stable pagination/order failed';
  end if;
  begin
    perform public.marketplace_search(p_limit=>1000);
    raise exception 'Unbounded page was accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.marketplace_search(p_max_price=>'NaN'::numeric);
    raise exception 'Nonfinite price was accepted';
  exception when invalid_parameter_value then null; end;
  if (select prosecdef from pg_proc where oid='public.marketplace_search(text,text,text,text,numeric,numeric,timestamptz,timestamptz,integer,integer,text)'::regprocedure) then
    raise exception 'Catalog must run as invoker';
  end if;
end $$;

set local role anon;
do $$ begin
  if not exists(select 1 from public.marketplace_search(p_city=>'Marketplace QA City',p_category=>'events')) then
    raise exception 'Published catalog is not readable by anonymous customers';
  end if;
end $$;
reset role;

update public.feature_flags set platforms=array['android','ios'] where key='events';
do $$ begin
  if exists(select 1 from public.marketplace_search(p_city=>'Marketplace QA City',p_category=>'events',p_platform=>'web')) then
    raise exception 'Disabled web module leaked into catalog';
  end if;
  if not exists(select 1 from public.marketplace_search(p_city=>'Marketplace QA City',p_category=>'events',p_platform=>'android')) then
    raise exception 'Enabled Android module was hidden';
  end if;
end $$;

-- Restrictive policies test source RLS independently of existing permissive
-- public/owner policies. A security-definer RPC would incorrectly bypass them.
create policy marketplace_test_hide_venue on public.venues as restrictive for select to anon, authenticated using (id <> 'ae000000-0000-4000-8000-000000000003');
create policy marketplace_test_hide_event on public.events as restrictive for select to anon, authenticated using (id <> 'ae000000-0000-4000-8000-000000000005');
create policy marketplace_test_hide_course on public.courses as restrictive for select to anon, authenticated using (id <> 'ae000000-0000-4000-8000-000000000008');
set local role anon;
do $$ begin
  if exists(select 1 from public.marketplace_search(p_city=>'Marketplace QA City')) then
    raise exception 'Anonymous catalog bypassed source RLS';
  end if;
end $$;
reset role;
set local role authenticated;
do $$ begin
  if exists(select 1 from public.marketplace_search(p_city=>'Marketplace QA City')) then
    raise exception 'Authenticated catalog bypassed source RLS';
  end if;
end $$;
reset role;
rollback;
