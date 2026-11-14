-- Add completed years to authorized public projections; birthdays remain private.
-- Existing eligibility checks, function privileges, and RLS remain unchanged.
begin;

create or replace function public.pilot_discovery_feed(person uuid) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare state text := private.discovery_state(person);
begin
    return jsonb_build_object(
        'state', state,
        'visible', coalesce((select visible from public.discovery_settings where user_id = person), false),
        'candidates', case when state = 'ready' then coalesce((
            select jsonb_agg(to_jsonb(candidate)) from (
                select profile.id, profile.first_name,
                    extract(year from age((current_timestamp at time zone 'UTC')::date, profile.date_of_birth))::integer as age,
                    profile.job_title, profile.goal, profile.city, private.profile_interests(profile.id) as interests
                from public.profiles profile
                where private.discovery_pair_allowed(person, profile.id)
                    and private.discovery_age_allowed(person, profile.id)
                    and private.discovery_interests_allowed(person, profile.id)
                    and not exists (select 1 from public.connection_decisions where user_id = person and target_id = profile.id)
                order by profile.created_at, profile.id limit 20
            ) candidate
        ), '[]'::jsonb) else '[]'::jsonb end,
        'matches', case when state = 'ready' then coalesce((
            select jsonb_agg(to_jsonb(connection)) from (
                select profile.id, profile.first_name,
                    extract(year from age((current_timestamp at time zone 'UTC')::date, profile.date_of_birth))::integer as age,
                    profile.job_title, profile.goal, profile.city, private.profile_interests(profile.id) as interests
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

create or replace function private.conversation_projection(conversation private.conversations, person uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
    select jsonb_build_object('id', conversation.id, 'created_at', conversation.created_at,
        'last_activity_at', conversation.last_activity_at,
        'participant', jsonb_build_object('id', profile.id, 'first_name', profile.first_name,
            'age', extract(year from age((current_timestamp at time zone 'UTC')::date, profile.date_of_birth))::integer,
            'job_title', profile.job_title, 'goal', profile.goal, 'city', profile.city, 'interests', private.profile_interests(profile.id)),
        'last_message', (select private.message_projection(message) from private.messages message
            where conversation_id = conversation.id order by created_at desc, id desc limit 1))
    from public.profiles profile where profile.id = case when person = conversation.participant_one_id
        then conversation.participant_two_id else conversation.participant_one_id end;
$$;

commit;
