-- Payment webhook hardening assertions.
-- Run against the target database after applying the matching migration.

do $$
declare
  confirmation_args text;
  register_args text;
  unique_event_key boolean;
begin
  select pg_get_function_arguments(p.oid)
    into confirmation_args
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'confirm_venue_booking';

  if confirmation_args <> 'p_booking_id uuid, p_user_id uuid, p_payment_ref text, p_payment_method text DEFAULT ''UPIRazorpay''::text' then
    raise exception 'FAIL: unexpected confirm_venue_booking signature: %', confirmation_args;
  end if;

  select pg_get_function_arguments(p.oid)
    into register_args
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'register_webhook_event';

  if register_args <> 'p_provider text, p_event_id text, p_event_type text, p_payload jsonb' then
    raise exception 'FAIL: unexpected register_webhook_event signature: %', register_args;
  end if;

  select exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'webhook_events'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) = 'UNIQUE (provider, event_id)'
  ) into unique_event_key;

  if not unique_event_key then
    raise exception 'FAIL: webhook event idempotency constraint is missing';
  end if;

  raise notice 'PASS: payment webhook hardening schema assertions';
end $$;
