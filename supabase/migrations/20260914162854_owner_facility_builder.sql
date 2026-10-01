-- One owner-scoped CMS document, using existing draft snapshots, RLS,
-- unique non-multiple section constraint, and publish_venue_sections RPC.
-- No new tables or client-writable global facility catalog.
insert into public.venue_section_types
  (key, name, description, icon, allows_multiple, editable_fields, display_order)
values
  ('owner_facilities', 'Facilities', 'Manage with the owner facility builder.',
   'category', false,
   '{"title":false,"content":false,"image":false,"subsections":false}'::jsonb, 80)
on conflict (key) do nothing;

-- Facility builder publication is deliberately section-scoped. The existing
-- venue-wide RPC remains for the legacy section manager, while this RPC lets
-- the owner flow publish only the authorized facility container.
create or replace function public.publish_venue_section(
  p_venue_id uuid,
  p_section_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if not (public.owns_venue(auth.uid(), p_venue_id)
          or public.is_platform_admin(auth.uid())) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_OWNER_OR_NOT_FOUND');
  end if;

  perform set_config('app.publishing_venue_sections', 'true', true);
  update public.venue_sections s
  set published_config = jsonb_build_object(
        'is_enabled', s.is_enabled,
        'title', s.title,
        'title_i18n', s.title_i18n,
        'content', s.content,
        'content_i18n', s.content_i18n,
        'image_url', s.image_url,
        'icon', s.icon,
        'display_order', s.display_order,
        'visible_subsections', s.visible_subsections,
        'config', s.config
      ),
      published_at = now(),
      published_by = auth.uid()
  where s.id = p_section_id and s.venue_id = p_venue_id;
  get diagnostics v_count = row_count;
  perform set_config('app.publishing_venue_sections', 'false', true);

  if v_count = 0 then
    return jsonb_build_object('success', false, 'error_code', 'SECTION_NOT_FOUND');
  end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'venue_section_published', 'venue_section', p_section_id,
          jsonb_build_object('venue_id', p_venue_id));
  return jsonb_build_object('success', true, 'section_id', p_section_id,
                            'published_at', now());
end;
$$;

revoke all on function public.publish_venue_section(uuid, uuid) from public, anon;
grant execute on function public.publish_venue_section(uuid, uuid) to authenticated;

-- Phase 4 media uses the existing administrator-managed bucket under a
-- dedicated namespace. Keep the prior category paths intact while allowing
-- only category managers to write CMS paths.
drop policy if exists category_media_manager_insert on storage.objects;
create policy category_media_manager_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'category-media'
    and public.is_category_manager()
    and (storage.foldername(name))[1] in ('categories', 'subsections', 'cms')
  );

drop policy if exists category_media_manager_update on storage.objects;
create policy category_media_manager_update on storage.objects
  for update to authenticated
  using (bucket_id = 'category-media' and public.is_category_manager())
  with check (bucket_id = 'category-media' and public.is_category_manager());

drop policy if exists category_media_manager_delete on storage.objects;
create policy category_media_manager_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'category-media' and public.is_category_manager());
