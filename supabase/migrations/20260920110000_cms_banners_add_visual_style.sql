-- Adds optional per-banner visual-style overrides so a slot-targeted
-- category banner can also override the category's icon/accent/gradient/
-- badge colors, not just its image. All nullable/additive: existing rows
-- (and the generic, non-slotted offer carousel) are completely unaffected
-- and keep using the app's hardcoded MainHomeSection defaults.
--
-- Rollback:
--   alter table public.cms_banners
--     drop column if exists icon_name,
--     drop column if exists accent_color,
--     drop column if exists gradient_start_color,
--     drop column if exists gradient_end_color,
--     drop column if exists badge_color;

alter table public.cms_banners
  add column if not exists icon_name text,
  add column if not exists accent_color text,
  add column if not exists gradient_start_color text,
  add column if not exists gradient_end_color text,
  add column if not exists badge_color text;
