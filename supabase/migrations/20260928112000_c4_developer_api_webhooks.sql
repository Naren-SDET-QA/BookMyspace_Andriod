-- Phase C4: developer API key registry and signed outbound webhook delivery.
-- Secrets are never stored in the client or in plaintext database columns.

create table if not exists public.developer_api_keys (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  key_prefix text not null,
  key_digest text not null unique,
  scopes text[] not null default array['bookings:read']::text[],
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  check (cardinality(scopes) > 0),
  check (length(trim(name)) between 1 and 120)
);

create table if not exists public.outbound_webhook_endpoints (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  endpoint_url text not null,
  secret_reference text not null,
  event_types text[] not null default array['booking.created']::text[],
  enabled boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_success_at timestamptz,
  check (endpoint_url ~ '^https://'),
  check (length(trim(secret_reference)) between 1 and 120)
);

create table if not exists public.outbound_webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  endpoint_id uuid not null references public.outbound_webhook_endpoints(id) on delete cascade,
  event_type text not null,
  event_key text not null,
  payload jsonb not null,
  status text not null default 'QUEUED'
    check (status in ('QUEUED', 'SENDING', 'DELIVERED', 'FAILED')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  response_status integer,
  error_code text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  unique (endpoint_id, event_key)
);

create index if not exists outbound_webhook_queue_idx
  on public.outbound_webhook_deliveries(status, next_attempt_at);
create index if not exists developer_api_keys_active_idx
  on public.developer_api_keys(created_by) where revoked_at is null;

alter table public.developer_api_keys enable row level security;
alter table public.outbound_webhook_endpoints enable row level security;
alter table public.outbound_webhook_deliveries enable row level security;

do $$
declare t text;
begin
  foreach t in array array['developer_api_keys','outbound_webhook_endpoints','outbound_webhook_deliveries'] loop
    execute format('drop policy if exists %I on public.%I', t || '_admin_read', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.has_role(auth.uid(), ''administrator'') or public.has_role(auth.uid(), ''super_administrator''))',
      t || '_admin_read', t
    );
  end loop;
end $$;

drop policy if exists outbound_webhook_endpoints_admin_write on public.outbound_webhook_endpoints;
create policy outbound_webhook_endpoints_admin_write on public.outbound_webhook_endpoints
  for all to authenticated
  using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
  with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

revoke all on public.developer_api_keys, public.outbound_webhook_endpoints,
  public.outbound_webhook_deliveries from public, anon, authenticated;
grant select on public.developer_api_keys, public.outbound_webhook_endpoints,
  public.outbound_webhook_deliveries to authenticated;

create or replace function public.admin_create_developer_api_key(
  p_name text,
  p_scopes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_secret text := 'bms_' || encode(gen_random_bytes(32), 'hex');
  v_row public.developer_api_keys;
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  insert into public.developer_api_keys(name, key_prefix, key_digest, scopes, created_by)
  values (
    trim(p_name), left(v_secret, 12), encode(digest(v_secret, 'sha256'), 'hex'),
    coalesce(nullif(p_scopes, '{}'), array['bookings:read']::text[]), auth.uid()
  ) returning * into v_row;
  return jsonb_build_object(
    'id', v_row.id, 'name', v_row.name, 'key_prefix', v_row.key_prefix,
    'scopes', v_row.scopes, 'secret', v_secret
  );
end;
$function$;

create or replace function public.admin_revoke_developer_api_key(p_key_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $function$
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  update public.developer_api_keys set revoked_at = coalesce(revoked_at, now()) where id = p_key_id;
end;
$function$;

create or replace function public.resolve_developer_api_key(p_secret text)
returns table (id uuid, created_by uuid, scopes text[])
language plpgsql
security definer
set search_path = public
as $function$
begin
  if p_secret is null or length(p_secret) < 20 then return; end if;
  return query
  update public.developer_api_keys k
  set last_used_at = now()
  where k.key_digest = encode(digest(p_secret, 'sha256'), 'hex')
    and k.revoked_at is null
  returning k.id, k.created_by, k.scopes;
end;
$function$;

create or replace function public.admin_save_webhook_endpoint(
  p_id uuid,
  p_name text,
  p_endpoint_url text,
  p_secret_reference text,
  p_event_types text[],
  p_enabled boolean
)
returns public.outbound_webhook_endpoints
language plpgsql
security definer
set search_path = public
as $function$
declare v_row public.outbound_webhook_endpoints;
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  if p_endpoint_url is null or p_endpoint_url !~ '^https://' then
    raise exception 'https_endpoint_required';
  end if;
  if p_id is null then
    insert into public.outbound_webhook_endpoints(
      name, endpoint_url, secret_reference, event_types, enabled, created_by
    ) values (
      trim(p_name), trim(p_endpoint_url), trim(p_secret_reference),
      coalesce(nullif(p_event_types, '{}'), array['booking.created']::text[]),
      coalesce(p_enabled, false), auth.uid()
    ) returning * into v_row;
  else
    update public.outbound_webhook_endpoints set
      name = trim(p_name), endpoint_url = trim(p_endpoint_url),
      secret_reference = trim(p_secret_reference),
      event_types = coalesce(nullif(p_event_types, '{}'), array['booking.created']::text[]),
      enabled = coalesce(p_enabled, false), updated_at = now()
    where id = p_id returning * into v_row;
  end if;
  if v_row.id is null then raise exception 'webhook_endpoint_not_found'; end if;
  return v_row;
end;
$function$;

create or replace function public.enqueue_outbound_webhook(
  p_event_type text,
  p_event_key text,
  p_payload jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare v_count integer;
begin
  insert into public.outbound_webhook_deliveries(endpoint_id, event_type, event_key, payload)
  select id, p_event_type, p_event_key, coalesce(p_payload, '{}'::jsonb)
  from public.outbound_webhook_endpoints
  where enabled and p_event_type = any(event_types)
  on conflict (endpoint_id, event_key) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

create or replace function public.enqueue_booking_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare v_event text; v_key text;
begin
  if tg_op = 'INSERT' then
    v_event := 'booking.created';
    v_key := v_event || ':' || new.id::text;
  elsif new.status is distinct from old.status then
    v_event := case new.status::text
      when 'confirmed' then 'booking.confirmed'
      when 'cancelled' then 'booking.cancelled'
      else null end;
    if v_event is null then return new; end if;
    v_key := v_event || ':' || new.id::text;
  else
    return new;
  end if;
  perform public.enqueue_outbound_webhook(v_event, v_key, jsonb_build_object(
    'booking_id', new.id, 'venue_id', new.venue_id, 'customer_id', new.user_id,
    'status', new.status, 'created_at', new.created_at
  ));
  return new;
end;
$function$;

drop trigger if exists trg_booking_outbound_webhook on public.bookings;
create trigger trg_booking_outbound_webhook
  after insert or update of status on public.bookings
  for each row execute function public.enqueue_booking_webhook();

create or replace function public.claim_outbound_webhook_batch(p_limit integer default 20)
returns setof public.outbound_webhook_deliveries
language plpgsql
security definer
set search_path = public
as $function$
begin
  if coalesce(auth.role(), '') <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'service_role_required';
  end if;
  return query
  update public.outbound_webhook_deliveries d
  set status = 'SENDING', attempt_count = attempt_count + 1
  where d.id in (
    select id from public.outbound_webhook_deliveries
    where status = 'QUEUED' and next_attempt_at <= now()
    order by created_at
    for update skip locked limit greatest(1, least(coalesce(p_limit, 20), 100))
  ) returning d.*;
end;
$function$;

create or replace function public.record_outbound_webhook_result(
  p_delivery_id uuid,
  p_success boolean,
  p_response_status integer default null,
  p_error_code text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $function$
begin
  if coalesce(auth.role(), '') <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'service_role_required';
  end if;
  update public.outbound_webhook_deliveries
  set status = case
        when p_success then 'DELIVERED'
        when attempt_count >= 5 then 'FAILED'
        else 'QUEUED'
      end,
      response_status = p_response_status,
      error_code = left(p_error_code, 200),
      next_attempt_at = case
        when p_success or attempt_count >= 5 then now()
        else now() + interval '5 minutes'
      end,
      delivered_at = case when p_success then now() else null end
  where id = p_delivery_id;
  if p_success then
    update public.outbound_webhook_endpoints e
    set last_success_at = now()
    where e.id = (select endpoint_id from public.outbound_webhook_deliveries where id = p_delivery_id);
  end if;
end;
$function$;

revoke all on function public.admin_create_developer_api_key(text, text[]) from public, anon;
revoke all on function public.admin_revoke_developer_api_key(uuid) from public, anon;
revoke all on function public.resolve_developer_api_key(text) from public, anon, authenticated;
revoke all on function public.admin_save_webhook_endpoint(uuid, text, text, text, text[], boolean) from public, anon;
revoke all on function public.enqueue_outbound_webhook(text, text, jsonb) from public, anon, authenticated;
revoke all on function public.claim_outbound_webhook_batch(integer) from public, anon, authenticated;
revoke all on function public.record_outbound_webhook_result(uuid, boolean, integer, text) from public, anon, authenticated;
grant execute on function public.admin_create_developer_api_key(text, text[]) to authenticated;
grant execute on function public.admin_revoke_developer_api_key(uuid) to authenticated;
grant execute on function public.admin_save_webhook_endpoint(uuid, text, text, text, text[], boolean) to authenticated;
grant execute on function public.resolve_developer_api_key(text) to service_role;
grant execute on function public.enqueue_outbound_webhook(text, text, jsonb) to service_role;
grant execute on function public.claim_outbound_webhook_batch(integer) to service_role;
grant execute on function public.record_outbound_webhook_result(uuid, boolean, integer, text) to service_role;
