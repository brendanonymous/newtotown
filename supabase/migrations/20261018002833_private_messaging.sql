begin;

create table private.conversations (
    id uuid primary key default gen_random_uuid(),
    participant_one_id uuid not null references public.profiles(id) on delete cascade,
    participant_two_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default clock_timestamp(),
    last_activity_at timestamptz not null default clock_timestamp(),
    constraint conversations_canonical_pair check (participant_one_id < participant_two_id),
    constraint conversations_unique_pair unique (participant_one_id, participant_two_id)
);
create index conversations_first_inbox on private.conversations(participant_one_id, last_activity_at desc, id desc);
create index conversations_second_inbox on private.conversations(participant_two_id, last_activity_at desc, id desc);

create table private.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references private.conversations(id) on delete cascade,
    sender_id uuid not null references public.profiles(id) on delete cascade,
    client_message_id uuid not null,
    body text not null,
    created_at timestamptz not null default clock_timestamp(),
    constraint messages_body_length check (char_length(body) between 1 and 2000),
    -- The whitespace set matches JavaScript String.trim(), including Unicode spaces.
    constraint messages_body_not_blank check (body !~ U&'^[\0009-\000D\0020\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]*$'),
    constraint messages_retry_key unique (conversation_id, sender_id, client_message_id)
);
create index messages_history on private.messages(conversation_id, created_at desc, id desc);
create index messages_sender on private.messages(sender_id);

alter table private.conversations enable row level security;
alter table private.messages enable row level security;
revoke all on private.conversations, private.messages from public, anon, authenticated, service_role;
grant select, insert on private.conversations, private.messages to service_role;
grant update (last_activity_at) on private.conversations to service_role;

-- All operations on a pair use the same lock, including the existing block RPC.
-- Hash collisions only serialize unrelated pairs; they never grant access.
create function private.lock_messaging_pair(person uuid, target uuid) returns void
language sql volatile security invoker set search_path = '' as $$
    select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
        least(person, target)::text || ':' || greatest(person, target)::text, 0));
$$;

create function private.messaging_pair_allowed(person uuid, target uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
    select coalesce(private.discovery_pair_allowed(person, target)
        and exists (select 1 from public.connection_decisions
            where user_id = person and target_id = target and choice = 'connect')
        and exists (select 1 from public.connection_decisions
            where user_id = target and target_id = person and choice = 'connect'), false);
$$;

create function private.require_conversation(person uuid, thread uuid, lock_pair boolean default false)
returns private.conversations
language plpgsql volatile security invoker set search_path = '' as $$
declare conversation private.conversations; other_person uuid;
begin
    select * into conversation from private.conversations
        where id = thread and person in (participant_one_id, participant_two_id);
    if not found then raise exception 'Conversation unavailable' using errcode = 'P0001'; end if;
    other_person := case when person = conversation.participant_one_id
        then conversation.participant_two_id else conversation.participant_one_id end;
    if lock_pair then perform private.lock_messaging_pair(person, other_person); end if;
    -- Recheck after acquiring the lock, not against a pre-block snapshot.
    if not private.messaging_pair_allowed(person, other_person) then
        raise exception 'Conversation unavailable' using errcode = 'P0001';
    end if;
    return conversation;
end;
$$;

create function private.message_projection(message private.messages) returns jsonb
language sql immutable security invoker set search_path = '' as $$
    select jsonb_build_object('id', message.id, 'conversation_id', message.conversation_id,
        'sender_id', message.sender_id, 'client_message_id', message.client_message_id,
        'body', message.body, 'created_at', message.created_at);
$$;

create function private.conversation_projection(conversation private.conversations, person uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
    select jsonb_build_object('id', conversation.id, 'created_at', conversation.created_at,
        'last_activity_at', conversation.last_activity_at,
        'participant', jsonb_build_object('id', profile.id, 'first_name', profile.first_name,
            'job_title', profile.job_title, 'goal', profile.goal, 'city', profile.city),
        'last_message', (select private.message_projection(message) from private.messages message
            where conversation_id = conversation.id order by created_at desc, id desc limit 1))
    from public.profiles profile where profile.id = case when person = conversation.participant_one_id
        then conversation.participant_two_id else conversation.participant_one_id end;
$$;

create function public.pilot_messaging_open(person uuid, target uuid) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
declare conversation private.conversations;
begin
    if person is null or target is null then
        raise exception 'Conversation unavailable' using errcode = 'P0001';
    end if;
    perform private.lock_messaging_pair(person, target);
    if not private.messaging_pair_allowed(person, target) then
        raise exception 'Conversation unavailable' using errcode = 'P0001';
    end if;
    insert into private.conversations(participant_one_id, participant_two_id)
        values (least(person, target), greatest(person, target)) on conflict do nothing;
    select * into conversation from private.conversations
        where participant_one_id = least(person, target) and participant_two_id = greatest(person, target);
    return private.conversation_projection(conversation, person);
end;
$$;

create function public.pilot_messaging_list(person uuid, before_time timestamptz default null, before_id uuid default null)
returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
declare result jsonb;
begin
    if (before_time is null) <> (before_id is null) then
        raise exception 'Invalid cursor' using errcode = '22023';
    end if;
    if before_id is not null then perform private.require_conversation(person, before_id); end if;
    with page as materialized (
        select conversation.* from private.conversations conversation
        where person in (participant_one_id, participant_two_id)
            and private.messaging_pair_allowed(participant_one_id, participant_two_id)
            and (before_time is null or (last_activity_at, id) < (before_time, before_id))
        order by last_activity_at desc, id desc limit 51
    ), returned as (select * from page order by last_activity_at desc, id desc limit 50)
    select jsonb_build_object(
        'conversations', coalesce((select jsonb_agg(private.conversation_projection(returned, person)
            order by last_activity_at desc, id desc) from returned), '[]'::jsonb),
        'next_cursor', case when (select count(*) from page) > 50 then
            (select jsonb_build_object('time', last_activity_at, 'id', id) from returned
                order by last_activity_at, id limit 1) else null end
    ) into result;
    return result;
end;
$$;

create function public.pilot_messaging_history(person uuid, thread uuid,
    before_time timestamptz default null, before_id uuid default null) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
declare conversation private.conversations; result jsonb;
begin
    conversation := private.require_conversation(person, thread);
    if (before_time is null) <> (before_id is null) then
        raise exception 'Invalid cursor' using errcode = '22023';
    end if;
    if before_id is not null and not exists (select 1 from private.messages
        where id = before_id and conversation_id = thread and created_at = before_time) then
        raise exception 'Invalid cursor' using errcode = '22023';
    end if;
    with page as materialized (
        select message.* from private.messages message where conversation_id = thread
            and (before_time is null or (created_at, id) < (before_time, before_id))
        order by created_at desc, id desc limit 51
    ), returned as (select * from page order by created_at desc, id desc limit 50)
    select jsonb_build_object('conversation', private.conversation_projection(conversation, person),
        'messages', coalesce((select jsonb_agg(private.message_projection(returned)
            order by created_at desc, id desc) from returned), '[]'::jsonb),
        'next_cursor', case when (select count(*) from page) > 50 then
            (select jsonb_build_object('time', created_at, 'id', id) from returned
                order by created_at, id limit 1) else null end
    ) into result;
    return result;
end;
$$;

create function public.pilot_messaging_send(person uuid, thread uuid, retry_id uuid, content text) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
declare conversation private.conversations; message private.messages;
begin
    conversation := private.require_conversation(person, thread, true);
    if retry_id is null or content is null or char_length(content) not between 1 and 2000
        or content ~ U&'^[\0009-\000D\0020\00A0\1680\2000-\200A\2028\2029\202F\205F\3000\FEFF]*$' then
        raise exception 'Invalid message' using errcode = '22023';
    end if;
    select * into message from private.messages
        where conversation_id = thread and sender_id = person and client_message_id = retry_id;
    if found then
        if message.body <> content then raise exception 'Message retry conflict' using errcode = 'P0002'; end if;
        return private.message_projection(message);
    end if;
    insert into private.messages(conversation_id, sender_id, client_message_id, body)
        values (thread, person, retry_id, content) returning * into message;
    update private.conversations set last_activity_at = greatest(last_activity_at, message.created_at)
        where id = thread;
    return private.message_projection(message);
end;
$$;

create or replace function public.pilot_discovery_block(person uuid, target uuid) returns void
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.lock_messaging_pair(person, target);
    if person = target or not exists (select 1 from public.profiles where id = person)
        or not exists (select 1 from public.profiles where id = target) then
        raise exception 'Profile unavailable' using errcode = 'P0001';
    end if;
    insert into public.profile_blocks(user_id, target_id) values (person, target) on conflict do nothing;
end;
$$;

revoke all on function private.lock_messaging_pair(uuid, uuid), private.messaging_pair_allowed(uuid, uuid),
    private.require_conversation(uuid, uuid, boolean), private.message_projection(private.messages),
    private.conversation_projection(private.conversations, uuid) from public, anon, authenticated;
grant execute on function private.lock_messaging_pair(uuid, uuid), private.messaging_pair_allowed(uuid, uuid),
    private.require_conversation(uuid, uuid, boolean), private.message_projection(private.messages),
    private.conversation_projection(private.conversations, uuid) to service_role;
revoke all on function public.pilot_messaging_open(uuid, uuid), public.pilot_messaging_list(uuid, timestamptz, uuid),
    public.pilot_messaging_history(uuid, uuid, timestamptz, uuid), public.pilot_messaging_send(uuid, uuid, uuid, text)
    from public, anon, authenticated;
grant execute on function public.pilot_messaging_open(uuid, uuid), public.pilot_messaging_list(uuid, timestamptz, uuid),
    public.pilot_messaging_history(uuid, uuid, timestamptz, uuid), public.pilot_messaging_send(uuid, uuid, uuid, text) to service_role;
commit;
