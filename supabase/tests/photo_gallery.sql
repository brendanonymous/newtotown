begin;
insert into auth.users values
    ('00000000-0000-0000-0000-000000000071'),
    ('00000000-0000-0000-0000-000000000072');
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find friends.', '1990-01-01'::date, 'Scottsdale', true
from auth.users where id in ('00000000-0000-0000-0000-000000000071', '00000000-0000-0000-0000-000000000072');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000071';
insert into public.photo_consents (user_id, version) values (auth.uid(), 'pilot-v1');
insert into storage.objects (bucket_id, name) values
    ('private-photos', auth.uid()::text || '/profile.jpg'),
    ('private-photos', auth.uid()::text || '/profile-2.jpg'),
    ('private-photos', auth.uid()::text || '/profile-3.jpg'),
    ('private-photos', auth.uid()::text || '/selfie.jpg');
do $$ begin
    if (select count(*) from storage.objects) <> 4 then raise exception 'Owner gallery incomplete'; end if;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile-4.jpg');
        raise exception 'Fourth public photo allowed';
    exception when insufficient_privilege then null; end;
    begin
        perform public.pilot_profile_photo_paths(array[auth.uid()]);
        raise exception 'Client can invoke service-only metadata lookup';
    exception when insufficient_privilege then null; end;
    begin
        update storage.objects set name = '00000000-0000-0000-0000-000000000072/profile-2.jpg'
        where name = auth.uid()::text || '/profile-2.jpg';
        raise exception 'Ownership transfer allowed';
    exception when insufficient_privilege then null; end;
end $$;
update storage.objects set name = name where name like '%/profile-%.jpg';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000072';
do $$ begin
    if exists (select 1 from storage.objects) then raise exception 'Other owner can read gallery'; end if;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile-2.jpg');
        raise exception 'Additional photo uploaded without consent';
    exception when insufficient_privilege then null; end;
end $$;
set local role service_role;
update public.pilot_features set photo_review_required = false;
do $$ declare paths text[]; begin
    select array_agg(path) into paths from public.pilot_profile_photo_paths(array['00000000-0000-0000-0000-000000000071'::uuid]) path;
    if paths <> array[
        '00000000-0000-0000-0000-000000000071/profile.jpg',
        '00000000-0000-0000-0000-000000000071/profile-2.jpg',
        '00000000-0000-0000-0000-000000000071/profile-3.jpg'] then
        raise exception 'Wrong public gallery paths: %', paths;
    end if;
end $$;
update public.pilot_features set photo_review_required = true;
do $$ declare paths text[]; begin
    select array_agg(path) into paths from public.pilot_profile_photo_paths(array['00000000-0000-0000-0000-000000000071'::uuid]) path;
    if paths <> array['00000000-0000-0000-0000-000000000071/profile.jpg'] then
        raise exception 'Unreviewed additional photos exposed';
    end if;
end $$;
rollback;
