-- CMS banners and feature flags. Additive; does not replace venue categories.
-- Public can read currently-active rows. Only administrators may write.

create table if not exists public.cms_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  image_url text,
  cta_text text,
  cta_route text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cms_banners_active_sort_idx
  on public.cms_banners (is_active, sort_order);

create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default true,
  platforms text[] not null default array['ios','android','web']::text[],
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.cms_banners enable row level security;
alter table public.feature_flags enable row level security;

drop policy if exists cms_banners_public_read on public.cms_banners;
create policy cms_banners_public_read
  on public.cms_banners
  for select
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

drop policy if exists cms_banners_admin_all on public.cms_banners;
create policy cms_banners_admin_all
  on public.cms_banners
  for all
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

drop policy if exists feature_flags_public_read on public.feature_flags;
create policy feature_flags_public_read
  on public.feature_flags
  for select
  using (true);

drop policy if exists feature_flags_admin_write on public.feature_flags;
create policy feature_flags_admin_write
  on public.feature_flags
  for all
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

grant select on public.cms_banners to anon, authenticated;
grant select, insert, update, delete on public.cms_banners to authenticated;
grant select on public.feature_flags to anon, authenticated;
grant select, insert, update, delete on public.feature_flags to authenticated;

insert into public.feature_flags (key, enabled)
values
  ('gps', true),
  ('pin_search', true),
  ('offers', true),
  ('courses', true),
  ('events', true),
  ('reviews', true),
  ('favorites', true),
  ('payments', true),
  ('notifications', true),
  ('support', true)
on conflict (key) do nothing;
