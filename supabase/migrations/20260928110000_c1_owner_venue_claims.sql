-- Phase C1: owner claims for discovered places.
-- Imported places remain unowned drafts until an administrator approves a claim.

create table if not exists public.venue_claims (
  id uuid primary key default gen_random_uuid(),
  staging_id uuid not null references public.venue_discovery_staging(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  venue_id uuid references public.venues(id) on delete set null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
  proof_note text,
  review_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists venue_claims_one_open_per_staging
  on public.venue_claims(staging_id)
  where status in ('PENDING', 'APPROVED');
create index if not exists venue_claims_owner_idx
  on public.venue_claims(owner_user_id, created_at desc);
create index if not exists venue_claims_status_idx
  on public.venue_claims(status, created_at desc);

alter table public.venue_claims enable row level security;

drop policy if exists venue_claims_self_read on public.venue_claims;
create policy venue_claims_self_read on public.venue_claims
  for select to authenticated
  using (
    owner_user_id = auth.uid()
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

revoke all on table public.venue_claims from public, anon, authenticated;
grant select on table public.venue_claims to authenticated;

drop trigger if exists venue_claims_updated_at on public.venue_claims;
create trigger venue_claims_updated_at
  before update on public.venue_claims
  for each row execute function public.set_updated_at();

create or replace function public.submit_venue_claim(
  p_staging_id uuid,
  p_proof_note text default null
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_stage public.venue_discovery_staging;
  v_claim public.venue_claims;
begin
  if v_uid is null or not public.has_role(v_uid, 'venue_owner') then
    raise exception 'owner_role_required';
  end if;

  select o.id into v_org_id
  from public.organizations o
  where o.owner_user_id = v_uid
    and o.org_type = 'venue_owner'
    and o.is_active
    and o.deleted_at is null
  order by o.created_at
  limit 1;
  if v_org_id is null then raise exception 'owner_organization_not_found'; end if;

  select * into v_stage
  from public.venue_discovery_staging
  where id = p_staging_id
  for update;
  if v_stage.id is null then raise exception 'discovered_place_not_found'; end if;
  if v_stage.status not in ('PENDING_REVIEW', 'APPROVED', 'PUBLISHED') then
    raise exception 'discovered_place_not_claimable';
  end if;

  if exists (
    select 1 from public.venue_claims c
    where c.staging_id = p_staging_id
      and c.status in ('PENDING', 'APPROVED')
  ) then
    raise exception 'discovered_place_already_claimed';
  end if;

  insert into public.venue_claims(
    staging_id, owner_user_id, organization_id, venue_id, proof_note
  ) values (
    p_staging_id, v_uid, v_org_id, v_stage.venue_id,
    nullif(left(trim(coalesce(p_proof_note, '')), 1000), '')
  ) returning * into v_claim;
  return v_claim;
end;
$function$;

create or replace function public.review_venue_claim(
  p_claim_id uuid,
  p_action text,
  p_review_note text default null
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_claim public.venue_claims;
  v_stage public.venue_discovery_staging;
  v_category_id uuid;
  v_existing_org uuid;
  v_venue_id uuid;
begin
  if v_uid is null or not (
    public.has_role(v_uid, 'administrator')
    or public.has_role(v_uid, 'super_administrator')
  ) then raise exception 'admin_role_required'; end if;
  if p_action not in ('APPROVE', 'REJECT') then
    raise exception 'invalid_claim_action';
  end if;

  select * into v_claim from public.venue_claims where id = p_claim_id for update;
  if v_claim.id is null then raise exception 'claim_not_found'; end if;
  if v_claim.status <> 'PENDING' then raise exception 'claim_not_pending'; end if;

  select * into v_stage
  from public.venue_discovery_staging
  where id = v_claim.staging_id
  for update;
  if v_stage.id is null then raise exception 'discovered_place_not_found'; end if;

  if p_action = 'REJECT' then
    update public.venue_claims
    set status = 'REJECTED', review_note = nullif(left(trim(coalesce(p_review_note, '')), 1000), ''),
        reviewed_by = v_uid, reviewed_at = now()
    where id = p_claim_id
    returning * into v_claim;
    return v_claim;
  end if;

  if v_stage.status not in ('PENDING_REVIEW', 'APPROVED', 'PUBLISHED') then
    raise exception 'discovered_place_not_approved';
  end if;

  v_venue_id := v_stage.venue_id;
  if v_venue_id is not null then
    select org_id into v_existing_org from public.venues where id = v_venue_id for update;
    if v_existing_org is not null and v_existing_org <> v_claim.organization_id then
      raise exception 'venue_already_owned';
    end if;
    update public.venues
    set org_id = v_claim.organization_id,
        is_active = false,
        is_verified = false,
        listing_status = 'draft',
        updated_at = now()
    where id = v_venue_id;
  else
    select vc.id into v_category_id
    from public.venue_categories vc
    where lower(vc.name) = lower(v_stage.category)
       or lower(vc.slug) = lower(v_stage.category)
    limit 1;
    if v_category_id is null then raise exception 'venue_category_not_found'; end if;

    insert into public.venues(
      org_id, category_id, name, slug, address_line1, city, state,
      latitude, longitude, capacity, pricing_base_amount, is_verified,
      is_active, listing_status
    ) values (
      v_claim.organization_id, v_category_id, v_stage.name,
      lower(regexp_replace(v_stage.name, '[^a-z0-9]+', '-', 'gi')),
      v_stage.address, v_stage.city, v_stage.state, v_stage.latitude,
      v_stage.longitude, 1, 0, false, false, 'draft'
    ) returning id into v_venue_id;
  end if;

  update public.venue_discovery_staging
  set venue_id = v_venue_id, status = case when status = 'PUBLISHED' then status else 'APPROVED' end,
      updated_at = now()
  where id = v_stage.id;

  update public.venue_claims
  set status = 'APPROVED', venue_id = v_venue_id,
      review_note = nullif(left(trim(coalesce(p_review_note, '')), 1000), ''),
      reviewed_by = v_uid, reviewed_at = now()
  where id = p_claim_id
  returning * into v_claim;
  return v_claim;
end;
$function$;

create or replace function public.withdraw_venue_claim(p_claim_id uuid)
returns public.venue_claims
language plpgsql
security definer
set search_path = public
as $function$
declare v_claim public.venue_claims;
begin
  select * into v_claim from public.venue_claims
  where id = p_claim_id and owner_user_id = auth.uid() for update;
  if v_claim.id is null then raise exception 'claim_not_found'; end if;
  if v_claim.status <> 'PENDING' then raise exception 'claim_not_pending'; end if;
  update public.venue_claims set status = 'WITHDRAWN' where id = p_claim_id returning * into v_claim;
  return v_claim;
end;
$function$;

revoke all on function public.submit_venue_claim(uuid, text) from public, anon;
revoke all on function public.review_venue_claim(uuid, text, text) from public, anon;
revoke all on function public.withdraw_venue_claim(uuid) from public, anon;
grant execute on function public.submit_venue_claim(uuid, text) to authenticated;
grant execute on function public.review_venue_claim(uuid, text, text) to authenticated;
grant execute on function public.withdraw_venue_claim(uuid) to authenticated;
