-- Legacy owner/admin ALL policies were scoped to PUBLIC. A SELECT combines
-- ALL and SELECT policy expressions, so anonymous catalog reads attempted to
-- call the deliberately restricted can_edit_venue function. Restrict the
-- write/admin policies to real authenticated sessions; do not grant anonymous
-- execution or change their ownership predicates or the public-read policies.
do $$
declare item record;
begin
  for item in select * from (values
    ('venue_images','venue_images_owner_write'),
    ('events','events_org_write'),
    ('courses','courses_org_write'),
    ('institutes','institutes_org_write'),
    ('feature_flags','feature_flags_admin_write'),
    ('venues','venues_admin_read'),
    ('venues','venues_owner_insert'),
    ('venues','venues_owner_write')
  ) as policies(table_name,policy_name)
  loop
    if exists(select 1 from pg_policies where schemaname='public'
      and tablename=item.table_name and policyname=item.policy_name) then
      execute format('alter policy %I on public.%I to authenticated',item.policy_name,item.table_name);
    end if;
  end loop;
end $$;
