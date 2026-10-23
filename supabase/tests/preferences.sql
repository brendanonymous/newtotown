begin;
insert into auth.users(id) values ('30000000-0000-0000-0000-000000000001'), ('30000000-0000-0000-0000-000000000002'), ('30000000-0000-0000-0000-000000000003');
insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a coffee buddy.', ((current_timestamp at time zone 'UTC')::date - interval '30 years')::date, 'Scottsdale', true
from auth.users where id::text like '30000000-%';
insert into storage.objects(bucket_id, name)
select 'private-photos', id::text || '/profile.jpg' from public.profiles where id::text like '30000000-%';
update public.pilot_features set photo_review_required = false;
set local role service_role;
do $$
declare a uuid := '30000000-0000-0000-0000-000000000001'; b uuid := '30000000-0000-0000-0000-000000000002'; c uuid := '30000000-0000-0000-0000-000000000003'; thread uuid; bounds jsonb;
begin
    if public.pilot_discovery_preferences(a) <> '{"minimum_age":18,"maximum_age":null}'::jsonb then raise exception 'Wrong defaults'; end if;
    perform public.pilot_discovery_save_preferences(a, 30, 30);
    if (select visible from public.discovery_settings where user_id = a) then raise exception 'Preferences opted into discovery'; end if;
    if public.pilot_discovery_preferences(b) <> '{"minimum_age":18,"maximum_age":null}'::jsonb then raise exception 'Preferences affected peer'; end if;
    perform public.pilot_discovery_visibility(a, true); perform public.pilot_discovery_visibility(b, true); perform public.pilot_discovery_visibility(c, true);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 2 then raise exception 'Age bounds excluded exact birthday'; end if;
    perform public.pilot_discovery_decide(a, b, 'connect'); perform public.pilot_discovery_decide(b, a, 'connect');
    thread := (public.pilot_messaging_open(a,b)->>'id')::uuid;
    perform public.pilot_discovery_save_preferences(a, 40, 50);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 then raise exception 'Outside ages appeared'; end if;
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 1 then raise exception 'Preference removed existing connection'; end if;
    perform public.pilot_messaging_send(a,thread,gen_random_uuid(),'Still connected');
    if jsonb_array_length(public.pilot_messaging_list(b)->'conversations') <> 1 then raise exception 'Preference revoked messaging'; end if;
    perform public.pilot_discovery_save_preferences(a,18,null);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 1 then raise exception 'Reset range lost candidate'; end if;
    foreach bounds in array array['[17,null]'::jsonb, '[30,29]'::jsonb, '[null,50]'::jsonb] loop
        begin
            perform public.pilot_discovery_save_preferences(a,(bounds->>0)::integer,(bounds->>1)::integer);
            raise exception 'Invalid range accepted';
        exception when invalid_parameter_value then null; end;
    end loop;
end $$;
reset role;
-- Birthday boundaries: eligibility changes at the birthday, using UTC calendar dates.
update public.profiles set date_of_birth = (((current_timestamp at time zone 'UTC')::date - interval '30 years')::date + 1)
where id = '30000000-0000-0000-0000-000000000003';
set local role service_role;
do $$ begin
    perform public.pilot_discovery_save_preferences('30000000-0000-0000-0000-000000000001',30,30);
    if private.discovery_age_allowed('30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003') then raise exception 'Tomorrow birthday included early'; end if;
end $$;
reset role;
-- Filtering happens before the twenty-card limit, even with many older out-of-range rows.
insert into auth.users(id)
select ('40000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid from generate_series(1,31) i;
insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement,created_at)
select id,'Alex','Designer','Find a coffee buddy.',
    ((current_timestamp at time zone 'UTC')::date - case when right(id::text,2)='31' then interval '30 years' else interval '20 years' end)::date,
    'Scottsdale',true,now() - interval '1 day'
from auth.users where id::text like '40000000-%';
insert into storage.objects(bucket_id,name)
select 'private-photos',id::text || '/profile.jpg' from public.profiles where id::text like '40000000-%';
insert into public.discovery_settings(user_id,visible)
select id,true from public.profiles where id::text like '40000000-%';
set local role service_role;
do $$ declare feed jsonb; begin
    feed := public.pilot_discovery_feed('30000000-0000-0000-0000-000000000001');
    if jsonb_array_length(feed->'candidates') <> 1 or feed->'candidates'->0->>'id' <> '40000000-0000-0000-0000-000000000031' then
        raise exception 'Age filtering ran after card limit'; end if;
end $$;
reset role;
set local role authenticated;
set local request.jwt.claim.sub = '30000000-0000-0000-0000-000000000002';
do $$ begin
    if exists(select 1 from public.discovery_settings where user_id <> auth.uid()) then raise exception 'Preferences readable across owners'; end if;
    begin perform public.pilot_discovery_save_preferences('30000000-0000-0000-0000-000000000001',18,null);
        raise exception 'Client impersonation permitted'; exception when insufficient_privilege then null; end;
    begin update public.discovery_settings set minimum_age=99;
        raise exception 'Direct preference write permitted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
    if not (select relrowsecurity from pg_class where oid='public.discovery_settings'::regclass) then raise exception 'Missing RLS'; end if;
    if has_function_privilege('anon','public.pilot_discovery_preferences(uuid)','EXECUTE')
        or has_function_privilege('authenticated','public.pilot_discovery_preferences(uuid)','EXECUTE')
        or has_function_privilege('anon','public.pilot_discovery_save_preferences(uuid,integer,integer)','EXECUTE') then raise exception 'Client RPC access'; end if;
end $$;
rollback;
