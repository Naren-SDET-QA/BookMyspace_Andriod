-- ============================================================
-- BookMySpace — External Channel / PMS Inventory Synchronization
--
-- Adds a provider-neutral schema + RPCs for external channel managers
-- (Booking.com / MakeMyTrip / Agoda / hotel PMS / phone-walkin) so that
-- BookMySpace never oversells inventory the hotel also sells elsewhere.
--
-- Reuses existing primitives instead of duplicating them:
--   - public.venues / public.time_slots / public.venue_blocked_dates
--     remain the local inventory model (room-type/slot granularity).
--   - public.booking_holds / public.bookings / acquire_venue_hold /
--     confirm_venue_booking remain the booking state machine — this
--     migration only teaches acquire_venue_hold about an additional
--     "externally reserved" block source.
--   - public.audit_logs (0006/0015) is reused for security-relevant
--     events; inventory_change_log below is the domain-specific,
--     append-only reconciliation trail requested by the task spec.
--   - public.is_platform_admin(uuid) (20260912140000) is reused for
--     admin authorization; public.owns_venue(uid, venue_id) (from
--     20260912140000_gap_closure_analytics_support_storage.sql) is reused
--     for owner scoping through organizations.owner_user_id.
-- ============================================================

-- ------------------------------------------------------------
-- 1. PROVIDERS (catalog of supported channel managers)
-- ------------------------------------------------------------
create table public.external_channel_providers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique, -- e.g. 'booking_com', 'makemytrip', 'agoda', 'generic_pms'
  name text not null,
  auth_model text not null default 'api_key', -- api_key | oauth2 | partner_agreement
  capabilities jsonb not null default '{}'::jsonb, -- {pull_availability, webhooks, push_inventory, create_reservation, cancel_reservation}
  requires_partner_agreement boolean not null default true,
  status text not null default 'blocked_external'
    check (status in ('available', 'blocked_external', 'deprecated')),
  docs_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.external_channel_providers is
  'Catalog of channel-manager/OTA providers BookMySpace can integrate with. status=blocked_external means no live credentials/partner account exist in this environment; the adapter/interface still exists.';

-- ------------------------------------------------------------
-- 2. CONNECTIONS (owner <-> provider <-> venue, credentials server-side only)
-- ------------------------------------------------------------
create table public.external_channel_connections (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  provider_id uuid not null references public.external_channel_providers(id),
  owner_user_id uuid not null references auth.users(id),
  credential_ref text,
  status text not null default 'pending_setup'
    check (status in (
      'pending_setup', 'connecting', 'connected', 'degraded',
      'disconnected', 'error', 'blocked_external'
    )),
  config jsonb not null default '{}'::jsonb,
  health text not null default 'not_configured'
    check (health in ('healthy', 'degraded', 'unavailable', 'not_configured')),
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, provider_id)
);

create index idx_ext_connections_owner on public.external_channel_connections(owner_user_id);
create index idx_ext_connections_venue on public.external_channel_connections(venue_id);

comment on column public.external_channel_connections.credential_ref is
  'Opaque reference to a server-side secret store entry. Never the raw API key/secret.';

-- ------------------------------------------------------------
-- 3. MAPPINGS (property / room-type / rate-plan)
-- ------------------------------------------------------------
create table public.external_property_mappings (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.external_channel_connections(id) on delete cascade,
  external_property_id text not null,
  local_venue_id uuid not null references public.venues(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_synced_at timestamptz,
  unique (connection_id, external_property_id)
);

create table public.external_room_mappings (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.external_channel_connections(id) on delete cascade,
  external_room_id text not null,
  external_room_name text,
  local_slot_id uuid references public.time_slots(id) on delete set null,
  total_inventory integer not null default 1,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_synced_at timestamptz,
  unique (connection_id, external_room_id)
);

create table public.external_rate_plan_mappings (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.external_channel_connections(id) on delete cascade,
  external_rate_plan_id text not null,
  local_slot_id uuid references public.time_slots(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (connection_id, external_rate_plan_id)
);

-- ------------------------------------------------------------
-- 4. EXTERNAL RESERVATIONS (source-of-truth blocks from the channel)
-- ------------------------------------------------------------
create table public.external_reservations (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.external_channel_connections(id) on delete cascade,
  provider_id uuid not null references public.external_channel_providers(id),
  external_reservation_id text not null,
  local_booking_id uuid references public.bookings(id) on delete set null,
  venue_id uuid not null references public.venues(id) on delete cascade,
  slot_id uuid references public.time_slots(id) on delete set null,
  book_date date not null,
  status text not null default 'booked'
    check (status in ('booked', 'modified', 'cancelled')),
  provider_version bigint,
  provider_updated_at timestamptz,
  guest_ref text,
  raw_event_ref uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_synced_at timestamptz not null default now(),
  unique (connection_id, external_reservation_id)
);

create index idx_ext_reservations_venue_date on public.external_reservations(venue_id, book_date)
  where status <> 'cancelled';
create index idx_ext_reservations_slot on public.external_reservations(slot_id, book_date)
  where status <> 'cancelled';

comment on table public.external_reservations is
  'Authoritative record of inventory the hotel sold through an external channel. Blocks BookMySpace availability while status <> cancelled.';

-- ------------------------------------------------------------
-- 5. INVENTORY EVENTS (raw/normalized webhook events — idempotency ledger)
-- ------------------------------------------------------------
create table public.external_inventory_events (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid references public.external_channel_connections(id) on delete cascade,
  provider_id uuid not null references public.external_channel_providers(id),
  external_event_id text not null,
  event_type text not null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received'
    check (processing_status in ('received', 'processed', 'failed', 'duplicate', 'out_of_order_buffered')),
  error text,
  unique (provider_id, connection_id, external_event_id)
);

create index idx_ext_events_connection on public.external_inventory_events(connection_id, received_at desc);

-- ------------------------------------------------------------
-- 6. SYNC STATE / ERRORS
-- ------------------------------------------------------------
create table public.inventory_sync_state (
  connection_id uuid primary key references public.external_channel_connections(id) on delete cascade,
  sync_status text not null default 'idle'
    check (sync_status in ('idle', 'syncing', 'success', 'error', 'blocked_external')),
  last_sync_attempt_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures integer not null default 0,
  mismatch_count integer not null default 0,
  next_retry_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.inventory_sync_errors (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.external_channel_connections(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  error_code text not null,
  error_message text not null,
  context jsonb not null default '{}'::jsonb,
  resolved boolean not null default false,
  resolved_at timestamptz
);

create index idx_sync_errors_connection on public.inventory_sync_errors(connection_id, resolved, occurred_at desc);

-- ------------------------------------------------------------
-- 7. IMMUTABLE CHANGE LOG (reconciliation / audit trail)
-- ------------------------------------------------------------
create table public.inventory_change_log (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  slot_id uuid references public.time_slots(id) on delete set null,
  book_date date,
  connection_id uuid references public.external_channel_connections(id) on delete set null,
  source text not null check (source in ('bms', 'external', 'reconciliation', 'admin')),
  change_type text not null,
  previous_state jsonb,
  new_state jsonb,
  actor text,
  created_at timestamptz not null default now()
);

create index idx_inventory_change_log_venue on public.inventory_change_log(venue_id, book_date, created_at desc);

-- ============================================================
-- RLS
-- ============================================================
alter table public.external_channel_providers enable row level security;
alter table public.external_channel_connections enable row level security;
alter table public.external_property_mappings enable row level security;
alter table public.external_room_mappings enable row level security;
alter table public.external_rate_plan_mappings enable row level security;
alter table public.external_reservations enable row level security;
alter table public.external_inventory_events enable row level security;
alter table public.inventory_sync_state enable row level security;
alter table public.inventory_sync_errors enable row level security;
alter table public.inventory_change_log enable row level security;

create policy "ext_providers_read" on public.external_channel_providers
  for select to authenticated
  using (true);
create policy "ext_providers_admin_write" on public.external_channel_providers
  for all to authenticated
  using (public.is_platform_admin((select auth.uid())))
  with check (public.is_platform_admin((select auth.uid())));

create policy "ext_connections_owner_rw" on public.external_channel_connections
  for all to authenticated
  using (
    owner_user_id = (select auth.uid())
    or public.is_platform_admin((select auth.uid()))
  )
  with check (
    owner_user_id = (select auth.uid())
    or public.is_platform_admin((select auth.uid()))
  );

create policy "ext_property_mappings_rw" on public.external_property_mappings
  for all to authenticated
  using (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ))
  with check (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ));

create policy "ext_room_mappings_rw" on public.external_room_mappings
  for all to authenticated
  using (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ))
  with check (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ));

create policy "ext_rate_plan_mappings_rw" on public.external_rate_plan_mappings
  for all to authenticated
  using (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ))
  with check (exists (
    select 1 from public.external_channel_connections c
    where c.id = connection_id
      and (c.owner_user_id = (select auth.uid()) or public.is_platform_admin((select auth.uid())))
  ));

create policy "ext_reservations_read" on public.external_reservations
  for select to authenticated
  using (
    public.is_platform_admin((select auth.uid()))
    or public.owns_venue((select auth.uid()), venue_id)
  );

create policy "ext_events_read" on public.external_inventory_events
  for select to authenticated
  using (
    public.is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.external_channel_connections c
      where c.id = connection_id and c.owner_user_id = (select auth.uid())
    )
  );

create policy "sync_state_read" on public.inventory_sync_state
  for select to authenticated
  using (
    public.is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.external_channel_connections c
      where c.id = connection_id and c.owner_user_id = (select auth.uid())
    )
  );

create policy "sync_errors_read" on public.inventory_sync_errors
  for select to authenticated
  using (
    public.is_platform_admin((select auth.uid()))
    or exists (
      select 1 from public.external_channel_connections c
      where c.id = connection_id and c.owner_user_id = (select auth.uid())
    )
  );

create policy "inventory_change_log_read" on public.inventory_change_log
  for select to authenticated
  using (
    public.is_platform_admin((select auth.uid()))
    or public.owns_venue((select auth.uid()), venue_id)
  );

revoke all on
  public.external_channel_providers,
  public.external_channel_connections,
  public.external_property_mappings,
  public.external_room_mappings,
  public.external_rate_plan_mappings,
  public.external_reservations,
  public.external_inventory_events,
  public.inventory_sync_state,
  public.inventory_sync_errors,
  public.inventory_change_log
from public;

-- P1 fix: owners must use the sanctioned disconnect RPC
-- (disconnect_external_channel_connection), which soft-updates status
-- and writes an inventory_change_log entry. A raw client DELETE would
-- destroy the row and bypass that audit trail entirely, so DELETE is
-- intentionally withheld from authenticated even though
-- select/insert/update remain (insert/update still gated by the
-- ext_connections_owner_rw RLS policy below).
grant select, insert, update on public.external_channel_connections to authenticated;
revoke delete on public.external_channel_connections from authenticated;
grant select, insert, update, delete on public.external_property_mappings to authenticated;
grant select, insert, update, delete on public.external_room_mappings to authenticated;
grant select, insert, update, delete on public.external_rate_plan_mappings to authenticated;
grant select on public.external_channel_providers to authenticated;
grant select on public.external_reservations to authenticated;
grant select on public.external_inventory_events to authenticated;
grant select on public.inventory_sync_state to authenticated;
grant select on public.inventory_sync_errors to authenticated;
grant select on public.inventory_change_log to authenticated;

-- ============================================================
-- P1 fix: mapping integrity — a mapping row must reference a
-- local venue/slot that actually belongs to its own connection's
-- venue. Implemented as a BEFORE INSERT/UPDATE trigger (not just an
-- RLS WITH CHECK) so the guarantee holds for every writer, including
-- the service-role key, not only the `authenticated` role.
-- ============================================================
create or replace function public.validate_external_mapping_venue()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_connection_venue_id uuid;
  v_target_venue_id uuid;
begin
  select venue_id into v_connection_venue_id
  from public.external_channel_connections
  where id = new.connection_id;

  if v_connection_venue_id is null then
    raise exception 'external mapping references unknown connection_id %', new.connection_id
      using errcode = 'foreign_key_violation';
  end if;

  if tg_table_name = 'external_property_mappings' then
    if new.local_venue_id is distinct from v_connection_venue_id then
      raise exception
        'external_property_mappings.local_venue_id (%) does not match connection''s venue (%)',
        new.local_venue_id, v_connection_venue_id
        using errcode = 'check_violation';
    end if;

  elsif tg_table_name in ('external_room_mappings', 'external_rate_plan_mappings') then
    if new.local_slot_id is not null then
      select venue_id into v_target_venue_id
      from public.time_slots
      where id = new.local_slot_id;

      if v_target_venue_id is null then
        raise exception 'mapping references unknown local_slot_id %', new.local_slot_id
          using errcode = 'foreign_key_violation';
      end if;

      if v_target_venue_id is distinct from v_connection_venue_id then
        raise exception
          '% .local_slot_id (%) belongs to a different venue than connection %''s venue (%)',
          tg_table_name, new.local_slot_id, new.connection_id, v_connection_venue_id
          using errcode = 'check_violation';
      end if;
    end if;
  end if;

  return new;
end;
$$;

comment on function public.validate_external_mapping_venue() is
  'Defense-in-depth guard: rejects any external_{property,room,rate_plan}_mappings row whose local_venue_id/local_slot_id does not belong to its own connection''s venue. Runs for every writer (RLS-independent).';

drop trigger if exists trg_validate_property_mapping_venue on public.external_property_mappings;
create trigger trg_validate_property_mapping_venue
  before insert or update on public.external_property_mappings
  for each row execute function public.validate_external_mapping_venue();

drop trigger if exists trg_validate_room_mapping_venue on public.external_room_mappings;
create trigger trg_validate_room_mapping_venue
  before insert or update on public.external_room_mappings
  for each row execute function public.validate_external_mapping_venue();

drop trigger if exists trg_validate_rate_plan_mapping_venue on public.external_rate_plan_mappings;
create trigger trg_validate_rate_plan_mapping_venue
  before insert or update on public.external_rate_plan_mappings
  for each row execute function public.validate_external_mapping_venue();
