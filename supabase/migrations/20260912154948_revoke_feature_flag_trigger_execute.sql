-- Trigger functions are invoked by PostgreSQL as part of feature_flags
-- writes; they are not public RPC endpoints. Keep their SECURITY DEFINER
-- implementation, but remove inherited API execute privileges.
--
-- Guarded 2026-09-14. These two functions are not created until
-- 20260912203000_owner_approval_and_plug_play_modules.sql, which sorts AFTER
-- this file. On the deployed project the revoke landed against a definition
-- that already existed out of band, but on a clean `supabase db reset` this
-- migration aborted with "function public.validate_feature_flag_config() does
-- not exist", taking every later migration with it.
--
-- Editing this file rather than adding a new one is deliberate: a follow-up
-- migration cannot help a fresh reset, because this file still runs first and
-- still aborts. Deployed environments have already recorded this version as
-- applied and will not replay it, so the guard is inert there. The revoke is
-- re-asserted in 20260914155335 after the functions are defined, so the
-- privilege outcome is identical whichever order a database sees.
do $$
begin
  if to_regprocedure('public.validate_feature_flag_config()') is not null then
    revoke all on function public.validate_feature_flag_config() from public, anon, authenticated;
  end if;
  if to_regprocedure('public.audit_feature_flag_change()') is not null then
    revoke all on function public.audit_feature_flag_change() from public, anon, authenticated;
  end if;
end $$;
