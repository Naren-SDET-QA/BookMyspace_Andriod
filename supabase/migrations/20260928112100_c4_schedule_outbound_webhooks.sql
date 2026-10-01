-- Phase C4: invoke the outbound webhook dispatcher from Supabase's scheduler.
--
-- The URL and service-role key are read from Vault at execution time. They
-- must be provisioned as `dispatch_outbound_webhooks_url` and
-- `service_role_key`; no credential is embedded in this migration.

do $$
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_net'
  ) and not exists (
    select 1 from pg_extension where extname = 'pg_net'
  ) then
    create extension pg_net with schema extensions;
  end if;

  if exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) and not exists (
    select 1 from pg_extension where extname = 'pg_cron'
  ) then
    create extension pg_cron;
  end if;

  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net')
     and not exists (
       select 1 from cron.job where jobname = 'dispatch-outbound-webhooks'
     ) then
    perform cron.schedule(
      'dispatch-outbound-webhooks',
      '* * * * *',
      $job$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'dispatch_outbound_webhooks_url'
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
      $job$
    );
  end if;
end $$;
