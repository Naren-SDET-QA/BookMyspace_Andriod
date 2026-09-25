-- The deployed venue_sections architecture is the authoritative owner
-- configuration path. Remove the temporary module_feature_configs guard that
-- was applied while that architecture was being verified.
drop trigger if exists owner_venue_module_config_guard
on public.module_feature_configs;

drop function if exists public.validate_owner_venue_module_config();
