-- The platform-admin write guard expects course_faculty.updated_at.
do $$
declare
  column_record record;
begin
  select is_nullable, column_default
    into column_record
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'course_faculty'
     and column_name = 'updated_at';

  if not found then
    raise exception 'course_faculty.updated_at is missing';
  end if;
  if column_record.is_nullable <> 'NO' then
    raise exception 'course_faculty.updated_at must be NOT NULL';
  end if;
  if column_record.column_default is null then
    raise exception 'course_faculty.updated_at must default to now()';
  end if;
  if not (
    select relrowsecurity
      from pg_class
     where oid = 'public.course_faculty'::regclass
  ) then
    raise exception 'course_faculty RLS must remain enabled';
  end if;
end
$$;
