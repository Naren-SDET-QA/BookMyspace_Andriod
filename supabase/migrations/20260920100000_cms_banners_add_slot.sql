-- Adds a nullable `slot` key to cms_banners so a banner row can target a
-- specific home surface (e.g. 'category_function_halls') instead of only
-- the generic offer-banner carousel. Additive and backward-compatible:
-- existing rows keep slot = null and keep showing in the generic carousel.
--
-- Rollback:
--   drop index if exists public.cms_banners_slot_active_idx;
--   alter table public.cms_banners drop column if exists slot;

alter table public.cms_banners
  add column if not exists slot text;

create index if not exists cms_banners_slot_active_idx
  on public.cms_banners(slot, is_active);
