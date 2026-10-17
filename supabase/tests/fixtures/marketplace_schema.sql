-- Only for an EMPTY disposable PostgreSQL database. This is a narrow schema
-- harness, not a replacement for running the full Supabase migration chain.
do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end $$;
create schema auth;
create table auth.users(id uuid primary key, email text);
create table public.organizations(id uuid primary key,owner_user_id uuid,org_type text,name text);
create table public.venue_categories(id uuid primary key,slug text,is_active boolean default true,deleted_at timestamptz,metadata jsonb default '{}');
create table public.venues(
  id uuid primary key,org_id uuid,name text,description text,city text,
  latitude double precision,longitude double precision,pricing_base_amount numeric,
  pricing_currency text default 'INR',avg_rating numeric default 0,is_active boolean default true,
  is_verified boolean default false,deleted_at timestamptz,category_id uuid,
  listing_status text default 'published'
);
create table public.venue_images(id uuid primary key,venue_id uuid,url text,is_cover boolean,sort_order integer,is_active boolean default true,media_kind text default 'image');
create table public.events(id uuid primary key,org_id uuid,venue_id uuid,category text,title text,description text,starts_at timestamptz,ends_at timestamptz,capacity integer,ticket_price numeric,is_free boolean,status text);
create table public.institutes(id uuid primary key,org_id uuid,name text,city text);
create table public.courses(id uuid primary key,institute_id uuid,title text,description text,mode text,duration_weeks integer,fee_amount numeric,status text,cover_image text);
alter table public.events add column cover_image text;
create table public.course_batches(id uuid default gen_random_uuid(),course_id uuid,label text,starts_on date,capacity integer,is_active boolean default true);
create table public.feature_flags(key text primary key,enabled boolean,platforms text[]);
alter table public.venues enable row level security;
alter table public.events enable row level security;
alter table public.courses enable row level security;
alter table public.institutes enable row level security;
alter table public.venue_categories enable row level security;
alter table public.venue_images enable row level security;
alter table public.course_batches enable row level security;
alter table public.feature_flags enable row level security;
create policy fixture_read on public.venues for select using(is_active);
create policy fixture_read on public.events for select using(status='published');
create policy fixture_read on public.courses for select using(status='published');
create policy fixture_read on public.institutes for select using(true);
create policy fixture_read on public.venue_categories for select using(true);
create policy fixture_read on public.venue_images for select using(false);
create policy fixture_read on public.course_batches for select using(true);
create policy fixture_read on public.feature_flags for select using(true);
-- Reproduce the legacy public ALL policy that broke anonymous source reads.
create function public.can_edit_venue(uuid,uuid) returns boolean language plpgsql as $$ begin return false; end $$;
revoke all on function public.can_edit_venue(uuid,uuid) from public;
grant execute on function public.can_edit_venue(uuid,uuid) to authenticated;
create policy venue_images_owner_write on public.venue_images for all
  using(public.can_edit_venue(venue_id,null)) with check(public.can_edit_venue(venue_id,null));
grant usage on schema public to anon,authenticated;
-- The migration supplies only required column grants. Do not grant SELECT
-- on every source table: that would hide missing invoker permissions.
