-- Fix: the global venue-category taxonomy (public.venue_categories /
-- public.venue_subsections) must be managed by platform Admins only.
--
-- Live defect found: private.is_category_manager() currently returns true
-- for (a) ANY row in public.owner_profiles, (b) anyone holding the
-- 'venue_owner' role, in addition to administrator/super_administrator.
-- Every RLS policy on venue_categories/venue_subsections, both reorder RPCs
-- (reorder_category_catalog, reorder_category_subsections), and the
-- category-media storage bucket policies all gate through this one
-- function. As deployed, ANY venue owner on the platform can create,
-- rename, hide, delete, reorder, or replace the image of ANY category or
-- subsection used by every other owner's venues and by customer discovery
-- surfaces platform-wide. This is exactly the "Owner edits global category
-- definitions" failure mode the product spec explicitly forbids.
--
-- Fix: narrow the function to administrator / super_administrator only.
-- Nothing else changes -- every policy, RPC, and storage rule that already
-- calls public.is_category_manager()/private.is_category_manager() is
-- corrected by this one function redefinition. The Admin console (which
-- already only grants this UI to administrator/super_administrator via its
-- own route guard) is unaffected.

create or replace function private.is_category_manager()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.has_role((select auth.uid()), 'administrator'::public.user_role)
    or public.has_role((select auth.uid()), 'super_administrator'::public.user_role);
$$;

comment on function private.is_category_manager() is
  'Administrator/super_administrator only. Global category/subsection taxonomy is platform configuration, never an owner-editable resource. Fixed 2026-09-13: previously also matched any owner_profiles row or the venue_owner role, letting any venue owner mutate platform-wide categories.';
