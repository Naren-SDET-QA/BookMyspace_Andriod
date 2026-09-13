-- Trigger functions are invoked by PostgreSQL as part of feature_flags
-- writes; they are not public RPC endpoints. Keep their SECURITY DEFINER
-- implementation, but remove inherited API execute privileges.
revoke all on function public.validate_feature_flag_config() from public, anon, authenticated;
revoke all on function public.audit_feature_flag_change() from public, anon, authenticated;
