-- Execute as a local test database owner after the fixture and migration.
-- Every assertion runs against PostgreSQL grants, constraints, and RLS.
begin;
insert into auth.users values
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002'),
    ('00000000-0000-0000-0000-000000000003');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
values (auth.uid(), 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true);

-- Supabase upsert must work with the restricted column grants.
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
values (auth.uid(), 'Alex', 'Teacher', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true)
on conflict (id) do update set
    id = excluded.id, first_name = excluded.first_name, job_title = excluded.job_title,
    goal = excluded.goal, date_of_birth = excluded.date_of_birth,
    city = excluded.city, platonic_agreement = excluded.platonic_agreement;

do $$ begin
    if (select job_title from public.profiles where id = auth.uid()) is distinct from 'Teacher' then
        raise exception 'Owner upsert did not persist';
    end if;
    begin
        update public.profiles set verification_status = 'approved' where id = auth.uid();
        raise exception 'Self approval was allowed';
    exception when insufficient_privilege then null; end;
    begin
        update public.profiles set created_at = now() where id = auth.uid();
        raise exception 'Created timestamp was writable';
    exception when insufficient_privilege then null; end;
    begin
        update public.profiles set id = '00000000-0000-0000-0000-000000000002' where id = auth.uid();
        raise exception 'Ownership transfer was allowed';
    exception when insufficient_privilege then null; end;
    begin
        update public.profiles set date_of_birth = current_date where id = auth.uid();
        raise exception 'Underage update was allowed';
    exception when check_violation then null; end;
    begin
        update public.profiles set platonic_agreement = false where id = auth.uid();
        raise exception 'Missing agreement was allowed';
    exception when check_violation then null; end;
    begin
        update public.profiles set city = 'Phoenix' where id = auth.uid();
        raise exception 'Unsupported city was allowed';
    exception when check_violation then null; end;
    begin
        insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
        values ('00000000-0000-0000-0000-000000000002', 'Sam', 'Teacher', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true);
        raise exception 'Cross-user insert was allowed';
    exception when insufficient_privilege then null; end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare affected integer; begin
    if (select count(*) from public.profiles) <> 0 then
        raise exception 'Another user could read a profile or birthday';
    end if;
    update public.profiles set first_name = 'Intruder' where id = '00000000-0000-0000-0000-000000000001';
    get diagnostics affected = row_count;
    if affected <> 0 then raise exception 'Cross-user update was allowed'; end if;
end $$;

insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
values (auth.uid(), 'Sam', 'Teacher', 'Find a hiking buddy.', ((current_timestamp at time zone 'UTC')::date - interval '18 years')::date, 'Scottsdale', true);

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
    begin
        insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
        values (auth.uid(), 'Sam', 'Teacher', 'Find a hiking buddy.', ((current_timestamp at time zone 'UTC')::date - interval '18 years' + interval '1 day')::date, 'Scottsdale', true);
        raise exception 'Underage insert was allowed';
    exception when check_violation then null; end;
    begin
        insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement, verification_status)
        values (auth.uid(), 'Sam', 'Teacher', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true, 'approved');
        raise exception 'Self approval on insert was allowed';
    exception when insufficient_privilege then null; end;
end $$;

set local role anon;
do $$ begin
    begin
        perform * from public.profiles;
        raise exception 'Anonymous profile read was allowed';
    exception when insufficient_privilege then null; end;
end $$;
-- Auth account deletion cascades to only that account's private profile.
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-000000000001';
do $$ begin
    if exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000001') then
        raise exception 'Deleted account profile remains';
    end if;
    if not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000002') then
        raise exception 'Another account profile was deleted';
    end if;
end $$;

-- Even a still-unexpired JWT cannot recreate a profile for a deleted Auth user.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
    begin
        insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
        values (auth.uid(), 'Alex', 'Teacher', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true);
        raise exception 'Deleted account recreated its profile';
    exception when foreign_key_violation then null; end;
end $$;
rollback;
