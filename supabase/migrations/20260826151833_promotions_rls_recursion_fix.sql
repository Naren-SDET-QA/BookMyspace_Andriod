-- Reconstructed from the deployed bookmyspace-dev migration ledger
-- (supabase_migrations.schema_migrations, version 20260826151833) on
-- 2026-09-12 because no local file previously existed for this version.
-- This is a verbatim copy of the statements Supabase recorded as applied;
-- it is not being re-run against the database, only checked in so the
-- repo's migration history matches deployed reality.
create or replace function public.promotion_has_category_target(p_promotion_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.promotion_categories pc
    join public.venue_categories c on c.id = pc.category_id
    where pc.promotion_id = p_promotion_id
      and c.metadata->>'active' = 'true'
      and c.metadata->>'offers_enabled' = 'true'
  );
$$;

create or replace function public.promotion_has_venue_target(p_promotion_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_catalog
as $$
  select exists (
    select 1 from public.promotion_venues pv
    join public.venues v on v.id = pv.venue_id
    join public.venue_categories c on c.id = v.category_id
    where pv.promotion_id = p_promotion_id
      and v.is_active
      and c.metadata->>'active' = 'true'
      and c.metadata->>'offers_enabled' = 'true'
  );
$$;

revoke all on function public.promotion_has_category_target(uuid) from public;
revoke all on function public.promotion_has_venue_target(uuid) from public;

drop policy if exists promotions_public_read on public.promotions;
create policy promotions_public_read on public.promotions
for select using (
  coalesce((select metadata->>'promotions_enabled' = 'true'
    from public.module_feature_configs
    where module_key = 'promotions' and venue_id is null), false)
  and active
  and (start_at is null or start_at <= now())
  and (end_at is null or end_at > now())
  and (
    (not public.promotion_has_category_target(promotions.id)
     and not public.promotion_has_venue_target(promotions.id))
    or public.promotion_has_category_target(promotions.id)
    or public.promotion_has_venue_target(promotions.id)
  )
);
