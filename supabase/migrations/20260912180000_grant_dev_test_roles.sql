-- Grant legitimate roles to existing Auth users in development.
-- This does NOT create auth.users and does NOT bypass RLS.
-- Create the Auth identities first (Supabase Auth Admin / Dashboard), then re-run.
--
-- Grants:
--   owner.dev@bookmyspace.app  -> venue_owner + owner_profiles + organization
--   admin.dev@bookmyspace.app  -> administrator
--   support.dev@bookmyspace.app -> support_agent (only if that Auth user exists)
--
-- Never grants administrator to customers. Never invents Auth sessions.

do $$
declare
  uid uuid;
begin
  select id into uid from auth.users where email = 'owner.dev@bookmyspace.app';
  if uid is not null then
    insert into public.user_roles (user_id, role)
    values (uid, 'venue_owner')
    on conflict (user_id, role) do update
      set revoked_at = null,
          granted_at = now();

    insert into public.owner_profiles (user_id, email, name)
    values (uid, 'owner.dev@bookmyspace.app', 'DEV Test Owner')
    on conflict (user_id) do update
      set email = excluded.email,
          name = excluded.name;

    insert into public.organizations (owner_user_id, org_type, name)
    select uid, 'venue_owner', 'DEV Owner Test Organisation'
    where not exists (
      select 1
      from public.organizations o
      where o.owner_user_id = uid
        and o.deleted_at is null
    );
  end if;

  select id into uid from auth.users where email = 'admin.dev@bookmyspace.app';
  if uid is not null then
    insert into public.user_roles (user_id, role)
    values (uid, 'administrator')
    on conflict (user_id, role) do update
      set revoked_at = null,
          granted_at = now();
  end if;

  select id into uid from auth.users where email = 'support.dev@bookmyspace.app';
  if uid is not null then
    insert into public.user_roles (user_id, role)
    values (uid, 'support_agent')
    on conflict (user_id, role) do update
      set revoked_at = null,
          granted_at = now();
  end if;
end $$;
