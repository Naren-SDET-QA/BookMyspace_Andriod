-- BookMySpace dev DB: give every venue category a distinct, verified cover
-- image so no two categories show the same stock photo anywhere in the app
-- (Home Featured Spotlight, venue cards, institute/venue lists, etc).
--
-- Run this in the Supabase SQL editor for project bookmyspace-dev
-- (zykxneztahxbjduagutv). Every URL below was checked to return real image
-- content (not a 404) before being included here. Swap any URL for a
-- different one at any time -- it's just a text column.
--
-- Scope: only the "real" seed categories (10 or 20 rows each). Deliberately
-- left untouched: E2E-* fixture venues, "BookMySpace E2E Test Venue",
-- "DEV Data Driven Hall 11", "Sunrise Function Hall", "The Boardroom",
-- "The Work Nest" -- these are test fixtures other tests may depend on by
-- exact image count/URL, so they're out of scope for a visual-only change.

with mapping(base_name, cover_url) as (
  values
    ('Auditorium',            'https://images.unsplash.com/photo-1517457373958-b7bdd4587205'),
    ('Community Hall',        'https://images.unsplash.com/photo-1497366216548-37526070297c'),
    ('Convention Center',     'https://images.unsplash.com/photo-1517502884422-41eaead166d4'),
    ('Coworking Space',       'https://images.unsplash.com/photo-1497366811353-6870744d04b2'),
    ('Function Hall',         'https://images.unsplash.com/photo-1519750783826-e2420f4d687f'),
    ('Institute',             'https://images.unsplash.com/photo-1505409859467-3a796fd5798e'),
    ('Marriage Hall',         'https://images.unsplash.com/photo-1519167758481-83f550bb49b3'),
    ('Meeting Room',          'https://images.unsplash.com/photo-1524178232363-1fb2b075b655'),
    ('Party Hall',            'https://images.unsplash.com/photo-1414235077428-338989a2e8c0'),
    ('Sports Ground',         'https://images.unsplash.com/photo-1587825140708-dfaf72ae4b04'),
    ('Co-living Spaces',      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267'),
    ('Coaching & Tuition',    'https://images.unsplash.com/photo-1503676260728-1c00da094a0b'),
    ('Computer & IT Classes', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3'),
    ('Dance Academy',         'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad'),
    ('Exhibition Hall',       'https://images.unsplash.com/photo-1540518614846-7eded433c457'),
    ('Gents PG',              'https://images.unsplash.com/photo-1554995207-c18c203602cb'),
    ('Government Hall',       'https://images.unsplash.com/photo-1590490360182-c33d57733427'),
    ('Guest House',           'https://images.unsplash.com/photo-1566073771259-6a8506099945'),
    ('Homestay',              'https://images.unsplash.com/photo-1445019980597-93fa8acb246c'),
    ('Hostel',                'https://images.unsplash.com/photo-1631049307264-da0ec9d70304'),
    ('Hotel',                 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461'),
    ('Hotel / Stay',          'https://images.unsplash.com/photo-1466442929976-97f336a657be'),
    ('Hourly / Day Room',     'https://images.unsplash.com/photo-1519874179391-3ebc752241dd'),
    ('Ladies PG',             'https://images.unsplash.com/photo-1584132967334-10e028bd69f7'),
    ('Lodge',                 'https://images.unsplash.com/photo-1517322048670-4fba75cbbb62'),
    ('Music & Singing',       'https://images.unsplash.com/photo-1601918774946-25832a4be0d6'),
    ('Open Lawn Ground',      'https://images.unsplash.com/photo-1533090161767-e6ffed986c88'),
    ('Party Hall / Banquet',  'https://images.unsplash.com/photo-1545389336-cf090694435e'),
    ('PG / Co-Living',        'https://images.unsplash.com/photo-1512917774080-9991f1c4c750'),
    ('PG / Hostel',           'https://images.unsplash.com/photo-1478147427282-58a87a120781'),
    ('Resort / Homestay',     'https://images.unsplash.com/photo-1519677100203-a0e668c92439'),
    ('Sports Academy & Turfs','https://images.unsplash.com/photo-1461988320302-91bde64fc8e4'),
    ('Student Hostel',        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2'),
    ('Temple',                'https://images.unsplash.com/photo-1571624436279-b272aff752b5')
)
update venue_images vi
set url = m.cover_url,
    thumbnail_url = m.cover_url
from venues v
join mapping m on m.base_name = regexp_replace(v.name, ' DEV [0-9]+$', '')
where vi.venue_id = v.id
  and vi.is_cover = true;

-- Sanity check afterward -- should show 0 categories still sharing a photo:
-- select cover_url, count(distinct base_name) as categories_sharing_it
-- from (
--   select regexp_replace(v.name, ' DEV [0-9]+$', '') as base_name, vi.url as cover_url
--   from venues v join venue_images vi on vi.venue_id = v.id and vi.is_cover
-- ) x
-- group by cover_url having count(distinct base_name) > 1;
