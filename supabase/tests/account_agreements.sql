begin;
insert into auth.users (id) values
    ('00000000-0000-0000-0000-000000000031'),
    ('00000000-0000-0000-0000-000000000032');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000031';
-- Acceptance happens after authentication, before profile creation.
insert into public.account_agreements (user_id, version) values (auth.uid(), 'onboarding-v1');
insert into public.account_agreements (user_id, version) values (auth.uid(), 'onboarding-v1') on conflict do nothing;
do $$ begin
    if (select count(*) from public.account_agreements) <> 1 then raise exception 'Receipt retry duplicated acceptance'; end if;
    begin
        insert into public.account_agreements (user_id, version) values ('00000000-0000-0000-0000-000000000032', 'onboarding-v1');
        raise exception 'Acceptance for another account was allowed';
    exception when insufficient_privilege then null; end;
    begin
        update public.account_agreements set accepted_at = now();
        raise exception 'Receipt timestamp was mutable';
    exception when insufficient_privilege then null; end;
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile.jpg');
        raise exception 'Photos without a profile were allowed';
    exception when insufficient_privilege then null; end;
end $$;
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
values (auth.uid(), 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true);
-- The new receipt alone permits upload and replacement; no photo-screen acceptance.
insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile.jpg');
update storage.objects set updated_at = clock_timestamp() where name = auth.uid()::text || '/profile.jpg';
do $$ begin
    if exists (select 1 from public.photo_consents) then raise exception 'New signup fabricated legacy photo consent'; end if;
    if (select count(*) from storage.objects) <> 1 then raise exception 'Owner photo was inaccessible'; end if;
    begin
        update storage.objects set name = '00000000-0000-0000-0000-000000000032/profile.jpg';
        raise exception 'Photo ownership transfer was allowed';
    exception when insufficient_privilege then null; end;
    begin
        delete from public.account_agreements;
        raise exception 'Receipt deletion was allowed';
    exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000032';
do $$ begin
    if exists (select 1 from public.account_agreements) then raise exception 'Another account can read acceptance'; end if;
end $$;
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
values (auth.uid(), 'Sam', 'Teacher', 'Find a climbing buddy.', '1990-01-01', 'Scottsdale', true);
do $$ begin
    begin
        insert into storage.objects (bucket_id, name) values ('private-photos', auth.uid()::text || '/profile.jpg');
        raise exception 'Upload without any acceptance was allowed';
    exception when insufficient_privilege then null; end;
    begin
        insert into public.account_agreements (user_id, version) values (auth.uid(), 'unknown');
        raise exception 'Unknown agreement version was allowed';
    exception when check_violation then null; end;
end $$;
insert into public.account_agreements (user_id, version) values (auth.uid(), 'onboarding-v1');
set local role anon;
do $$ begin
    begin
        perform * from public.account_agreements;
        raise exception 'Anonymous receipt access was allowed';
    exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Deletion clears receipts, even for accounts that never finished their profile.
delete from auth.users where id = '00000000-0000-0000-0000-000000000032';
do $$ begin
    if exists (select 1 from public.account_agreements where user_id = '00000000-0000-0000-0000-000000000032') then
        raise exception 'Deleted account left agreement receipt';
    end if;
end $$;
rollback;
