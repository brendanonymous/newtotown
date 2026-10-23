begin;
insert into auth.users(id) values ('50000000-0000-0000-0000-000000000001'), ('50000000-0000-0000-0000-000000000002'), ('50000000-0000-0000-0000-000000000003');
insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement)
select id,'Alex','Designer','Find a coffee buddy.','1990-01-01','Scottsdale',true from auth.users where id::text like '50000000-%';
insert into storage.objects(bucket_id,name)
select 'private-photos', id::text || '/profile.jpg' from auth.users where id::text like '50000000-%';
insert into public.discovery_settings(user_id,visible)
select id,true from auth.users where id::text like '50000000-%';
update public.pilot_features set photo_review_required=false;
insert into public.connection_decisions(user_id,target_id,choice) values
('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','connect'),
('50000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000001','connect');
set local role service_role;
do $$
declare a uuid := '50000000-0000-0000-0000-000000000001'; b uuid := '50000000-0000-0000-0000-000000000002';
    c uuid := '50000000-0000-0000-0000-000000000003'; retry uuid := gen_random_uuid(); receipt jsonb; thread uuid;
begin
    thread := (public.pilot_messaging_open(a,b)->>'id')::uuid;
    perform public.pilot_messaging_send(a,thread,gen_random_uuid(),'Before report');
    receipt := public.pilot_report_profile(a,b,'non_platonic',null,retry);
    if receipt <> public.pilot_report_profile(a,b,'non_platonic',null,retry) then raise exception 'Retry duplicated receipt'; end if;
    if (select count(*) from private.profile_reports) <> 1 then raise exception 'Duplicate report stored'; end if;
    if (select count(*) from public.profile_blocks where user_id=a and target_id=b) <> 1 then raise exception 'Report did not prevent contact'; end if;
    if private.discovery_pair_allowed(a,b) or private.discovery_pair_allowed(b,a) then raise exception 'Reported profiles still visible'; end if;
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 0
        or jsonb_array_length(public.pilot_discovery_feed(b)->'matches') <> 0
        or jsonb_array_length(public.pilot_messaging_list(a)->'conversations') <> 0
        or jsonb_array_length(public.pilot_messaging_list(b)->'conversations') <> 0 then raise exception 'Reported connection still listed'; end if;
    begin perform public.pilot_messaging_send(b,thread,gen_random_uuid(),'After report'); raise exception 'Message after report accepted';
        exception when raise_exception then if sqlerrm <> 'Conversation unavailable' then raise; end if; end;
    begin perform public.pilot_messaging_history(a,thread); raise exception 'Reported history still accessible';
        exception when raise_exception then if sqlerrm <> 'Conversation unavailable' then raise; end if; end;
    if (select count(*) from private.messages where conversation_id=thread) <> 1 then raise exception 'Stored history was deleted'; end if;
    if (select status from private.profile_reports where reporter_id=a) <> 'pending' then raise exception 'Wrong initial status'; end if;
    begin perform public.pilot_report_profile(a,b,'spam',null,retry); raise exception 'Changed retry accepted';
        exception when unique_violation then null; end;
    begin perform public.pilot_report_profile(a,c,'spam',null,gen_random_uuid()); raise exception 'Stranger report accepted';
        exception when raise_exception then if sqlerrm <> 'Connection unavailable' then raise; end if; end;
    if exists(select 1 from public.profile_blocks where user_id=a and target_id=c) then raise exception 'Failed report blocked a stranger'; end if;
    begin perform public.pilot_report_profile(a,a,'spam',null,gen_random_uuid()); raise exception 'Self report accepted';
        exception when invalid_parameter_value then null; end;
    begin perform public.pilot_report_profile(a,b,'invalid',null,gen_random_uuid()); raise exception 'Invalid reason accepted';
        exception when invalid_parameter_value then null; end;
    begin perform public.pilot_report_profile(a,b,'other',repeat('😀',1001),gen_random_uuid()); raise exception 'Long details accepted';
        exception when invalid_parameter_value then null; end;
    perform public.pilot_report_profile(a,b,'other',repeat('😀',1000),gen_random_uuid());
    perform public.pilot_discovery_block(b,a);
    perform public.pilot_report_profile(a,b,'unwanted_contact','Previously connected',gen_random_uuid());
    if (select count(*) from private.profile_reports where reporter_id=a) <> 3 then raise exception 'Blocked connection not reportable'; end if;
    perform public.pilot_discovery_decide(a,c,'connect'); perform public.pilot_discovery_decide(c,a,'connect');
    begin perform public.pilot_report_profile(a,c,'non_platonic',null,retry); raise exception 'Retry changed target';
        exception when unique_violation then null; end;
    if exists(select 1 from public.profile_blocks where user_id=a and target_id=c) then raise exception 'Retry conflict blocked another target'; end if;
end $$;
reset role;
-- Force a downstream block error: report insertion must roll back with it.
create function pg_temp.reject_report_block() returns trigger language plpgsql as $$ begin
    if new.target_id='50000000-0000-0000-0000-000000000003'::uuid then raise exception 'Test block failure'; end if;
    return new;
end $$;
create trigger reject_report_block before insert on public.profile_blocks for each row execute function pg_temp.reject_report_block();
set local role service_role;
do $$ declare retry uuid := gen_random_uuid(); begin
    begin perform public.pilot_report_profile('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000003','spam',null,retry);
        raise exception 'Expected downstream failure'; exception when raise_exception then if sqlerrm <> 'Test block failure' then raise; end if; end;
    if exists(select 1 from private.profile_reports where client_report_id=retry) then raise exception 'Partial report committed'; end if;
end $$;
reset role;
do $$ begin
    if not (select relrowsecurity from pg_class where oid='private.profile_reports'::regclass) then raise exception 'Missing RLS'; end if;
    if has_table_privilege('anon','private.profile_reports','SELECT') or has_table_privilege('authenticated','private.profile_reports','SELECT')
        or has_table_privilege('authenticated','private.profile_reports','INSERT')
        or has_function_privilege('anon','public.pilot_report_profile(uuid,uuid,text,text,uuid)','EXECUTE')
        or has_function_privilege('authenticated','public.pilot_report_profile(uuid,uuid,text,text,uuid)','EXECUTE') then raise exception 'Client report access'; end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '50000000-0000-0000-0000-000000000001';
do $$ begin
    begin perform public.pilot_report_profile(auth.uid(),'50000000-0000-0000-0000-000000000002','spam',null,gen_random_uuid());
        raise exception 'Client RPC accepted'; exception when insufficient_privilege then null; end;
    begin perform * from private.profile_reports; raise exception 'Client read accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
delete from auth.users where id='50000000-0000-0000-0000-000000000001';
do $$ begin if exists(select 1 from private.profile_reports) then raise exception 'Account deletion retained reports'; end if; end $$;
rollback;
