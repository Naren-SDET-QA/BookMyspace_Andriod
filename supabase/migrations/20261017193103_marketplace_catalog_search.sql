-- A read-only catalog projection. Runs as the caller so existing table RLS
-- remains authoritative. No booking, availability or payment state is invented.
create index if not exists venues_marketplace_fts_idx on public.venues using gin
  (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(description, '')))
  where is_active and deleted_at is null;
create index if not exists events_marketplace_fts_idx on public.events using gin
  (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')))
  where status = 'published';
create index if not exists courses_marketplace_fts_idx on public.courses using gin
  (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')))
  where status = 'published';

create or replace function public.marketplace_search(
  p_query text default '', p_city text default '', p_category text default 'all',
  p_sort text default 'relevance', p_min_price numeric default null,
  p_max_price numeric default null, p_from timestamptz default null,
  p_until timestamptz default null, p_limit integer default 24,
  p_offset integer default 0, p_platform text default 'web'
) returns table (
  id uuid, entity_type text, category text, title text, description text,
  city text, image_url text, price numeric, currency text, rating numeric,
  starts_at timestamptz
)
language plpgsql stable security invoker
set search_path = ''
set statement_timeout = '5s'
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_city text := btrim(coalesce(p_city, ''));
  v_tsquery tsquery;
begin
  if p_limit is null or p_limit not between 1 and 48
     or p_offset is null or p_offset not between 0 and 10000
     or length(v_query) > 200 or length(v_city) > 100
     or p_category is null or p_category not in ('all','events','venues','sports','restaurants','experiences','courses')
     or p_sort is null or p_sort not in ('relevance','price_low','price_high','rating','soonest')
     or p_platform is null or p_platform not in ('ios','android','web')
     or p_min_price < 0 or p_max_price < 0
     or p_min_price::text in ('NaN','Infinity','-Infinity')
     or p_max_price::text in ('NaN','Infinity','-Infinity')
     or p_min_price > p_max_price or p_from > p_until then
    raise exception 'invalid_catalog_filters' using errcode = '22023';
  end if;
  v_tsquery := case when v_query = '' then null else websearch_to_tsquery('simple', v_query) end;

  return query
  with catalog as (
    select v.id, 'venue'::text as entity_type,
      case
        when vc.slug in ('sports_ground','sports_turf','turf','badminton','sports_academy') then 'sports'
        when vc.slug in ('restaurant','restaurants','cafe','dining') then 'restaurants'
        when vc.slug in ('experience','experiences','adventure','wellness','kids_activity') then 'experiences'
        else 'venues'
      end::text as category,
      v.name::text as title, coalesce(v.description,'') as description,
      coalesce(v.city,'') as city,
      coalesce((select vi.url from public.venue_images vi where vi.venue_id = v.id
        and vi.is_active and vi.media_kind = 'image'
        order by vi.is_cover desc, vi.sort_order, vi.id limit 1),'') as image_url,
      v.pricing_base_amount as price, v.pricing_currency::text as currency,
      nullif(v.avg_rating, 0) as rating, null::timestamptz as starts_at,
      to_tsvector('simple', coalesce(v.name,'') || ' ' || coalesce(v.description,'')) as document
    from public.venues v left join public.venue_categories vc on vc.id = v.category_id
    where v.is_active and v.deleted_at is null
      and v.listing_status = 'published'
      and (vc.id is null or (vc.is_active and vc.deleted_at is null
        and coalesce(vc.metadata #>> '{listing,published}','true') = 'true'))
      and (p_category not in ('events','courses'))
    union all
    select e.id, 'event', 'events', e.title, coalesce(e.description,''), coalesce(v.city,''),
      coalesce(e.cover_image,''), case when e.is_free then 0 else coalesce(e.ticket_price,0) end,
      'INR', null::numeric, e.starts_at,
      to_tsvector('simple', coalesce(e.title,'') || ' ' || coalesce(e.description,''))
    from public.events e left join public.venues v on v.id = e.venue_id
    where e.status = 'published' and e.ends_at > now()
      and not exists (select 1 from public.feature_flags f where f.key = 'events'
        and (not f.enabled or not (p_platform = any(f.platforms))))
      and (p_category in ('all','events'))
    union all
    select c.id, 'course', 'courses', c.title, coalesce(c.description,''),
      coalesce(i.city,''), coalesce(c.cover_image,''), c.fee_amount, 'INR', null::numeric,
      (select min(cb.starts_on)::timestamptz from public.course_batches cb
        where cb.course_id = c.id and cb.is_active and cb.starts_on >= current_date),
      to_tsvector('simple', coalesce(c.title,'') || ' ' || coalesce(c.description,''))
    from public.courses c join public.institutes i on i.id = c.institute_id
    where c.status = 'published' and (p_category in ('all','courses'))
      and not exists (select 1 from public.feature_flags f where f.key = 'courses'
        and (not f.enabled or not (p_platform = any(f.platforms))))
  )
  select d.id, d.entity_type, d.category, d.title, d.description,
    d.city, d.image_url, d.price, d.currency, d.rating, d.starts_at
  from catalog d
  where (p_category = 'all' or d.category = p_category)
    and (v_city = '' or lower(d.city) = lower(v_city))
    and (v_query = '' or d.document @@ v_tsquery)
    and (p_min_price is null or d.price >= p_min_price)
    and (p_max_price is null or d.price <= p_max_price)
    -- This catalog compares INR prices. Other currencies need a separate
    -- catalog currency selection rather than silent cross-currency sorting.
    and d.currency = 'INR'
    and (p_from is null or d.starts_at >= p_from)
    and (p_until is null or d.starts_at < p_until)
  order by
    case when p_sort = 'relevance' then ts_rank(d.document, v_tsquery) end desc nulls last,
    case when p_sort = 'price_low' then d.price end asc nulls last,
    case when p_sort = 'price_high' then d.price end desc nulls last,
    case when p_sort = 'rating' then d.rating end desc nulls last,
    case when p_sort = 'soonest' then d.starts_at end asc nulls last,
    d.title, d.entity_type, d.id
  limit p_limit offset p_offset;
end;
$$;

-- Grant only columns this projection needs, rather than exposing contact,
-- ownership or other private metadata merely to make an invoker RPC work.
-- Existing RLS policies continue to apply to these source reads.
grant select (id,category_id,name,description,city,pricing_base_amount,pricing_currency,avg_rating,is_active,deleted_at,listing_status)
  on public.venues to anon,authenticated;
grant select (id,slug,is_active,deleted_at,metadata) on public.venue_categories to anon,authenticated;
grant select (id,venue_id,url,is_active,media_kind,is_cover,sort_order) on public.venue_images to anon,authenticated;
grant select (id,venue_id,title,description,cover_image,is_free,ticket_price,starts_at,ends_at,status) on public.events to anon,authenticated;
grant select (id,institute_id,title,description,cover_image,fee_amount,status) on public.courses to anon,authenticated;
grant select (id,city) on public.institutes to anon,authenticated;
grant select (course_id,starts_on,is_active) on public.course_batches to anon,authenticated;
grant select (key,enabled,platforms) on public.feature_flags to anon,authenticated;

revoke all on function public.marketplace_search(text,text,text,text,numeric,numeric,timestamptz,timestamptz,integer,integer,text) from public;
grant execute on function public.marketplace_search(text,text,text,text,numeric,numeric,timestamptz,timestamptz,integer,integer,text) to anon, authenticated;
comment on function public.marketplace_search(text,text,text,text,numeric,numeric,timestamptz,timestamptz,integer,integer,text)
  is 'Published INR marketplace catalog; security invoker preserves source RLS. Date filters select scheduled items only. Prices are discovery values, never checkout quotes.';
