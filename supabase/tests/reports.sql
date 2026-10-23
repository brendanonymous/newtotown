begin;
insert into auth.users(id) values ('50000000-0000-0000-0000-000000000001'), ('50000000-0000-0000-0000-000000000002'), ('50000000-0000-0000-0000-000000000003');
insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement)
select id,'Alex','Designer','Find a coffee buddy.','1990-01-01','Scottsdale',true from auth.users where id::text like '50000000-%';
insert into public.connection_decisions(user_id,target_id,choice) values
('50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','connect'),
('50000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000001','connect');
set local role service_role;
do $$
declare a uuid := '50000000-0000-0000-0000-000000000001'; b uuid := '50000000-0000-0000-0000-000000000002';
    c uuid := '50000000-0000-0000-0000-000000000003'; retry uuid := gen_random_uuid(); receipt jsonb;
begin
    receipt := public.pilot_report_profile(a,b,'non_platonic',null,retry);
    if receipt <> public.pilot_report_profile(a,b,'non_platonic',null,retry) then raise exception 'Retry duplicated receipt'; end if;
    if (select count(*) from private.profile_reports) <> 1 then raise exception 'Duplicate report stored'; end if;
    if exists(select 1 from public.profile_blocks where user_id=a) then raise exception 'Report blocked peer'; end if;
    if (select status from private.profile_reports where reporter_id=a) <> 'pending' then raise exception 'Wrong initial status'; end if;
    begin perform public.pilot_report_profile(a,b,'spam',null,retry); raise exception 'Changed retry accepted';
        exception when unique_violation then null; end;
    begin perform public.pilot_report_profile(a,c,'spam',null,gen_random_uuid()); raise exception 'Stranger report accepted';
        exception when raise_exception then if sqlerrm <> 'Connection unavailable' then raise; end if; end;
    begin perform public.pilot_report_profile(a,a,'spam',null,gen_random_uuid()); raise exception 'Self report accepted';
        exception when invalid_parameter_value then null; end;
    begin perform public.pilot_report_profile(a,b,'invalid',null,gen_random_uuid()); raise exception 'Invalid reason accepted';
        exception when invalid_parameter_value then null; end;
    begin perform public.pilot_report_profile(a,b,'other',repeat('😀',1001),gen_random_uuid()); raise exception 'Long details accepted';
        exception when invalid_parameter_value then null; end;
    perform public.pilot_report_profile(a,b,'other',repeat('😀',1000),gen_random_uuid());
    -- Reports remain possible after hiding/blocking, with no discovery visibility bypass.
    perform public.pilot_discovery_block(b,a);
    perform public.pilot_report_profile(a,b,'unwanted_contact','Previously connected',gen_random_uuid());
    if (select count(*) from private.profile_reports where reporter_id=a) <> 3 then raise exception 'Blocked connection not reportable'; end if;
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
