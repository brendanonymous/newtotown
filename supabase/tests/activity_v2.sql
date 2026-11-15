-- Behavior and privileges against the disposable auth_fixture database.
begin;
do $$ begin
    if (select count(*) from private.looking_for_categories) <> 12
        or (select count(*) from private.activity_interests) <> 557
        or (select count(*) from private.activity_interests where published) <> 507
        or (select count(*) from private.activity_interests where age_restricted and not published) <> 50
        or (select count(*) from private.interest_looking_for_links) <> 595
    then raise exception 'Canonical catalog counts changed'; end if;
    if not exists(select 1 from private.activity_interests where id='board_games' and published)
        or not exists(select 1 from private.activity_interests where id='3d_printing' and published)
        or not exists(select 1 from private.activity_interests where id='3d_modeling' and published)
    then raise exception 'Required canonical interests missing'; end if;
    if exists(select 1 from public.pilot_features where activity_profiles_v2_enabled or activity_ranking_v2_enabled) then
        raise exception 'Capabilities enabled before rollout'; end if;
end $$;

-- Full row fingerprints derived from the approved canonical JSON, including labels and placement order.
do $$ begin
    if (select md5(string_agg(concat_ws(chr(31),id,title,description,sort_order::text),chr(10) order by sort_order)) from private.looking_for_categories) <> '9fa3648f9705a805d1bc3447c2c176f3' then
        raise exception 'Canonical looking_for_categories data changed'; end if;
    if (select md5(string_agg(concat_ws(chr(31),id,title,age_restricted::text,published::text,sort_order::text),chr(10) order by sort_order)) from private.activity_interests) <> '23a7e6e22d68c378ce2fede654ff580f' then
        raise exception 'Canonical activity_interests data changed'; end if;
    if (select md5(string_agg(concat_ws(chr(31),interest_id,category_id,group_title,group_order::text,sort_order::text),chr(10) order by category_id,sort_order)) from private.interest_looking_for_links) <> '7723640550ecc56d43232b390e7518d8' then
        raise exception 'Canonical interest_looking_for_links data changed'; end if;
end $$;

insert into auth.users(id) values
    ('70000000-0000-0000-0000-000000000001'), -- legacy profile/filter
    ('70000000-0000-0000-0000-000000000002'), -- new setup
    ('70000000-0000-0000-0000-000000000003'), -- no agreement
    ('70000000-0000-0000-0000-000000000004'); -- existing implicit age range
insert into public.profiles(id,first_name,job_title,goal,date_of_birth,platonic_agreement)
    select id,'Sam','Designer','Find a coffee buddy.',current_date-interval '30 years',true from auth.users
    where id in ('70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000004');
insert into public.account_agreements(user_id,version) values ('70000000-0000-0000-0000-000000000002','onboarding-v1');
insert into storage.objects(bucket_id,name) values
    ('private-photos','70000000-0000-0000-0000-000000000001/profile.jpg');
set local role service_role;
select public.pilot_interests_save('70000000-0000-0000-0000-000000000001','profile',array['golf','coffee','craft_beer','chess','professional_networking']);
select public.pilot_interests_save('70000000-0000-0000-0000-000000000001','filters',array['golf','coffee']);
select public.pilot_discovery_save_preferences('70000000-0000-0000-0000-000000000001',40,55);

do $$
declare a uuid := '70000000-0000-0000-0000-000000000001'; b uuid := '70000000-0000-0000-0000-000000000002';
    d uuid := '70000000-0000-0000-0000-000000000004'; result jsonb; ids text[]; before_state jsonb;
begin
    result := public.activity_v2_owner(a);
    if result->'interest_ids' <> '["golf","chess"]'::jsonb
        or result->'filter_ids' <> '["golf"]'::jsonb
        or result->'setup'->>'filters_need_review' <> 'true'
        or result->'category_ids' <> '[]'::jsonb or result->'priority_ids' <> '[]'::jsonb
        or result->'setup'->>'entry_kind' <> 'existing'
        or result->'setup'->>'basics_complete' <> 'true' or result->'setup'->>'photos_complete' <> 'true'
    then raise exception 'Legacy import mismatch: %',result; end if;
    if jsonb_array_length(result->'unavailable_legacy_interest_ids') <> 3 then raise exception 'Unavailable choices not preserved'; end if;
    if (select count(*) from private.profile_interest_selections where user_id=a) <> 5 then raise exception 'Legacy rows lost'; end if;
    -- Import happens once: old-client changes cannot replace or truncate v2 sets.
    perform public.pilot_interests_save(a,'profile',array['hiking']);
    if public.activity_v2_owner(a)->'interest_ids' <> result->'interest_ids' then raise exception 'Legacy overwrite'; end if;
    if jsonb_array_length(public.pilot_interests(a)->'categories') <> 5 then raise exception 'Legacy contract changed'; end if;
    result := public.activity_v2_save_filters(a,0,array[]::text[]);
    if result->'setup'->>'filters_need_review' <> 'false' then raise exception 'Reviewed empty filter rejected'; end if;
    if public.activity_v2_owner(d)->'setup'->>'entry_kind' <> 'existing' or exists(select 1 from public.discovery_settings where user_id=d) then
        raise exception 'Existing implicit age preferences changed'; end if;
    perform public.activity_v2_save_basics(a,1,'Sam','Engineer','Meet people for weekend hikes.',(current_date-interval '32 years')::date);
    if (select minimum_age<>40 or maximum_age<>55 from public.discovery_settings where user_id=a) then raise exception 'Existing range reset'; end if;
    result := public.activity_v2_owner(b);
    if result->'setup'->>'entry_kind' <> 'new' or result->'setup'->>'basics_complete' <> 'false' then raise exception 'New setup state wrong'; end if;
    begin perform public.activity_v2_owner('70000000-0000-0000-0000-000000000003'); raise exception 'Missing agreement accepted';
        exception when raise_exception then if sqlerrm <> 'Agreement required' then raise; end if; end;
    begin perform public.activity_v2_complete_photos(b,0); raise exception 'Missing photo accepted'; exception when invalid_parameter_value then null; end;
    result := public.activity_v2_save_basics(b,0,'Alex','Designer','Meet people for weekend hikes.',(current_date-interval '20 years')::date);
    if (select minimum_age<>18 or maximum_age<>32 or visible from public.discovery_settings where user_id=b) then raise exception 'New age defaults wrong'; end if;
    perform public.activity_v2_save_basics(b,1,'Alex','Designer','Meet people for weekend hikes.',(current_date-interval '21 years')::date);
    if (select maximum_age<>32 from public.discovery_settings where user_id=b) then raise exception 'Birthday reset range'; end if;
    begin perform public.activity_v2_save_basics(b,2,'Alex','Designer','Meet people for weekend hikes.',(current_date-interval '17 years')::date); raise exception 'Minor accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_interests(b,2,array[]::text[],true); raise exception 'Early completion accepted'; exception when invalid_parameter_value then null; end;
    -- Priority array is authoritative: retaining only former rank 2 promotes it to 1.
    perform public.activity_v2_save_looking_for(b,2,array['gym','sports'],array['sports','gym']);
    result := public.activity_v2_save_looking_for(b,3,array['gym'],array['gym']);
    if result->'priority_ids' <> '["gym"]'::jsonb or (select priority_rank from private.profile_looking_for where user_id=b) <> 1 then raise exception 'Priority not promoted'; end if;
    before_state := result;
    begin perform public.activity_v2_save_looking_for(b,3,array['hobby'],array[]::text[]); raise exception 'Stale save accepted'; exception when serialization_failure then null; end;
    begin perform public.activity_v2_save_looking_for(b,4,array[]::text[],array[]::text[]); raise exception 'Empty Looking For accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_looking_for(b,4,array['gym','gym'],array[]::text[]); raise exception 'Duplicate category accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_looking_for(b,4,array['gym'],array['sports']); raise exception 'Non-subset priority accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_looking_for(b,4,array['gym','sports','hobby','events','weekend','outdoor'],array[]::text[]); raise exception 'Six choices accepted'; exception when invalid_parameter_value then null; end;
    if public.activity_v2_owner(b) <> before_state then raise exception 'Rejected save changed state'; end if;
    -- All 507 available interests, including digit-leading IDs; no count/per-category cap.
    select array_agg(id order by sort_order) into ids from private.activity_interests where published;
    result := public.activity_v2_save_interests(b,4,ids,false);
    if jsonb_array_length(result->'interest_ids') <> 507 then raise exception 'Catalog selections truncated'; end if;
    perform public.activity_v2_save_filters(b,5,array['3d_printing']);
    if jsonb_array_length(public.activity_v2_owner(b)->'interest_ids') <> 507 then raise exception 'Filter overwrote interests'; end if;
    begin perform public.activity_v2_save_interests(b,6,array['craft_beer'],false); raise exception 'Hidden interest accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_interests(b,6,array['golf','golf'],false); raise exception 'Duplicate interest accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_interests(b,6,array['unknown'],false); raise exception 'Unknown interest accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.activity_v2_save_filters(b,6,array[null]::text[]); raise exception 'Null filter accepted'; exception when invalid_parameter_value then null; end;
    if (select selection_revision from private.profile_setup_progress where user_id=b) <> 6 then raise exception 'Failed request advanced revision'; end if;
end $$;
reset role;
insert into storage.objects(bucket_id,name) values ('private-photos','70000000-0000-0000-0000-000000000002/selfie.jpg');
set local role service_role;
do $$ begin
    begin perform public.activity_v2_complete_photos('70000000-0000-0000-0000-000000000002',6); raise exception 'Selfie counted as public photo'; exception when invalid_parameter_value then null; end;
end $$;
reset role;
insert into storage.objects(bucket_id,name) values ('private-photos','70000000-0000-0000-0000-000000000002/profile-2.jpg');
set local role service_role;
select public.activity_v2_complete_photos('70000000-0000-0000-0000-000000000002',6);
select public.activity_v2_save_interests('70000000-0000-0000-0000-000000000002',7,array[]::text[],true);
reset role;
delete from storage.objects where name='70000000-0000-0000-0000-000000000002/profile-2.jpg';
do $$ declare result jsonb; begin
    result := public.activity_v2_owner('70000000-0000-0000-0000-000000000002');
    if result->'setup'->>'completed_at' is null or result->'has_photo' <> 'false'::jsonb then raise exception 'Photo removal restarted onboarding'; end if;
end $$;
-- Retired filters require review; public output omits the newly hidden selection.
update private.activity_interests set published=false where id='golf';
set local role service_role;
do $$ declare result jsonb; begin
    perform public.activity_v2_save_filters('70000000-0000-0000-0000-000000000001',2,array['chess']);
end $$;
reset role;
update private.activity_interests set published=false where id='chess';
set local role service_role;
do $$ declare result jsonb; begin
    result := public.activity_v2_owner('70000000-0000-0000-0000-000000000001');
    if result->'setup'->>'filters_need_review' <> 'true' or result->'filter_ids' <> '[]'::jsonb then raise exception 'Retired filter silently broadened'; end if;
end $$;
reset role;

-- Deferred constraints also protect privileged maintenance writes.
do $$ begin
    begin
        insert into private.profile_looking_for(user_id,category_id) select '70000000-0000-0000-0000-000000000004',id from private.looking_for_categories limit 6;
        set constraints private.activity_looking_for_invariants immediate;
        raise exception 'Six direct choices accepted';
    exception when check_violation then null; end;
    begin
        insert into private.profile_looking_for values ('70000000-0000-0000-0000-000000000004','gym',2);
        set constraints private.activity_looking_for_invariants immediate;
        raise exception 'Priority gap accepted';
    exception when check_violation then null; end;
    begin insert into private.profile_activity_interests values ('70000000-0000-0000-0000-000000000004','craft_beer'); raise exception 'Privileged hidden insert accepted'; exception when invalid_parameter_value then null; end;
end $$;

do $$ begin
    begin
        delete from private.profile_looking_for where user_id='70000000-0000-0000-0000-000000000002';
        set constraints private.activity_looking_for_invariants immediate;
        raise exception 'Completed profile lost last Looking For category';
    exception when check_violation then null; end;
end $$;

-- All client roles are denied raw state and owner-selecting RPCs.
do $$ declare role_name text; relation text; rpc regprocedure; begin
    foreach role_name in array array['anon','authenticated'] loop
        foreach relation in array array['looking_for_categories','activity_interests','interest_looking_for_links','profile_looking_for',
            'profile_activity_interests','discovery_activity_filters','profile_setup_progress','activity_feed_sessions','activity_feed_entries'] loop
            if has_table_privilege(role_name,'private.'||relation,'SELECT,INSERT,UPDATE,DELETE') then raise exception 'Client table access: %',relation; end if;
            if not (select relrowsecurity from pg_class where oid=('private.'||relation)::regclass) then raise exception 'RLS missing'; end if;
        end loop;
        for rpc in select oid::regprocedure from pg_proc where proname like 'activity_%' loop
            if has_function_privilege(role_name,rpc,'EXECUTE') then raise exception 'Client RPC access: %',rpc; end if;
        end loop;
    end loop;
end $$;

insert into private.activity_feed_sessions(id,user_id,mode,context_revision) values
    ('71000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','strict','fixture');
insert into private.activity_feed_entries values ('71000000-0000-0000-0000-000000000001',0,'70000000-0000-0000-0000-000000000002');
delete from auth.users where id='70000000-0000-0000-0000-000000000002';
do $$ begin
    if exists(select 1 from private.activity_feed_entries) or exists(select 1 from private.profile_setup_progress where user_id='70000000-0000-0000-0000-000000000002')
        or exists(select 1 from private.profile_looking_for where user_id='70000000-0000-0000-0000-000000000002')
        or exists(select 1 from private.discovery_activity_filters where user_id='70000000-0000-0000-0000-000000000002')
    then raise exception 'Account/peer cleanup failed'; end if;
end $$;
delete from auth.users where id='70000000-0000-0000-0000-000000000001';
do $$ begin
    if exists(select 1 from private.activity_feed_sessions) or exists(select 1 from private.profile_activity_interests where user_id='70000000-0000-0000-0000-000000000001') then raise exception 'Owner cleanup failed'; end if;
end $$;
rollback;
