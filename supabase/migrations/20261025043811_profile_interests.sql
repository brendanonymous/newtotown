begin;

create table private.interest_categories (
    id text primary key,
    title text not null,
    sort_order integer not null unique
);
create table private.interest_options (
    id text primary key,
    category_id text not null references private.interest_categories(id),
    title text not null,
    sort_order integer not null,
    active boolean not null default true,
    unique (category_id, id),
    unique (category_id, sort_order)
);
create table private.profile_interest_selections (
    user_id uuid not null references public.profiles(id) on delete cascade,
    category_id text not null,
    option_id text not null,
    primary key (user_id, option_id),
    foreign key (category_id, option_id) references private.interest_options(category_id, id)
);
create table private.discovery_interest_filters (
    user_id uuid not null references public.profiles(id) on delete cascade,
    category_id text not null,
    option_id text not null,
    primary key (user_id, option_id),
    foreign key (category_id, option_id) references private.interest_options(category_id, id)
);
create index profile_interest_options on private.profile_interest_selections(option_id, user_id);
create index discovery_interest_options on private.discovery_interest_filters(option_id, user_id);

alter table private.interest_categories enable row level security;
alter table private.interest_options enable row level security;
alter table private.profile_interest_selections enable row level security;
alter table private.discovery_interest_filters enable row level security;
revoke all on private.interest_categories, private.interest_options,
    private.profile_interest_selections, private.discovery_interest_filters from public, anon, authenticated;
grant select on private.interest_categories, private.interest_options to service_role;
grant select, insert, delete on private.profile_interest_selections, private.discovery_interest_filters to service_role;
-- SELECT FOR UPDATE needs UPDATE privilege; members receive no new profile privileges.
grant update(id) on public.profiles to service_role;

insert into private.interest_categories(id, title, sort_order) values
    ('sports_fitness', 'Sports & fitness', 0),
    ('outdoors', 'Outdoors', 1),
    ('food_drinks', 'Food & drinks', 2),
    ('arts_entertainment', 'Arts & entertainment', 3),
    ('social_hobbies', 'Social & hobbies', 4);

insert into private.interest_options(id, category_id, title, sort_order) values
    ('golf', 'sports_fitness', 'Golf', 0),
    ('pickleball', 'sports_fitness', 'Pickleball', 1),
    ('gym', 'sports_fitness', 'Gym', 2),
    ('running', 'sports_fitness', 'Running', 3),
    ('basketball', 'sports_fitness', 'Basketball', 4),
    ('tennis', 'sports_fitness', 'Tennis', 5),
    ('hiking', 'outdoors', 'Hiking', 0),
    ('camping', 'outdoors', 'Camping', 1),
    ('cycling', 'outdoors', 'Cycling', 2),
    ('fishing', 'outdoors', 'Fishing', 3),
    ('kayaking', 'outdoors', 'Kayaking', 4),
    ('dog_walks', 'outdoors', 'Dog walks', 5),
    ('coffee', 'food_drinks', 'Coffee', 0),
    ('craft_beer', 'food_drinks', 'Craft beer', 1),
    ('dining_out', 'food_drinks', 'Dining out', 2),
    ('cooking', 'food_drinks', 'Cooking', 3),
    ('barbecue', 'food_drinks', 'Barbecue', 4),
    ('wine', 'food_drinks', 'Wine', 5),
    ('live_music', 'arts_entertainment', 'Live music', 0),
    ('movies', 'arts_entertainment', 'Movies', 1),
    ('comedy', 'arts_entertainment', 'Comedy', 2),
    ('museums', 'arts_entertainment', 'Museums', 3),
    ('photography', 'arts_entertainment', 'Photography', 4),
    ('theater', 'arts_entertainment', 'Theater', 5),
    ('board_games', 'social_hobbies', 'Board games', 0),
    ('video_games', 'social_hobbies', 'Video games', 1),
    ('volunteering', 'social_hobbies', 'Volunteering', 2),
    ('professional_networking', 'social_hobbies', 'Professional networking', 3),
    ('reading', 'social_hobbies', 'Reading', 4),
    ('cars', 'social_hobbies', 'Cars', 5);

-- These functions are invoked only by the authenticated Edge Function's service role.
-- They cannot be called by a member supplying a different owner ID.
create function public.pilot_interests(person uuid) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
begin
    if not exists (select 1 from public.profiles where id = person) then
        raise exception 'Profile unavailable' using errcode = 'P0001';
    end if;
    return jsonb_build_object(
        'categories', (select jsonb_agg(jsonb_build_object('id', category.id, 'title', category.title,
            'options', (select coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'title', option.title)
                order by option.sort_order), '[]'::jsonb)
                from private.interest_options option where option.category_id = category.id and option.active))
            order by category.sort_order) from private.interest_categories category),
        'profile_option_ids', (select coalesce(jsonb_agg(selection.option_id order by selection.option_id), '[]'::jsonb)
            from private.profile_interest_selections selection
            join private.interest_options option on option.id = selection.option_id and option.active where selection.user_id = person),
        'filter_option_ids', (select coalesce(jsonb_agg(selection.option_id order by selection.option_id), '[]'::jsonb)
            from private.discovery_interest_filters selection
            join private.interest_options option on option.id = selection.option_id and option.active where selection.user_id = person)
    );
end;
$$;

create function public.pilot_interests_save(person uuid, selection_kind text, option_ids text[]) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    -- Serialize complete replacements for this owner, including concurrent edits.
    perform 1 from public.profiles where id = person for update;
    if not found then raise exception 'Profile unavailable' using errcode = 'P0001'; end if;
    if selection_kind is null or selection_kind not in ('profile', 'filters') or option_ids is null
        or cardinality(option_ids) > 15
        or cardinality(option_ids) <> (select count(distinct id) from unnest(option_ids) id)
        or exists (select 1 from unnest(option_ids) selected(id) where not exists (
            select 1 from private.interest_options option where option.id = selected.id and option.active))
        or exists (select 1 from private.interest_options where id = any(option_ids) group by category_id having count(*) > 3)
    then raise exception 'Invalid interests' using errcode = '22023'; end if;
    if selection_kind = 'profile' then
        delete from private.profile_interest_selections where user_id = person;
        insert into private.profile_interest_selections(user_id, category_id, option_id)
            select person, category_id, id from private.interest_options where id = any(option_ids);
    else
        delete from private.discovery_interest_filters where user_id = person;
        insert into private.discovery_interest_filters(user_id, category_id, option_id)
            select person, category_id, id from private.interest_options where id = any(option_ids);
    end if;
    return public.pilot_interests(person);
end;
$$;

-- Only attach this public-field projection after discovery/messaging eligibility passes.
create function private.profile_interests(person uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
    select coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'category_id', option.category_id, 'title', option.title)
        order by category.sort_order, option.sort_order), '[]'::jsonb)
    from private.profile_interest_selections selection
    join private.interest_options option on option.id = selection.option_id and option.active
    join private.interest_categories category on category.id = option.category_id
    where selection.user_id = person;
$$;

create function private.discovery_interests_allowed(person uuid, target uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
    select not exists (
        select 1 from private.discovery_interest_filters filter
        join private.interest_options option on option.id = filter.option_id and option.active where filter.user_id = person
    ) or exists (
        select 1 from private.discovery_interest_filters filter
        join private.profile_interest_selections selection on selection.option_id = filter.option_id and selection.user_id = target
        join private.interest_options option on option.id = filter.option_id and option.active where filter.user_id = person
    );
$$;

revoke all on function public.pilot_interests(uuid), public.pilot_interests_save(uuid,text,text[]),
    private.profile_interests(uuid), private.discovery_interests_allowed(uuid,uuid) from public, anon, authenticated;
grant execute on function public.pilot_interests(uuid), public.pilot_interests_save(uuid,text,text[]),
    private.profile_interests(uuid), private.discovery_interests_allowed(uuid,uuid) to service_role;

create or replace function public.pilot_discovery_feed(person uuid) returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare state text := private.discovery_state(person);
begin
    return jsonb_build_object(
        'state', state,
        'visible', coalesce((select visible from public.discovery_settings where user_id = person), false),
        'candidates', case when state = 'ready' then coalesce((
            select jsonb_agg(to_jsonb(candidate)) from (
                select profile.id, profile.first_name, profile.job_title, profile.goal, profile.city, private.profile_interests(profile.id) as interests
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
                select profile.id, profile.first_name, profile.job_title, profile.goal, profile.city, private.profile_interests(profile.id) as interests
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
            'job_title', profile.job_title, 'goal', profile.goal, 'city', profile.city, 'interests', private.profile_interests(profile.id)),
        'last_message', (select private.message_projection(message) from private.messages message
            where conversation_id = conversation.id order by created_at desc, id desc limit 1))
    from public.profiles profile where profile.id = case when person = conversation.participant_one_id
        then conversation.participant_two_id else conversation.participant_one_id end;
$$;

commit;
