-- Transaction-only policy/eligibility tests. No files are uploaded.
begin;
insert into auth.users (id) values
    ('00000000-0000-0000-0000-000000000011'),
    ('00000000-0000-0000-0000-000000000012');
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01'::date, 'Scottsdale', true
from auth.users where id in ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000012');
insert into public.photo_consents (user_id, version)
values ('00000000-0000-0000-0000-000000000011', 'pilot-v1');
update public.pilot_features set photo_review_required = false;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000011';
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Photo-less profile is eligible'; end if;
    begin
        update public.pilot_features set photo_review_required = true;
        raise exception 'Client changed feature flag';
    exception when insufficient_privilege then null; end;
    begin
        insert into public.profile_access (user_id, suspended) values (auth.uid(), false);
        raise exception 'Client wrote moderation state';
    exception when insufficient_privilege then null; end;
end $$;
insert into storage.objects (bucket_id, name, updated_at)
values ('private-photos', auth.uid()::text || '/profile.jpg', now() - interval '1 minute');
do $$ begin
    if not public.is_own_profile_discoverable() then raise exception 'Pilot requires selfie'; end if;
end $$;
reset role;
update public.pilot_features set photo_review_required = true;
set local role authenticated;
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Enabled review allows unapproved profile'; end if;
end $$;
insert into storage.objects (bucket_id, name, updated_at)
values ('private-photos', auth.uid()::text || '/selfie.jpg', now() - interval '1 minute');
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Selfie alone counted as approval'; end if;
end $$;
reset role;
-- Simulate a trusted reviewer recording both exact versions. No client has this grant.
insert into public.profile_access (user_id, approved_profile_id, approved_profile_updated_at,
    approved_selfie_id, approved_selfie_updated_at)
select '00000000-0000-0000-0000-000000000011', profile.id, profile.updated_at, selfie.id, selfie.updated_at
from storage.objects profile cross join storage.objects selfie
where profile.name = '00000000-0000-0000-0000-000000000011/profile.jpg'
    and selfie.name = '00000000-0000-0000-0000-000000000011/selfie.jpg';
set local role authenticated;
do $$ begin
    if not public.is_own_profile_discoverable() then raise exception 'Approved versions are ineligible'; end if;
    begin
        update public.profile_access set suspended = false;
        raise exception 'Client changed moderation state';
    exception when insufficient_privilege then null; end;
end $$;
-- Seeded timestamps predate this transaction so hosted Storage’s now() trigger
-- can represent a later replacement even in this rollback-only test.
update storage.objects set updated_at = updated_at + interval '1 second'
where name = auth.uid()::text || '/profile.jpg';
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Changed photo retained approval'; end if;
end $$;
reset role;
update public.profile_access set approved_profile_updated_at = (
    select updated_at from storage.objects
    where name = '00000000-0000-0000-0000-000000000011/profile.jpg'
);
set local role authenticated;
update storage.objects set updated_at = updated_at + interval '1 second'
where name = auth.uid()::text || '/selfie.jpg';
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Changed selfie retained approval'; end if;
end $$;
reset role;
update public.profile_access set approved_selfie_updated_at = (
    select updated_at from storage.objects
    where name = '00000000-0000-0000-0000-000000000011/selfie.jpg'
);
-- A recreated Storage object cannot reuse approval even if the timestamp matches.
update storage.objects set id = gen_random_uuid()
where name = '00000000-0000-0000-0000-000000000011/profile.jpg';
set local role authenticated;
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Recreated photo retained approval'; end if;
end $$;
reset role;
update public.pilot_features set photo_review_required = false;
update public.profile_access set suspended = true;
set local role authenticated;
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Flag bypasses suspension'; end if;
end $$;
reset role;
update public.profile_access set suspended = false, rejected = true;
set local role authenticated;
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Flag bypasses rejection'; end if;
end $$;
reset role;
update public.profile_access set rejected = false;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000012';
do $$ begin
    if exists (select 1 from public.profile_access) then raise exception 'Other moderation row exposed'; end if;
    if exists (select 1 from storage.objects) then raise exception 'Other photos exposed'; end if;
    if public.is_own_profile_discoverable() then raise exception 'Other user inherited eligibility'; end if;
end $$;
reset role;
-- Missing configuration must never make anyone eligible.
delete from public.pilot_features;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000011';
do $$ begin
    if public.is_own_profile_discoverable() then raise exception 'Missing flag failed open'; end if;
end $$;
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-000000000011';
set local role authenticated;
do $$ begin
    if exists (select 1 from public.profile_access) then raise exception 'Deleted user retains access row'; end if;
    if public.is_own_profile_discoverable() then raise exception 'Deleted user eligible'; end if;
end $$;
set local role anon;
do $$ begin
    begin
        perform public.is_own_profile_discoverable();
        raise exception 'Anonymous caller has eligibility access';
    exception when insufficient_privilege then null; end;
    begin
        perform 1 from public.pilot_features;
        raise exception 'Anonymous caller has feature access';
    exception when insufficient_privilege then null; end;
end $$;
rollback;
