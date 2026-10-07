begin;
insert into auth.users values
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01'::date, 'Scottsdale', true from auth.users
where id in ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');

-- Bucket upload restrictions are enforced by the Storage service, not these RLS tests.
do $$ begin
    if not exists (select 1 from storage.buckets where id = 'private-photos' and not public
        and file_size_limit = 3145728 and allowed_mime_types = array['image/jpeg']) then
        raise exception 'Private bucket configuration is incorrect';
    end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile.jpg');
        raise exception 'Upload without consent was allowed';
    exception when insufficient_privilege then null; end;
    begin
        insert into public.photo_consents (user_id, version) values ('00000000-0000-0000-0000-000000000002', 'pilot-v1');
        raise exception 'Consent for another user was allowed';
    exception when insufficient_privilege then null; end;
end $$;
insert into public.photo_consents (user_id, version) values (auth.uid(), 'pilot-v1');
-- Idempotent acceptance must not overwrite the server timestamp.
insert into public.photo_consents (user_id, version) values (auth.uid(), 'pilot-v1') on conflict do nothing;
insert into storage.objects (bucket_id, name) values
    ('private-photos', auth.uid()::text || '/profile.jpg'),
    ('private-photos', auth.uid()::text || '/selfie.jpg');
do $$ begin
    if (select count(*) from storage.objects) <> 2 then raise exception 'Owner cannot read both photos'; end if;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/other.jpg');
        raise exception 'Arbitrary photo path was allowed';
    exception when insufficient_privilege then null; end;
    begin
        update public.photo_consents set accepted_at = now() where user_id = auth.uid();
        raise exception 'Consent timestamp was writable';
    exception when insufficient_privilege then null; end;
    begin
        update storage.objects set name = '00000000-0000-0000-0000-000000000002/profile.jpg'
        where name = auth.uid()::text || '/profile.jpg';
        raise exception 'Photo ownership transfer was allowed';
    exception when insufficient_privilege then null; end;
end $$;
update storage.objects set name = name where bucket_id = 'private-photos';

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare affected integer; begin
    if (select count(*) from storage.objects) <> 0 then raise exception 'Another user can see photos'; end if;
    if (select count(*) from public.photo_consents) <> 0 then raise exception 'Another user can see consent'; end if;
    delete from storage.objects;
    get diagnostics affected = row_count;
    if affected <> 0 then raise exception 'Another user can delete photos'; end if;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', '00000000-0000-0000-0000-000000000001/other.jpg');
        raise exception 'Another user can upload to owner prefix';
    exception when insufficient_privilege then null; end;
end $$;

set local role anon;
do $$ begin
    begin
        if exists (select 1 from storage.objects) then raise exception 'Anonymous photos are visible'; end if;
    exception when insufficient_privilege then null; end;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
delete from storage.objects;
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-000000000001';
set local role authenticated;
do $$ begin
    if exists (select 1 from public.photo_consents) then raise exception 'Deleted account consent remains'; end if;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile.jpg');
        raise exception 'Deleted identity can upload photos';
    exception when insufficient_privilege then null; end;
end $$;
rollback;
