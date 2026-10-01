-- B14: hotel class (1-5 stars) on venues, separate from avg_rating.
alter table public.venues
  add column if not exists star_rating smallint
    check (star_rating between 1 and 5);

create index if not exists idx_venues_star_rating
  on public.venues (star_rating)
  where star_rating is not null;

comment on column public.venues.star_rating is
  'Hotel classification (1-5 stars). Null for non-hotel listings.';
