-- BookMySpace dev DB: give each dev-seed course its own distinct cover
-- image. Right now all 10 "DEV Course 01".."DEV Course 10" rows (the ones
-- that show up in Home's "Courses" row) share the exact same Unsplash
-- photo, so that row repeats one picture across every card -- the same
-- issue the venues had. The 2 real courses (Flutter App Development
-- Bootcamp, UI/UX Design Essentials) already have their own distinct
-- images and are left untouched.
--
-- Run this in the Supabase SQL editor for project bookmyspace-dev
-- (zykxneztahxbjduagutv). Every URL was checked to return real image
-- content (not a 404) before being included here.

update courses set cover_image = 'https://images.unsplash.com/photo-1516321497487-e288fb19713f' where title = 'DEV Course 01' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f' where title = 'DEV Course 02' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1543269865-cbf427effbad'   where title = 'DEV Course 03' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1509062522246-3755977927d7' where title = 'DEV Course 04' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1571260899304-425eee4c7efc' where title = 'DEV Course 05' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1610484826967-09c5720778c7' where title = 'DEV Course 06' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1523240795612-9a054b0db644' where title = 'DEV Course 07' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d'   where title = 'DEV Course 08' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1588072432836-e10032774350' where title = 'DEV Course 09' and status = 'published';
update courses set cover_image = 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b' where title = 'DEV Course 10' and status = 'published';

-- Sanity check afterward -- should show 0 rows (no two courses sharing a photo):
-- select cover_image, count(*) from courses where status = 'published' group by cover_image having count(*) > 1;
