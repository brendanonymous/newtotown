begin;

-- Only committed messages move a connection into Messages. Preserve mutual decisions.
create or replace function public.pilot_discovery_feed(person uuid) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare state text := private.discovery_state(person);
begin
    return jsonb_build_object(
        'state', state,
        'visible', coalesce((select visible from public.discovery_settings where user_id = person), false),
        'candidates', case when state = 'ready' then coalesce((
            select jsonb_agg(to_jsonb(candidate)) from (
                select profile.id, profile.first_name, profile.job_title, profile.goal, profile.city
                from public.profiles profile
                where private.discovery_pair_allowed(person, profile.id)
                    and not exists (select 1 from public.connection_decisions where user_id = person and target_id = profile.id)
                order by profile.created_at, profile.id limit 20
            ) candidate
        ), '[]'::jsonb) else '[]'::jsonb end,
        'matches', case when state = 'ready' then coalesce((
            select jsonb_agg(to_jsonb(connection)) from (
                select profile.id, profile.first_name, profile.job_title, profile.goal, profile.city
                from public.profiles profile
                join public.connection_decisions outgoing on outgoing.user_id = person and outgoing.target_id = profile.id and outgoing.choice = 'connect'
                join public.connection_decisions incoming on incoming.user_id = profile.id and incoming.target_id = person and incoming.choice = 'connect'
                where private.discovery_pair_allowed(person, profile.id)
                    and not exists (
                        select 1 from private.conversations conversation
                        join private.messages message on message.conversation_id = conversation.id
                        where conversation.participant_one_id = least(person, profile.id)
                            and conversation.participant_two_id = greatest(person, profile.id)
                    )
                order by greatest(outgoing.created_at, incoming.created_at) desc, profile.id limit 50
            ) connection
        ), '[]'::jsonb) else '[]'::jsonb end
    );
end;
$$;

create or replace function public.pilot_messaging_list(person uuid, before_time timestamptz default null, before_id uuid default null)
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
            and exists (select 1 from private.messages message where message.conversation_id = conversation.id)
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

commit;
