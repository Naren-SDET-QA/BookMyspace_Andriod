-- B17: save courses and institutes (venues keep using public.favorites).
create table if not exists public.saved_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('course', 'institute')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, item_type, item_id)
);

create index if not exists idx_saved_items_user
  on public.saved_items (user_id, item_type, created_at desc);

alter table public.saved_items enable row level security;

drop policy if exists saved_items_own on public.saved_items;
create policy saved_items_own on public.saved_items
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.saved_items from anon;
grant select, insert, delete on public.saved_items to authenticated;
