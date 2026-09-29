-- Harden the Auth profile/role bootstrap trigger without changing its behavior.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'customer')
  on conflict (user_id, role) do nothing;

  return new;
end;
$$;

-- The Auth trigger runs under the SECURITY DEFINER function owner.
-- Preserve existing authenticated/service-role compatibility while removing
-- unnecessary public and anonymous execution.
revoke execute on function public.handle_new_user() from public, anon;
grant execute on function public.handle_new_user() to authenticated, service_role;
