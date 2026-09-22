-- Admin clients need to read the review queue, but only the existing
-- administrator policies may expose rows. Imports and job writes remain
-- server-role-only.
revoke all on table public.venue_discovery_jobs,
  public.venue_discovery_staging from public, anon, authenticated;
grant select on table public.venue_discovery_jobs,
  public.venue_discovery_staging to authenticated;
grant select, insert, update on table public.venue_discovery_jobs
  to service_role;
grant select on table public.venue_discovery_staging to service_role;

-- The RPC has its own administrator check, so use a definer context to make
-- the state transition without granting clients direct UPDATE privileges.
create or replace function public.review_discovered_venue(
  p_staging_id uuid,
  p_action text
)
returns public.venue_discovery_staging
language plpgsql
security definer
set search_path = ''
as $function$
declare
  r public.venue_discovery_staging;
begin
  if auth.uid() is null or not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  if p_action is null or p_action not in ('APPROVE', 'REJECT') then
    raise exception 'invalid_review_action';
  end if;

  update public.venue_discovery_staging
  set status = case when p_action = 'APPROVE' then 'APPROVED' else 'REJECTED' end,
      updated_at = pg_catalog.now()
  where id = p_staging_id and status = 'PENDING_REVIEW'
  returning * into r;

  if r.id is null then
    raise exception 'staging_record_not_pending';
  end if;
  return r;
end;
$function$;

revoke all on function public.review_discovered_venue(uuid, text)
  from public, anon, authenticated;
grant execute on function public.review_discovered_venue(uuid, text)
  to authenticated;
