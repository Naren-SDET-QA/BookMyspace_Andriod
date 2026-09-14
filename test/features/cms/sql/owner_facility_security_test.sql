-- Isolated PostgreSQL contract harness. Never run against an application DB.
-- Real venue-section migration, with minimal auth/venue dependency fixtures.
\set ON_ERROR_STOP on
do $$ begin
  if current_database() <> 'phase3_owner_facility_test' then
    raise exception 'Run only in phase3_owner_facility_test';
  end if;
end $$;
begin;
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
create table public.organizations(id uuid primary key, owner_user_id uuid, deleted_at timestamptz);
create table public.venues(id uuid primary key, org_id uuid, deleted_at timestamptz, is_active boolean default true);
create table public.audit_logs(actor_id uuid, action text, entity_type text, entity_id uuid, details jsonb);
create function public.set_updated_at() returns trigger language plpgsql as
$$ begin new.updated_at = now(); return new; end $$;
-- Same ownership predicate as the existing application helper.
create function public.owns_venue(uid uuid, p_venue_id uuid) returns boolean language sql stable as $$
 select exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
 where v.id=p_venue_id and o.owner_user_id=uid and o.deleted_at is null and v.deleted_at is null)
$$;
create function public.is_platform_admin(uid uuid) returns boolean language sql stable as $$
 select uid = '00000000-0000-0000-0000-000000000003'::uuid
$$;
grant select on public.venues, public.organizations to authenticated;
-- The publish functions write an audit row as their definer. Read access is
-- granted here so the harness can assert that the row exists.
grant select on public.audit_logs to authenticated;
-- Minimal stand-ins for the Supabase Storage objects the migrations touch.
-- These are fixtures only: the contract under test is venue-section
-- authorization, not Storage behaviour, and the real project ships a
-- provisioned storage schema and is_category_manager helper.
create schema storage;
create table storage.objects(
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null
);
create function storage.foldername(name text) returns text[] language sql immutable as
$$ select string_to_array(name, '/') $$;
create function public.is_category_manager() returns boolean language sql stable as
$$ select true $$;
\ir ../../../../supabase/migrations/20260913061000_owner_venue_sections.sql
\ir ../../../../supabase/migrations/20260914162854_owner_facility_builder.sql
-- Replay is idempotent.
\ir ../../../../supabase/migrations/20260914162854_owner_facility_builder.sql
insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002'), ('00000000-0000-0000-0000-000000000003');
insert into organizations values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',null), ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002',null);
insert into venues(id,org_id) values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'), ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
insert into venue_sections(id,venue_id,section_type_id,title,content,config,published_config)
select '30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',id,'Facilities','Draft one','{"facility_types":[{"key":"mine","title":{"base":"Mine"}}]}','{"forged":true}'
from venue_section_types where key='owner_facilities';
do $$ begin
 if (select published_config is not null from venue_sections limit 1) then raise exception 'Forged publish accepted'; end if;
 if exists(select 1 from list_published_venue_sections('20000000-0000-0000-0000-000000000001')) then raise exception 'Draft leaked'; end if;
 begin
   insert into venue_sections(venue_id,section_type_id) select '20000000-0000-0000-0000-000000000002',id from venue_section_types where key='owner_facilities';
   raise exception 'Foreign venue accepted';
 exception when insufficient_privilege then null; end;
 begin
   insert into venue_sections(venue_id,section_type_id) select '20000000-0000-0000-0000-000000000001',id from venue_section_types where key='owner_facilities';
   raise exception 'Duplicate container accepted';
 exception when unique_violation then null; end;
 if (publish_venue_sections('20000000-0000-0000-0000-000000000001')->>'success') <> 'true' then raise exception 'Owner publish failed'; end if;
end $$;
-- Section-scoped publish: the only publish path the owner facility builder
-- uses. It must accept the owner, apply the named section, be audited, and
-- refuse an unknown section id or a section owned by another venue.
do $$ begin
 if (publish_venue_section('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001')->>'success') <> 'true' then raise exception 'Owner section publish failed'; end if;
 if (select content from list_published_venue_sections('20000000-0000-0000-0000-000000000001')) <> 'Draft one' then raise exception 'Section publish content wrong'; end if;
 if not exists(select 1 from audit_logs where entity_id='30000000-0000-0000-0000-000000000001' and action='venue_section_published') then raise exception 'Section publish not audited'; end if;
 begin
   if (publish_venue_section('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000ff')->>'success') <> 'false' then raise exception 'Unknown section published'; end if;
 end;
 begin
   if (publish_venue_section('20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001')->>'success') <> 'false' then raise exception 'Cross-venue section published'; end if;
 end;
end $$;
update venue_sections set content='Draft two' where id='30000000-0000-0000-0000-000000000001';
do $$ begin
 if (select content from list_published_venue_sections('20000000-0000-0000-0000-000000000001')) <> 'Draft one' then raise exception 'Unsaved publish leaked'; end if;
 begin
   update venue_sections set published_config='{}';
   raise exception 'Direct snapshot update accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $$ begin
 if exists(select 1 from venue_sections) then raise exception 'Other owner can read draft'; end if;
 update venue_sections set content='Attacker';
 if found then raise exception 'Other owner updated draft'; end if;
 if (publish_venue_sections('20000000-0000-0000-0000-000000000001')->>'success') <> 'false' then raise exception 'Other owner published'; end if;
 if (publish_venue_section('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001')->>'success') <> 'false' then raise exception 'Other owner section published'; end if;
end $$;
set local role anon;
do $$ begin
 begin
   perform * from venue_sections;
   raise exception 'Anonymous draft read accepted';
 exception when insufficient_privilege then null; end;
 begin
   perform publish_venue_sections('20000000-0000-0000-0000-000000000001');
   raise exception 'Anonymous publish accepted';
 exception when insufficient_privilege then null; end;
 begin
   perform publish_venue_section('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001');
   raise exception 'Anonymous section publish accepted';
 exception when insufficient_privilege then null; end;
 if (select content from list_published_venue_sections('20000000-0000-0000-0000-000000000001')) <> 'Draft one' then raise exception 'Published read failed'; end if;
end $$;
reset role;
rollback;
\echo 'PASS: owner scope, forged IDs, anonymous denial, section-scoped publish authorization and audit, snapshot isolation, unique retry container, migration replay'
