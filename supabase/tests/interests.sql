begin;
insert into auth.users(id) values ('60000000-0000-0000-0000-000000000001'), ('60000000-0000-0000-0000-000000000002'), ('60000000-0000-0000-0000-000000000003');
insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a coffee buddy.', current_date - interval '30 years', 'Scottsdale', true
from auth.users where id::text like '60000000-%';
insert into storage.objects(bucket_id, name)
select 'private-photos', id::text || '/profile.jpg' from public.profiles where id::text like '60000000-%';
update public.pilot_features set photo_review_required = false;
set local role service_role;
do $$
declare a uuid := '60000000-0000-0000-0000-000000000001'; b uuid := '60000000-0000-0000-0000-000000000002'; c uuid := '60000000-0000-0000-0000-000000000003'; result jsonb; invalid text[]; thread uuid;
begin
    result := public.pilot_interests(a);
    if jsonb_array_length(result->'categories') <> 5 or result->'profile_option_ids' <> '[]'::jsonb or result->'filter_option_ids' <> '[]'::jsonb then raise exception 'Wrong defaults'; end if;
    perform public.pilot_interests_save(a, 'profile', array['golf','gym','tennis','coffee','professional_networking']);
    if (public.pilot_interests(b)->'profile_option_ids') <> '[]'::jsonb then raise exception 'Peer modified'; end if;
    if exists(select 1 from public.discovery_settings where user_id=a) then raise exception 'Interests enabled discovery'; end if;
    perform public.pilot_interests_save(b, 'profile', array['golf']);
    perform public.pilot_interests_save(a, 'filters', array['golf','coffee']);
    if jsonb_array_length(public.pilot_interests(a)->'profile_option_ids') <> 5 then raise exception 'Filters overwrote interests'; end if;
    perform public.pilot_discovery_visibility(a,true); perform public.pilot_discovery_visibility(b,true); perform public.pilot_discovery_visibility(c,true);
    result := public.pilot_discovery_feed(a);
    if jsonb_array_length(result->'candidates') <> 1 or result->'candidates'->0->>'id' <> b::text then raise exception 'Any-interest filtering failed'; end if;
    if result->'candidates'->0->'interests' <> '[{"id":"golf","category_id":"sports_fitness","title":"Golf"}]'::jsonb then raise exception 'Public interests missing'; end if;
    if (result->'candidates'->0) ? 'filter_option_ids' then raise exception 'Private filters exposed'; end if;
    perform public.pilot_discovery_save_preferences(a,40,50);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 then raise exception 'Age filter ignored'; end if;
    perform public.pilot_discovery_save_preferences(a,18,null);
    perform public.pilot_discovery_decide(a,b,'connect'); perform public.pilot_discovery_decide(b,a,'connect');
    perform public.pilot_interests_save(a,'filters',array['hiking']);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 1 then raise exception 'Filters removed connection'; end if;
    thread := (public.pilot_messaging_open(a,b)->>'id')::uuid;
    perform public.pilot_messaging_send(a,thread,gen_random_uuid(),'Still connected');
    result := public.pilot_messaging_history(a,thread);
    if jsonb_array_length(result->'conversation'->'participant'->'interests') <> 1 then raise exception 'Conversation interests missing'; end if;
    perform public.pilot_interests_save(a,'filters',array[]::text[]);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 1 then raise exception 'Clear filters failed'; end if;
    -- Validate before deletion: a rejected replacement must preserve the previous selection.
    foreach invalid slice 1 in array array[array['golf','golf'],array['golf','unknown']] loop
        begin
            perform public.pilot_interests_save(a,'profile',invalid);
            raise exception 'Invalid selection accepted';
        exception when invalid_parameter_value then null; end;
    end loop;
    begin perform public.pilot_interests_save(a,'profile',array['golf','gym','tennis','running']); raise exception 'Four in category accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.pilot_interests_save(a,'profile',array[null]::text[]); raise exception 'Null option accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.pilot_interests_save(a,'profile',null); raise exception 'Null list accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.pilot_interests_save(a,'wrong',array[]::text[]); raise exception 'Invalid kind accepted'; exception when invalid_parameter_value then null; end;
    begin perform public.pilot_interests_save(gen_random_uuid(),'profile',array['golf']); raise exception 'Missing owner accepted'; exception when raise_exception then if sqlerrm <> 'Profile unavailable' then raise; end if; end;
    if jsonb_array_length(public.pilot_interests(a)->'profile_option_ids') <> 5 then raise exception 'Rejected save lost data'; end if;
end $$;
reset role;
-- Matching must happen before the feed limit, even behind thirty nonmatching rows.
insert into auth.users(id) select ('61000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid from generate_series(1,31) i;
insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement,created_at)
select id,'Sam','Engineer','Find a coffee buddy.',current_date - interval '30 years','Scottsdale',true,now()-interval '1 day'
from auth.users where id::text like '61000000-%';
insert into storage.objects(bucket_id,name) select 'private-photos',id::text||'/profile.jpg' from public.profiles where id::text like '61000000-%';
insert into public.discovery_settings(user_id,visible) select id,true from public.profiles where id::text like '61000000-%';
set local role service_role;
do $$ declare a uuid := '60000000-0000-0000-0000-000000000001'; target uuid := '61000000-0000-0000-0000-000000000031'; result jsonb; begin
    perform public.pilot_interests_save(target,'profile',array['coffee']);
    perform public.pilot_interests_save(a,'filters',array['coffee']);
    result := public.pilot_discovery_feed(a);
    if jsonb_array_length(result->'candidates') <> 1 or result->'candidates'->0->>'id' <> target::text then raise exception 'Matching occurred after limit'; end if;
    perform public.pilot_discovery_visibility(target,false);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 then raise exception 'Filter bypassed hidden profile'; end if;
    perform public.pilot_discovery_visibility(target,true);
    perform public.pilot_discovery_block(a,target);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 then raise exception 'Filter bypassed block'; end if;
end $$;
reset role;
-- Catalog retirement hides old choices and makes a filter with no active choices inactive.
update private.interest_options set active=false where id='golf';
set local role service_role;
do $$ declare a uuid := '60000000-0000-0000-0000-000000000001'; begin
    begin perform public.pilot_interests_save(a,'profile',array['golf']); raise exception 'Inactive accepted'; exception when invalid_parameter_value then null; end;
    if jsonb_array_length(private.profile_interests('60000000-0000-0000-0000-000000000002')) <> 0 then raise exception 'Inactive projected'; end if;
end $$;
reset role;
-- Referential integrity protects category membership even against privileged tooling mistakes.
do $$ begin
    begin insert into private.profile_interest_selections values('60000000-0000-0000-0000-000000000003','outdoors','coffee'); raise exception 'Category mismatch accepted'; exception when foreign_key_violation then null; end;
end $$;
-- No client role can read raw selections or invoke owner-selecting functions.
do $$ declare role_name text; table_name text; signature text; begin
    foreach role_name in array array['anon','authenticated'] loop
        foreach table_name in array array['interest_categories','interest_options','profile_interest_selections','discovery_interest_filters'] loop
            if has_table_privilege(role_name,'private.'||table_name,'SELECT,INSERT,UPDATE,DELETE') then raise exception 'Client table access'; end if;
        end loop;
        foreach signature in array array['public.pilot_interests(uuid)','public.pilot_interests_save(uuid,text,text[])','private.profile_interests(uuid)','private.discovery_interests_allowed(uuid,uuid)'] loop
            if has_function_privilege(role_name,signature,'EXECUTE') then raise exception 'Client RPC access'; end if;
        end loop;
    end loop;
end $$;
delete from auth.users where id='60000000-0000-0000-0000-000000000001';
do $$ begin
    if exists(select 1 from private.profile_interest_selections where user_id='60000000-0000-0000-0000-000000000001') or exists(select 1 from private.discovery_interest_filters where user_id='60000000-0000-0000-0000-000000000001') then raise exception 'Delete did not cascade'; end if;
end $$;
rollback;
