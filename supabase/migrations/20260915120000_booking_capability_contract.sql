-- Phase 14: Booking ↔ Capability Contract
-- Adds server-side capability resolution to the booking flow.
-- Preserves backward compatibility: venues without capabilities default to bookable.

-- 1. Add resolved capability columns to bookings for audit trail.
alter table public.bookings
  add column if not exists resolved_capabilities jsonb,
  add column if not exists catalog_node_path text;

comment on column public.bookings.resolved_capabilities is
  'Resolved CMS capabilities at booking time. Server-authoritative, never client-supplied.';
comment on column public.bookings.catalog_node_path is
  'Hierarchy path: facility_type_key/section_key/subsection_key. Empty when no CMS config.';

-- 2. resolve_booking_capabilities(p_venue_id) → jsonb
-- Reads the CMS catalog from feature_flags.config and resolves capabilities
-- through the full hierarchy for the venue's category.
-- Returns: { "interaction_mode": "bookable", "capacity": 100, ... } or null.
create or replace function public.resolve_booking_capabilities(p_venue_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_config jsonb;
  v_parent_section text;
  v_category_slug text;
  v_facility_types jsonb;
  v_type jsonb;
  v_sections jsonb;
  v_section jsonb;
  v_subsections jsonb;
  v_subsection jsonb;
  v_type_caps jsonb;
  v_section_caps jsonb;
  v_subsection_caps jsonb;
  v_resolved jsonb := '{}'::jsonb;
  v_sub_slug text;
  key text;
begin
  -- Look up the venue's category and parent_section.
  select vc.slug, vc.parent_section
  into v_category_slug, v_parent_section
  from public.venues v
  join public.venue_categories vc on vc.id = (
    select vs.category_id from public.venue_subsections vs
    where vs.slug = (v.metadata->>'category_slug')
    limit 1
  )
  where v.id = p_venue_id
    and v.is_active = true
    and v.deleted_at is null
    and vc.is_active = true
    and vc.deleted_at is null;

  -- If no category found, try direct metadata parent_section.
  if v_parent_section is null then
    select v.metadata->>'parent_section', v.metadata->>'category_slug'
    into v_parent_section, v_category_slug
    from public.venues v
    where v.id = p_venue_id
      and v.is_active = true
      and v.deleted_at is null;
  end if;

  if v_parent_section is null then
    return null;
  end if;

  -- Read the CMS catalog from feature_flags.
  select ff.config into v_config
  from public.feature_flags ff
  where ff.key = 'category_catalog' and ff.enabled = true;

  if v_config is null or v_config = '{}'::jsonb then
    return null;
  end if;

  v_facility_types := v_config->'facility_types';
  if v_facility_types is null or jsonb_array_length(v_facility_types) = 0 then
    return null;
  end if;

  -- Find the facility type matching the venue's parent_section.
  for i in 0..jsonb_array_length(v_facility_types) - 1 loop
    v_type := v_facility_types->i;
    if v_type->>'key' = v_parent_section then
      v_type_caps := v_type->'capabilities';
      v_sections := v_type->'sections';
      exit;
    end if;
  end loop;

  if v_type is null then
    return null;
  end if;

  -- Resolve type-level capabilities.
  if v_type_caps is not null and v_type_caps != 'null'::jsonb then
    v_resolved := v_type_caps;
  end if;

  -- Find the section matching the category slug (via search_aliases).
  if v_sections is not null then
    for i in 0..jsonb_array_length(v_sections) - 1 loop
      v_section := v_sections->i;
      -- Check if the category slug is in this section's search_aliases.
      if v_section->'search_aliases' is not null then
        for j in 0..jsonb_array_length(v_section->'search_aliases') - 1 loop
          if v_section->'search_aliases'->>j = v_category_slug then
            v_section_caps := v_section->'capabilities';
            exit;
          end if;
        end loop;
        if v_section_caps is not null then exit; end if;
      end if;
      -- Fallback: section key matches category slug.
      if v_section->>'key' = v_category_slug then
        v_section_caps := v_section->'capabilities';
        exit;
      end if;
    end loop;
  end if;

  -- Merge section capabilities (section overrides type).
  if v_section_caps is not null and v_section_caps != 'null'::jsonb then
    -- Merge each key from section into resolved.
    for key in select jsonb_object_keys(v_section_caps) loop
      if v_section_caps->key is not null and v_section_caps->key != 'null'::jsonb then
        v_resolved := v_resolved || jsonb_build_object(key, v_section_caps->key);
      end if;
    end loop;
  end if;

  -- Find the subsection matching the category slug.
  if v_sections is not null and v_category_slug is not null then
    for i in 0..jsonb_array_length(v_sections) - 1 loop
      v_section := v_sections->i;
      v_subsections := v_section->'subsections';
      if v_subsections is not null then
        for j in 0..jsonb_array_length(v_subsections) - 1 loop
          v_subsection := v_subsections->j;
          -- Match on key or alias_slugs.
          if v_subsection->>'key' = v_category_slug then
            v_subsection_caps := v_subsection->'capabilities';
            exit;
          end if;
          if v_subsection->'alias_slugs' is not null then
            for k in 0..jsonb_array_length(v_subsection->'alias_slugs') - 1 loop
              if v_subsection->'alias_slugs'->>k = v_category_slug then
                v_subsection_caps := v_subsection->'capabilities';
                exit;
              end if;
            end loop;
            if v_subsection_caps is not null then exit; end if;
          end if;
        end loop;
        if v_subsection_caps is not null then exit; end if;
      end if;
    end loop;
  end if;

  -- Merge subsection capabilities (subsection overrides section/type).
  if v_subsection_caps is not null and v_subsection_caps != 'null'::jsonb then
    for key in select jsonb_object_keys(v_subsection_caps) loop
      if v_subsection_caps->key is not null and v_subsection_caps->key != 'null'::jsonb then
        v_resolved := v_resolved || jsonb_build_object(key, v_subsection_caps->key);
      end if;
    end loop;
  end if;

  -- Return null if no capabilities were resolved.
  if v_resolved = '{}'::jsonb then
    return null;
  end if;

  return v_resolved;
end;
$$;

comment on function public.resolve_booking_capabilities(uuid) is
  'Resolves CMS capabilities for a venue through the full hierarchy. Server-authoritative.';

grant execute on function public.resolve_booking_capabilities(uuid) to authenticated, anon;

-- 3. validate_booking_capabilities(p_venue_id, p_slot_id, p_book_date) → jsonb
-- Validates a booking request against published capabilities.
-- Returns { "valid": true/false, "error_code": "...", "message": "..." }
create or replace function public.validate_booking_capabilities(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_caps jsonb;
  v_slot record;
  v_mode text;
  v_approval_required boolean;
  v_max_capacity integer;
  v_start_time time;
  v_end_time time;
  v_slot_start_minutes integer;
  v_slot_end_minutes integer;
  v_max_slots integer;
  v_slot_count integer;
  v_day_of_week text;
  v_allowed_days jsonb;
begin
  -- Resolve capabilities for this venue.
  v_caps := public.resolve_booking_capabilities(p_venue_id);

  -- No capabilities configured → default to bookable (backward compatible).
  if v_caps is null then
    return jsonb_build_object('valid', true, 'has_caps', false);
  end if;

  -- Check interaction mode.
  v_mode := v_caps->>'interaction_mode';
  if v_mode is not null and v_mode != 'bookable' then
    return jsonb_build_object(
      'valid', false,
      'error_code', 'NOT_BOOKABLE',
      'message', 'This facility is not available for direct booking.'
    );
  end if;

  -- Load the slot for time-based checks.
  select s.start_time, s.end_time, s.price_amount, v.tax_rate
  into v_slot
  from public.time_slots s
  join public.venues v on v.id = s.venue_id
  where s.id = p_slot_id
    and s.venue_id = p_venue_id
    and s.is_active = true
    and v.is_active = true
    and v.deleted_at is null;

  if not found then
    return jsonb_build_object(
      'valid', false,
      'error_code', 'INVALID_SLOT',
      'message', 'The selected time slot is not available.'
    );
  end if;

  v_start_time := v_slot.start_time;
  v_end_time := v_slot.end_time;

  -- Validate time slot against allowed schedule (if configured).
  v_allowed_days := v_caps->'availability'->'weekly_schedule';
  if v_allowed_days is not null and v_allowed_days != 'null'::jsonb then
    v_day_of_week := to_char(p_book_date, 'fmday');
    -- Normalize to lowercase for matching.
    v_day_of_week := lower(v_day_of_week);
    if v_allowed_days->v_day_of_week is null then
      return jsonb_build_object(
        'valid', false,
        'error_code', 'DAY_NOT_ALLOWED',
        'message', 'Bookings are not available on this day of the week.'
      );
    end if;
  end if;

  -- Validate max slots (if configured).
  v_max_slots := (v_caps->>'max_slots')::integer;
  if v_max_slots is not null then
    select count(*) into v_slot_count
    from public.time_slots s
    where s.venue_id = p_venue_id
      and s.is_active = true;

    if v_slot_count > v_max_slots then
      return jsonb_build_object(
        'valid', false,
        'error_code', 'TOO_MANY_SLOTS',
        'message', 'This facility has too many time slots configured.'
      );
    end if;
  end if;

  -- All checks passed.
  return jsonb_build_object(
    'valid', true,
    'has_caps', true,
    'interaction_mode', coalesce(v_mode, 'bookable'),
    'approval_required', coalesce((v_caps->>'approval_required')::boolean, true)
  );
end;
$$;

comment on function public.validate_booking_capabilities(uuid, uuid, date) is
  'Validates a booking request against published CMS capabilities.';

grant execute on function public.validate_booking_capabilities(uuid, uuid, date) to authenticated;

-- 4. Modify request_venue_booking to validate capabilities and store resolved caps.
-- We create a new version that calls validate_booking_capabilities.
-- The existing function signature is preserved; capabilities are validated internally.
create or replace function public.request_venue_booking(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_base_amount numeric default 0,
  p_tax_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_approval_minutes integer default 120
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_slot record;
  v_existing record;
  v_hold_id uuid;
  v_booking_id uuid;
  v_booking_ref text;
  v_requested_at timestamptz := now();
  v_approval_expires_at timestamptz;
  v_lock_key bigint;
  v_request_lock_key bigint;
  v_base numeric(12,2);
  v_tax numeric(12,2);
  v_total numeric(12,2);
  v_owner_id uuid;
  v_caps_validation jsonb;
  v_resolved_caps jsonb;
  v_approval_required boolean;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if p_idempotency_key is null then
    return jsonb_build_object('success', false, 'error_code', 'MISSING_IDEMPOTENCY_KEY');
  end if;
  if p_book_date < current_date then
    return jsonb_build_object('success', false, 'error_code', 'DATE_IN_PAST');
  end if;

  v_request_lock_key := hashtextextended(
    'booking-request:' || p_user_id::text || ':' || p_idempotency_key::text, 0
  );
  perform pg_advisory_xact_lock(v_request_lock_key);

  select b.id, b.hold_id, b.booking_ref, b.status, b.approval_expires_at,
         b.payment_expires_at, b.total_amount
  into v_existing
  from public.bookings b
  where b.user_id = p_user_id
    and b.request_idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'success', true, 'booking_id', v_existing.id, 'hold_id', v_existing.hold_id,
      'booking_ref', v_existing.booking_ref, 'status', v_existing.status,
      'approval_expires_at', v_existing.approval_expires_at,
      'payment_expires_at', v_existing.payment_expires_at,
      'total_amount', v_existing.total_amount, 'idempotent', true
    );
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  perform public.expire_stale_holds();

  select s.id, s.label, s.start_time, s.end_time, s.price_amount,
         v.tax_rate, v.org_id
  into v_slot
  from public.time_slots s
  join public.venues v on v.id = s.venue_id
  where s.id = p_slot_id
    and s.venue_id = p_venue_id
    and s.is_active = true
    and v.is_active = true
    and v.deleted_at is null;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_SLOT');
  end if;

  if exists (
    select 1 from public.venue_blocked_dates d
    where d.venue_id = p_venue_id and d.blocked_date = p_book_date
  ) then
    return jsonb_build_object('success', false, 'error_code', 'DATE_BLOCKED');
  end if;

  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id and h.book_date = p_book_date
      and h.status = 'active' and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id
          and s.start_time < v_slot.end_time
          and s.end_time > v_slot.start_time
      )
  ) or exists (
    select 1 from public.bookings b
    where b.venue_id = p_venue_id and b.book_date = p_book_date
      and b.status in ('held', 'awaiting_owner_approval', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot.end_time and b.end_time > v_slot.start_time
  ) then
    return jsonb_build_object(
      'success', false, 'error_code', 'SLOT_UNAVAILABLE',
      'message', 'The selected venue, date, and time slot is no longer available.'
    );
  end if;

  -- Validate against CMS capabilities (authoritative server-side check).
  v_caps_validation := public.validate_booking_capabilities(p_venue_id, p_slot_id, p_book_date);
  if (v_caps_validation->>'valid')::boolean = false then
    return jsonb_build_object(
      'success', false,
      'error_code', v_caps_validation->>'error_code',
      'message', v_caps_validation->>'message'
    );
  end if;

  -- Resolve capabilities for audit trail.
  v_resolved_caps := public.resolve_booking_capabilities(p_venue_id);

  -- Use capability-derived approval_required when available.
  v_approval_required := coalesce(
    (v_caps_validation->>'approval_required')::boolean,
    true
  );

  v_base := round(coalesce(v_slot.price_amount, 0)::numeric, 2);
  v_tax := round(v_base * greatest(0, least(coalesce(v_slot.tax_rate, 0), 100)) / 100, 2);
  v_total := greatest(0, v_base + v_tax);
  v_approval_expires_at := v_requested_at +
    (greatest(15, least(coalesce(p_approval_minutes, 120), 1440)) * interval '1 minute');
  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, v_total,
    v_approval_expires_at, 'active'
  ) returning id into v_hold_id;

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
    hold_id, status, quantity, amount, tax_amount, discount_amount, total_amount,
    currency, request_idempotency_key, approval_required, approval_requested_at,
    approval_expires_at, resolved_capabilities, catalog_node_path, metadata
  ) values (
    v_booking_ref, p_user_id, p_venue_id, p_slot_id, p_book_date,
    v_slot.start_time, v_slot.end_time, v_hold_id, 'awaiting_owner_approval', 1,
    v_base, v_tax, 0, v_total, 'INR', p_idempotency_key, v_approval_required, v_requested_at,
    v_approval_expires_at,
    v_resolved_caps,
    null,
    jsonb_build_object(
      'approval_mode', 'request_to_book',
      'request_idempotency_key', p_idempotency_key,
      'has_capabilities', v_caps_validation->>'has_caps',
      'interaction_mode', v_caps_validation->>'interaction_mode'
    )
  ) returning id into v_booking_id;

  select o.owner_user_id into v_owner_id
  from public.organizations o
  where o.id = v_slot.org_id and o.deleted_at is null;
  if v_owner_id is not null then
    insert into public.notifications (user_id, title, body, type, data)
    values (
      v_owner_id, 'New booking request',
      'A customer requested your venue. Review the exact date and time before the approval deadline.',
      'system', jsonb_build_object('booking_id', v_booking_id, 'venue_id', p_venue_id,
        'approval_expires_at', v_approval_expires_at)
    );
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    p_user_id, 'booking_requested', 'booking', v_booking_id,
    jsonb_build_object('venue_id', p_venue_id, 'slot_id', p_slot_id,
      'book_date', p_book_date, 'from_status', null,
      'to_status', 'awaiting_owner_approval', 'actor_role', 'customer',
      'has_capabilities', v_caps_validation->>'has_caps')
  );

  return jsonb_build_object(
    'success', true, 'booking_id', v_booking_id, 'hold_id', v_hold_id,
    'booking_ref', v_booking_ref, 'status', 'awaiting_owner_approval',
    'approval_expires_at', v_approval_expires_at, 'total_amount', v_total,
    'message', 'Your request was sent to the venue owner for approval.'
  );
end;
$$;

revoke all on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  from public, anon;
grant execute on function public.request_venue_booking(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer)
  to authenticated;
