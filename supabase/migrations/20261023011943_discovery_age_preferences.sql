begin;

alter table public.discovery_settings
    add column minimum_age integer not null default 18,
    add column maximum_age integer,
    add constraint discovery_age_range check (minimum_age >= 18 and (maximum_age is null or maximum_age >= minimum_age));

create function private.discovery_age_allowed(person uuid, target uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
    select extract(year from age((current_timestamp at time zone 'UTC')::date, profile.date_of_birth)) >= coalesce(settings.minimum_age, 18)
        and (settings.maximum_age is null or extract(year from age((current_timestamp at time zone 'UTC')::date, profile.date_of_birth)) <= settings.maximum_age)
    from public.profiles profile
    left join public.discovery_settings settings on settings.user_id = person
    where profile.id = target;
$$;

create function public.pilot_discovery_preferences(person uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
    select jsonb_build_object('minimum_age', coalesce((select minimum_age from public.discovery_settings where user_id = person), 18),
        'maximum_age', (select maximum_age from public.discovery_settings where user_id = person));
$$;

create function public.pilot_discovery_save_preferences(person uuid, minimum_age integer, maximum_age integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
begin
    if minimum_age is null or minimum_age < 18 or (maximum_age is not null and maximum_age < minimum_age) then
        raise exception 'Invalid age range' using errcode = '22023';
    end if;
    -- Creating preferences never opts a new profile into discovery.
    insert into public.discovery_settings(user_id, minimum_age, maximum_age)
        values (person, minimum_age, maximum_age)
    on conflict (user_id) do update set minimum_age = excluded.minimum_age, maximum_age = excluded.maximum_age;
    return public.pilot_discovery_preferences(person);
end;
$$;

revoke all on function private.discovery_age_allowed(uuid, uuid),
    public.pilot_discovery_preferences(uuid), public.pilot_discovery_save_preferences(uuid, integer, integer)
    from public, anon, authenticated;
grant execute on function private.discovery_age_allowed(uuid, uuid),
    public.pilot_discovery_preferences(uuid), public.pilot_discovery_save_preferences(uuid, integer, integer)
    to service_role;

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
                    and private.discovery_age_allowed(person, profile.id)
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

commit;
