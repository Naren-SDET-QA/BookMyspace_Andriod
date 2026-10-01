-- =============================================================================
-- Schedule the reconcile-refunds Edge Function via pg_cron + pg_net.
--
-- reconcile-refunds already exists and is deployed (see
-- supabase/functions/reconcile-refunds/index.ts). Its own header states it
-- was "not wired to a schedule by this change" -- this migration is that
-- missing wiring, and nothing else. It performs read-only Razorpay lookups
-- and idempotent apply_refund_result() calls; it does not retry the refund
-- POST itself, so invoking it on an interval is safe to repeat.
--
-- Prerequisites (already provisioned, verified live before this migration):
--   - extension pg_net
--   - vault secret 'reconcile_refunds_url' = the function's HTTPS URL
--   - vault secret 'service_role_key'      = the project's service-role key
--     (reconcile-refunds requires the caller's Authorization header to
--     contain the service-role key -- see its own auth check).
--
-- Both secrets are read from Vault at cron execution time via
-- vault.decrypted_secrets. Neither value is embedded as a literal anywhere
-- in this migration, in cron.job, or in any log this migration produces.
-- =============================================================================

create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'reconcile-refunds-sweep',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'reconcile_refunds_url'
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'service_role_key'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
