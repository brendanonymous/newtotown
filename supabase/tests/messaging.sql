-- All fixtures and assertions roll back; this suite never retains user data.
begin;
insert into auth.users(id) values
    ('00000000-0000-0000-0000-000000000041'),
    ('00000000-0000-0000-0000-000000000042'),
    ('00000000-0000-0000-0000-000000000043');
insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true
from auth.users where id::text in ('00000000-0000-0000-0000-000000000041',
    '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000043');
insert into storage.objects(bucket_id, name)
select 'private-photos', id::text || '/profile.jpg' from public.profiles
where id::text in ('00000000-0000-0000-0000-000000000041',
    '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000043');
update public.pilot_features set photo_review_required = false;

set local role service_role;
do $$
declare a uuid := '00000000-0000-0000-0000-000000000041';
    b uuid := '00000000-0000-0000-0000-000000000042';
    c uuid := '00000000-0000-0000-0000-000000000043';
    conversation jsonb; thread uuid; other_thread uuid; sent jsonb; history jsonb; page jsonb;
    retry uuid := gen_random_uuid(); stamp timestamptz; invalid_text text;
begin
    perform public.pilot_discovery_visibility(a, true);
    perform public.pilot_discovery_visibility(b, true);
    perform public.pilot_discovery_visibility(c, true);
    perform public.pilot_discovery_decide(a, b, 'connect');
    begin
        perform public.pilot_messaging_open(a, b);
        raise exception 'One-sided interest opened a thread';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    begin
        perform public.pilot_messaging_open(a, a);
        raise exception 'Self thread allowed';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    perform public.pilot_discovery_decide(b, a, 'connect');
    conversation := public.pilot_messaging_open(a, b);
    thread := (conversation->>'id')::uuid;
    if conversation->'participant'->>'id' <> b::text or conversation->'participant' ? 'date_of_birth'
        or conversation ? 'participant_one_id' then raise exception 'Wrong/private conversation projection'; end if;
    if public.pilot_messaging_open(b, a)->>'id' <> thread::text then raise exception 'Reverse open duplicated thread'; end if;
    sent := public.pilot_messaging_send(a, thread, retry, 'Coffee on Saturday?');
    if sent->>'sender_id' <> a::text or sent->>'body' <> 'Coffee on Saturday?' then raise exception 'Wrong message'; end if;
    select last_activity_at into stamp from private.conversations where id = thread;
    if public.pilot_messaging_send(a, thread, retry, 'Coffee on Saturday?') <> sent then raise exception 'Retry changed message'; end if;
    if (select last_activity_at from private.conversations where id = thread) <> stamp then raise exception 'Retry bumped activity'; end if;
    begin
        perform public.pilot_messaging_send(a, thread, retry, 'Different message');
        raise exception 'Retry key overwrote body';
    exception when sqlstate 'P0002' then null; end;
    -- The retry namespace is scoped to sender and conversation.
    perform public.pilot_messaging_send(b, thread, retry, 'Sounds good!');
    history := public.pilot_messaging_history(b, thread);
    if jsonb_array_length(history->'messages') <> 2 then raise exception 'Participant history missing'; end if;
    if (history->'conversation'->'participant'->>'id') <> a::text then raise exception 'Wrong peer'; end if;
    if jsonb_array_length(public.pilot_messaging_list(a)->'conversations') <> 1 then raise exception 'Inbox missing'; end if;
    begin
        perform public.pilot_messaging_history(c, thread);
        raise exception 'Unrelated caller read thread';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    begin
        perform public.pilot_messaging_send(c, thread, gen_random_uuid(), 'Impersonation');
        raise exception 'Unrelated caller sent message';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    begin
        perform public.pilot_messaging_history(a, gen_random_uuid());
        raise exception 'Missing thread returned data';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    foreach invalid_text in array array['', '   ', E'\t\r\n', chr(160), chr(8199), chr(65279), repeat('a', 2001), null] loop
        begin
            perform public.pilot_messaging_send(a, thread, gen_random_uuid(), invalid_text);
            raise exception 'Invalid text accepted';
        exception when invalid_parameter_value then null; end;
    end loop;
    perform public.pilot_messaging_send(a, thread, gen_random_uuid(), repeat('😀', 2000));
    perform public.pilot_messaging_send(a, thread, gen_random_uuid(), E'  Line one\nLine two  ');
    begin
        perform public.pilot_messaging_history(a, thread, now(), null);
        raise exception 'Partial cursor accepted';
    exception when invalid_parameter_value then null; end;
    begin
        perform public.pilot_messaging_list(a, now(), gen_random_uuid());
        raise exception 'Unowned list cursor accepted';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    -- New pages are bounded and resolve equal timestamps using their UUIDs.
    for i in 1..52 loop
        perform public.pilot_messaging_send(a, thread, gen_random_uuid(), 'Message ' || i);
    end loop;
    page := public.pilot_messaging_history(a, thread);
    if jsonb_array_length(page->'messages') <> 50 or page->'next_cursor' = 'null'::jsonb then raise exception 'Unbounded/missing history page'; end if;
    history := public.pilot_messaging_history(a, thread, (page->'next_cursor'->>'time')::timestamptz,
        (page->'next_cursor'->>'id')::uuid);
    if jsonb_array_length(history->'messages') <> 6 or history->'next_cursor' <> 'null'::jsonb then raise exception 'History cursor lost messages'; end if;
    -- Hide pauses both participants, but does not delete history.
    perform public.pilot_discovery_visibility(b, false);
    if jsonb_array_length(public.pilot_messaging_list(a)->'conversations') <> 0 then raise exception 'Hidden thread listed'; end if;
    begin
        perform public.pilot_messaging_send(a, thread, retry, 'Coffee on Saturday?');
        raise exception 'Retry bypassed visibility';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    begin
        perform public.pilot_messaging_history(b, thread);
        raise exception 'Hidden caller read history';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    perform public.pilot_discovery_visibility(b, true);
    if public.pilot_messaging_open(b, a)->>'id' <> thread::text then raise exception 'Rejoin lost conversation'; end if;
    update public.pilot_features set photo_review_required = true;
    begin
        perform public.pilot_messaging_history(a, thread);
        raise exception 'Review requirement bypassed';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    update public.pilot_features set photo_review_required = false;
    insert into public.profile_access(user_id, suspended) values (b, true);
    begin
        perform public.pilot_messaging_open(a, b);
        raise exception 'Suspension bypassed';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    update public.profile_access set suspended = false where user_id = b;
    perform public.pilot_discovery_decide(a, c, 'pass');
    perform public.pilot_discovery_decide(c, a, 'connect');
    begin
        perform public.pilot_messaging_open(a, c);
        raise exception 'Pass opened a thread';
    exception when sqlstate 'P0001' then
        if sqlerrm <> 'Conversation unavailable' then raise; end if;
    end;
    perform public.pilot_discovery_block(b, a);
    foreach other_thread in array array[thread] loop
        begin
            perform public.pilot_messaging_history(a, other_thread);
            raise exception 'Blocked history exposed';
        exception when sqlstate 'P0001' then
            if sqlerrm <> 'Conversation unavailable' then raise; end if;
        end;
        begin
            perform public.pilot_messaging_send(b, other_thread, gen_random_uuid(), 'Blocked');
            raise exception 'Blocker sent message';
        exception when sqlstate 'P0001' then
            if sqlerrm <> 'Conversation unavailable' then raise; end if;
        end;
    end loop;
    if jsonb_array_length(public.pilot_messaging_list(a)->'conversations') <> 0
        or jsonb_array_length(public.pilot_messaging_list(b)->'conversations') <> 0 then raise exception 'Blocked thread listed'; end if;
end $$;
reset role;

-- Direct client reads/writes and every RPC are denied even with a forged caller ID.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000043';
do $$ begin
    begin perform public.pilot_messaging_open('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000042');
        raise exception 'Client impersonated caller'; exception when insufficient_privilege then null; end;
    begin perform public.pilot_messaging_list(auth.uid());
        raise exception 'Client called server list'; exception when insufficient_privilege then null; end;
    begin perform public.pilot_messaging_history(auth.uid(), gen_random_uuid());
        raise exception 'Client called server history'; exception when insufficient_privilege then null; end;
    begin perform public.pilot_messaging_send(auth.uid(), gen_random_uuid(), gen_random_uuid(), 'No');
        raise exception 'Client called server send'; exception when insufficient_privilege then null; end;
    begin perform * from private.conversations;
        raise exception 'Direct conversation read allowed'; exception when insufficient_privilege then null; end;
    begin perform * from private.messages;
        raise exception 'Direct message read allowed'; exception when insufficient_privilege then null; end;
    begin insert into private.messages(conversation_id, sender_id, client_message_id, body)
        values (gen_random_uuid(), auth.uid(), gen_random_uuid(), 'No');
        raise exception 'Direct message insert allowed'; exception when insufficient_privilege then null; end;
    begin update private.messages set body = 'Edited';
        raise exception 'Direct message edit allowed'; exception when insufficient_privilege then null; end;
    begin delete from private.messages;
        raise exception 'Direct message delete allowed'; exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
    begin perform public.pilot_messaging_list(gen_random_uuid());
        raise exception 'Anonymous RPC allowed'; exception when insufficient_privilege then null; end;
    begin perform * from private.messages;
        raise exception 'Anonymous messages exposed'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Hard-deleting either participant removes the entire thread, not only their sends.
delete from auth.users where id = '00000000-0000-0000-0000-000000000042';
do $$ begin
    if exists(select 1 from private.conversations) or exists(select 1 from private.messages) then
        raise exception 'Deleted participant conversation history remains';
    end if;
    if not exists(select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000041') then
        raise exception 'Deletion removed the other profile';
    end if;
end $$;
rollback;

-- Exercise a full inbox and tied timestamps with an independent fixture.
begin;
insert into auth.users(id)
select ('10000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid from generate_series(1, 52) i;
insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true
from auth.users where id::text like '10000000-0000-0000-0000-%';
insert into storage.objects(bucket_id, name)
select 'private-photos', id::text || '/profile.jpg' from public.profiles where id::text like '10000000-0000-0000-0000-%';
insert into public.discovery_settings(user_id, visible)
select id, true from public.profiles where id::text like '10000000-0000-0000-0000-%';
insert into public.connection_decisions(user_id, target_id, choice)
select '10000000-0000-0000-0000-000000000001', id, 'connect' from public.profiles
where id::text like '10000000-0000-0000-0000-%' and id <> '10000000-0000-0000-0000-000000000001';
insert into public.connection_decisions(user_id, target_id, choice)
select id, '10000000-0000-0000-0000-000000000001', 'connect' from public.profiles
where id::text like '10000000-0000-0000-0000-%' and id <> '10000000-0000-0000-0000-000000000001';
update public.pilot_features set photo_review_required = false;
set local role service_role;
select public.pilot_messaging_open('10000000-0000-0000-0000-000000000001', id) is not null as opened
from public.profiles where id::text like '10000000-0000-0000-0000-%' and id <> '10000000-0000-0000-0000-000000000001';
update private.conversations set last_activity_at = '2026-10-17T00:00:00Z';
do $$
declare person uuid := '10000000-0000-0000-0000-000000000001';
    first_page jsonb; second_page jsonb; first_thread uuid; second_thread uuid; sent jsonb;
begin
    first_page := public.pilot_messaging_list(person);
    if jsonb_array_length(first_page->'conversations') <> 50 then raise exception 'Inbox page not bounded'; end if;
    second_page := public.pilot_messaging_list(person, (first_page->'next_cursor'->>'time')::timestamptz,
        (first_page->'next_cursor'->>'id')::uuid);
    if jsonb_array_length(second_page->'conversations') <> 1 or second_page->'next_cursor' <> 'null'::jsonb then
        raise exception 'Tied inbox cursor lost a thread';
    end if;
    if exists(select 1 from jsonb_array_elements(first_page->'conversations') a,
        jsonb_array_elements(second_page->'conversations') b where a->>'id' = b->>'id') then
        raise exception 'Inbox pages overlap';
    end if;
    first_thread := (first_page->'conversations'->0->>'id')::uuid;
    second_thread := (second_page->'conversations'->0->>'id')::uuid;
    sent := public.pilot_messaging_send(person, first_thread, gen_random_uuid(), 'A private message');
    begin
        perform public.pilot_messaging_history(person, second_thread, (sent->>'created_at')::timestamptz, (sent->>'id')::uuid);
        raise exception 'Cross-conversation message cursor allowed';
    exception when invalid_parameter_value then null; end;
    perform public.pilot_messaging_send(person, second_thread, gen_random_uuid(), 'Newest activity');
    if public.pilot_messaging_list(person)->'conversations'->0->>'id' <> second_thread::text then
        raise exception 'Inbox not ordered by new message activity';
    end if;
end $$;
reset role;
-- Index tie-breakers must also work for messages sharing a server timestamp.
do $$
declare thread uuid; sender uuid;
begin
    select id, participant_one_id into thread, sender from private.conversations order by id limit 1;
    insert into private.messages(conversation_id, sender_id, client_message_id, body, created_at)
    select thread, sender, gen_random_uuid(), 'Same timestamp ' || i, '2026-10-17T00:00:00Z'
    from generate_series(1, 55) i;
end $$;
update private.messages set created_at = '2026-10-17T00:00:00Z';
set local role service_role;
do $$
declare person uuid := '10000000-0000-0000-0000-000000000001'; thread uuid;
    first_page jsonb; second_page jsonb; total integer;
begin
    select conversation_id into thread from private.messages group by conversation_id having count(*) > 50;
    select count(*) into total from private.messages where conversation_id = thread;
    first_page := public.pilot_messaging_history(person, thread);
    second_page := public.pilot_messaging_history(person, thread,
        (first_page->'next_cursor'->>'time')::timestamptz, (first_page->'next_cursor'->>'id')::uuid);
    if jsonb_array_length(first_page->'messages') <> 50 or jsonb_array_length(second_page->'messages') <> total - 50 then
        raise exception 'Tied message cursor lost messages';
    end if;
    if exists(select 1 from jsonb_array_elements(first_page->'messages') a,
        jsonb_array_elements(second_page->'messages') b where a->>'id' = b->>'id') then
        raise exception 'Message pages overlap';
    end if;
end $$;
reset role;

-- Security-advisor equivalents for the new objects, against the actual local schema.
do $$
declare relation text; role_name text; operation text; procedure record;
begin
    foreach relation in array array['private.conversations', 'private.messages'] loop
        if not (select relrowsecurity from pg_class where oid = relation::regclass) then raise exception 'RLS missing'; end if;
        foreach role_name in array array['anon', 'authenticated'] loop
            foreach operation in array array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] loop
                if has_table_privilege(role_name, relation, operation) then raise exception 'Client table privilege remains'; end if;
            end loop;
        end loop;
    end loop;
    if has_column_privilege('service_role', 'private.conversations', 'participant_one_id', 'UPDATE')
        or has_column_privilege('service_role', 'private.messages', 'body', 'UPDATE') then raise exception 'Server can mutate immutable fields'; end if;
    for procedure in select oid, prosecdef, proconfig from pg_proc where proname like 'pilot_messaging_%'
        or proname in ('lock_messaging_pair', 'messaging_pair_allowed', 'require_conversation', 'message_projection', 'conversation_projection') loop
        if procedure.prosecdef or not ('search_path=""' = any(procedure.proconfig)) then raise exception 'Unsafe function security/search path'; end if;
        if has_function_privilege('anon', procedure.oid, 'EXECUTE') or has_function_privilege('authenticated', procedure.oid, 'EXECUTE') then
            raise exception 'Client can execute messaging helper/RPC';
        end if;
    end loop;
end $$;
rollback;
