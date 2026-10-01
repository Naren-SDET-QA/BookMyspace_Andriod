-- Replace the public-role venue-images writes.
--
-- The previous policies were created without a TO clause, so they applied to
-- public (anon and authenticated). Their check required auth.uid(), which
-- rejects anon, but any authenticated user could insert, update, and delete
-- an object whose first folder was their own user id.
--
-- Owner Media Manager stores {auth.uid()}/{venue_id}/... . These policies
-- keep that path for a venue whose organization the caller owns, and no
-- longer allow a customer to write an arbitrary object under their user id.
-- objects.name is qualified because organizations.name would hide the
-- storage object name inside the subquery.
--
-- Organization-folder policies, platform-admin policies, public reads,
-- education-media, and category-media are untouched.

drop policy if exists "venue_images_storage_owner_insert" on storage.objects;
drop policy if exists "venue_images_storage_owner_update" on storage.objects;
drop policy if exists "venue_images_storage_owner_delete" on storage.objects;

create policy "venue_images_storage_owner_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'venue-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id::text = (storage.foldername(objects.name))[2]
        and o.owner_user_id = (select auth.uid())
        and o.deleted_at is null
        and o.is_active = true
        and v.deleted_at is null
    )
  );

create policy "venue_images_storage_owner_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'venue-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id::text = (storage.foldername(objects.name))[2]
        and o.owner_user_id = (select auth.uid())
        and o.deleted_at is null
    )
  )
  with check (
    bucket_id = 'venue-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id::text = (storage.foldername(objects.name))[2]
        and o.owner_user_id = (select auth.uid())
        and o.deleted_at is null
    )
  );

create policy "venue_images_storage_owner_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'venue-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id::text = (storage.foldername(objects.name))[2]
        and o.owner_user_id = (select auth.uid())
        and o.deleted_at is null
    )
  );
