begin;

create function private.activity_has_photo(person uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
    select exists (select 1 from storage.objects where bucket_id = 'private-photos'
        and name in (person::text || '/profile.jpg', person::text || '/profile-2.jpg', person::text || '/profile-3.jpg'));
$$;

-- Called on first v2 entry, including members created later by an older client.
-- Never synthesize a receipt, Looking For choices or guessed legacy replacements.
create function private.activity_initialize(person uuid) returns void
language plpgsql volatile security invoker set search_path = '' as $$
declare has_profile boolean;
begin
    perform 1 from auth.users where id = person for update;
    if not found then raise exception 'Account unavailable' using errcode = 'P0001'; end if;
    perform 1 from public.profiles where id = person for update;
    has_profile := found;
    if not exists (select 1 from private.profile_setup_progress where user_id = person) then
        if not has_profile and not exists (select 1 from public.account_agreements where user_id = person and version = 'onboarding-v1') then
            raise exception 'Agreement required' using errcode = 'P0001';
        end if;
        insert into private.profile_setup_progress(user_id,entry_kind,basics_complete,photos_complete,interests_complete,legacy_imported_at)
            values (person,case when has_profile then 'existing' else 'new' end,has_profile,
                has_profile and private.activity_has_photo(person),has_profile,now());
        if has_profile then
            insert into private.profile_activity_interests(user_id,interest_id)
                select person,old.option_id from private.profile_interest_selections old
                join private.interest_options legacy on legacy.id = old.option_id and legacy.active
                join private.activity_interests canonical on canonical.id = old.option_id and canonical.published and not canonical.age_restricted
                where old.user_id = person;
            insert into private.discovery_activity_filters(user_id,interest_id)
                select person,old.option_id from private.discovery_interest_filters old
                join private.interest_options legacy on legacy.id = old.option_id and legacy.active
                join private.activity_interests canonical on canonical.id = old.option_id and canonical.published and not canonical.age_restricted
                where old.user_id = person;
            update private.profile_setup_progress set filters_need_review = exists (
                select 1 from private.discovery_interest_filters old where old.user_id = person
                    and not exists (select 1 from private.discovery_activity_filters current
                        where current.user_id = person and current.interest_id = old.option_id))
                where user_id = person;
        end if;
    end if;
    -- Publication changes must not silently broaden an already saved hard filter.
    update private.profile_setup_progress set filters_need_review = true,
        selection_revision = selection_revision + 1, updated_at = now()
        where user_id = person and not filters_need_review and exists (
            select 1 from private.discovery_activity_filters filter
            join private.activity_interests interest on interest.id = filter.interest_id
            where filter.user_id = person and (not interest.published or interest.age_restricted));
end;
$$;

-- Edge handlers resolve the account from live Auth, then invoke these service-only RPCs.
-- Auth-row then profile-row locks cover progress before Basics and serialize replacements.
create function private.activity_check_revision(person uuid, expected_revision bigint) returns void
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_initialize(person);
    if expected_revision is null or expected_revision <> (
        select selection_revision from private.profile_setup_progress where user_id = person)
    then raise exception 'stale_selection' using errcode = '40001'; end if;
end;
$$;

create function private.activity_owner_state(person uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$
    select jsonb_build_object(
        'setup', to_jsonb(progress) - 'user_id',
        'has_photo', private.activity_has_photo(person),
        'category_ids', (select coalesce(jsonb_agg(choice.category_id order by category.sort_order),'[]'::jsonb)
            from private.profile_looking_for choice join private.looking_for_categories category on category.id = choice.category_id where choice.user_id = person),
        'priority_ids', (select coalesce(jsonb_agg(category_id order by priority_rank),'[]'::jsonb)
            from private.profile_looking_for where user_id = person and priority_rank is not null),
        'interest_ids', (select coalesce(jsonb_agg(selected.interest_id order by interest.sort_order),'[]'::jsonb)
            from private.profile_activity_interests selected join private.activity_interests interest on interest.id = selected.interest_id
            where selected.user_id = person and interest.published and not interest.age_restricted),
        'filter_ids', (select coalesce(jsonb_agg(selected.interest_id order by interest.sort_order),'[]'::jsonb)
            from private.discovery_activity_filters selected join private.activity_interests interest on interest.id = selected.interest_id
            where selected.user_id = person and interest.published and not interest.age_restricted),
        'unavailable_legacy_interest_ids', (select coalesce(jsonb_agg(old.option_id order by old.option_id),'[]'::jsonb)
            from private.profile_interest_selections old join private.interest_options legacy on legacy.id = old.option_id
            where old.user_id = person and (not legacy.active or not exists (
                select 1 from private.activity_interests interest where interest.id = old.option_id and interest.published and not interest.age_restricted)))
    ) from private.profile_setup_progress progress where progress.user_id = person;
$$;

create function public.activity_v2_owner(person uuid) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_initialize(person);
    return private.activity_owner_state(person);
end;
$$;

create function public.activity_v2_save_basics(person uuid, expected_revision bigint,
    name text, job text, bio text, birthday date) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
declare is_new_profile boolean; member_age integer;
begin
    perform private.activity_check_revision(person,expected_revision);
    is_new_profile := not exists (select 1 from public.profiles where id = person);
    if name is null or char_length(btrim(name)) not between 1 and 40
        or job is null or char_length(btrim(job)) not between 1 and 80
        or bio is null or char_length(btrim(bio)) not between 10 and 280
        or birthday is null or birthday + interval '18 years' > (current_timestamp at time zone 'UTC')::date
    then raise exception 'Invalid profile basics' using errcode = '22023'; end if;
    insert into public.profiles(id,first_name,job_title,goal,date_of_birth,city,platonic_agreement)
        values (person,btrim(name),btrim(job),btrim(bio),birthday,'Scottsdale',true)
        on conflict (id) do update set first_name=excluded.first_name,job_title=excluded.job_title,
            goal=excluded.goal,date_of_birth=excluded.date_of_birth;
    if is_new_profile and exists (select 1 from private.profile_setup_progress where user_id=person and entry_kind='new') then
        member_age := extract(year from age((current_timestamp at time zone 'UTC')::date,birthday));
        insert into public.discovery_settings(user_id,minimum_age,maximum_age)
            values (person,greatest(18,member_age-12),member_age+12) on conflict (user_id) do nothing;
    end if;
    update private.profile_setup_progress set basics_complete=true,selection_revision=selection_revision+1,updated_at=now() where user_id=person;
    return private.activity_owner_state(person);
end;
$$;

create function public.activity_v2_complete_photos(person uuid, expected_revision bigint) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_check_revision(person,expected_revision);
    if not exists(select 1 from public.profiles where id=person) or not private.activity_has_photo(person) then
        raise exception 'Saved profile photo required' using errcode='22023';
    end if;
    update private.profile_setup_progress set photos_complete=true,selection_revision=selection_revision+1,updated_at=now() where user_id=person;
    return private.activity_owner_state(person);
end;
$$;

create function public.activity_v2_save_looking_for(person uuid, expected_revision bigint,
    category_ids text[], priority_ids text[]) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_check_revision(person,expected_revision);
    if not exists(select 1 from public.profiles where id=person) then raise exception 'Profile unavailable' using errcode='P0001'; end if;
    if category_ids is null or cardinality(category_ids) not between 1 and 5
        or array_position(category_ids,null) is not null
        or cardinality(category_ids) <> (select count(distinct id) from unnest(category_ids) id)
        or exists(select 1 from unnest(category_ids) selected(id) where not exists(select 1 from private.looking_for_categories where id=selected.id))
        or priority_ids is null or cardinality(priority_ids)>2 or array_position(priority_ids,null) is not null
        or cardinality(priority_ids) <> (select count(distinct id) from unnest(priority_ids) id)
        or not priority_ids <@ category_ids
    then raise exception 'Invalid Looking For choices' using errcode='22023'; end if;
    delete from private.profile_looking_for where user_id=person;
    insert into private.profile_looking_for(user_id,category_id,priority_rank)
        select person,id,array_position(priority_ids,id)::smallint from unnest(category_ids) id;
    update private.profile_setup_progress set looking_for_complete=true,
        completed_at=case when basics_complete and photos_complete and interests_complete and private.activity_has_photo(person)
            then coalesce(completed_at,now()) else completed_at end,
        selection_revision=selection_revision+1,updated_at=now() where user_id=person;
    return private.activity_owner_state(person);
end;
$$;

-- Shared validation has no 15-choice/per-category limit. The API's 64 KiB bound
-- and canonical set constrain input; duplicates and unavailable IDs are errors.
create function private.activity_validate_interests(interest_ids text[]) returns void
language plpgsql stable security invoker set search_path = '' as $$
begin
    if interest_ids is null or array_position(interest_ids,null) is not null
        or cardinality(interest_ids) <> (select count(distinct id) from unnest(interest_ids) id)
        or exists (select 1 from unnest(interest_ids) selected(id) where not exists (
            select 1 from private.activity_interests where id=selected.id and published and not age_restricted))
    then raise exception 'Invalid interests' using errcode='22023'; end if;
end;
$$;

create function public.activity_v2_save_interests(person uuid, expected_revision bigint,
    interest_ids text[], complete_setup boolean) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_check_revision(person,expected_revision);
    perform private.activity_validate_interests(interest_ids);
    if complete_setup is null then raise exception 'Completion flag required' using errcode='22023'; end if;
    if not exists(select 1 from public.profiles where id=person) then raise exception 'Profile unavailable' using errcode='P0001'; end if;
    if complete_setup and not exists (select 1 from private.profile_setup_progress where user_id=person and
        (completed_at is not null or (basics_complete and photos_complete and looking_for_complete
            and private.activity_has_photo(person) and exists(select 1 from private.profile_looking_for where user_id=person))))
    then raise exception 'Complete earlier setup steps' using errcode='22023'; end if;
    delete from private.profile_activity_interests where user_id=person;
    insert into private.profile_activity_interests(user_id,interest_id) select person,unnest(interest_ids);
    update private.profile_setup_progress set interests_complete=interests_complete or complete_setup,
        completed_at=case when complete_setup then coalesce(completed_at,now()) else completed_at end,
        selection_revision=selection_revision+1,updated_at=now() where user_id=person;
    return private.activity_owner_state(person);
end;
$$;

create function public.activity_v2_save_filters(person uuid, expected_revision bigint, interest_ids text[]) returns jsonb
language plpgsql volatile security invoker set search_path = '' as $$
begin
    perform private.activity_check_revision(person,expected_revision);
    perform private.activity_validate_interests(interest_ids);
    if not exists(select 1 from public.profiles where id=person) then raise exception 'Profile unavailable' using errcode='P0001'; end if;
    delete from private.discovery_activity_filters where user_id=person;
    insert into private.discovery_activity_filters(user_id,interest_id) select person,unnest(interest_ids);
    update private.profile_setup_progress set filters_need_review=false,selection_revision=selection_revision+1,updated_at=now() where user_id=person;
    return private.activity_owner_state(person);
end;
$$;

revoke all on function private.activity_has_photo(uuid), private.activity_initialize(uuid),
    private.activity_check_revision(uuid,bigint), private.activity_owner_state(uuid),
    private.activity_validate_interests(text[]), public.activity_v2_owner(uuid),
    public.activity_v2_save_basics(uuid,bigint,text,text,text,date), public.activity_v2_complete_photos(uuid,bigint),
    public.activity_v2_save_looking_for(uuid,bigint,text[],text[]), public.activity_v2_save_interests(uuid,bigint,text[],boolean),
    public.activity_v2_save_filters(uuid,bigint,text[]) from public,anon,authenticated;
grant execute on function private.activity_has_photo(uuid), private.activity_initialize(uuid),
    private.activity_check_revision(uuid,bigint), private.activity_owner_state(uuid),
    private.activity_validate_interests(text[]), public.activity_v2_owner(uuid),
    public.activity_v2_save_basics(uuid,bigint,text,text,text,date), public.activity_v2_complete_photos(uuid,bigint),
    public.activity_v2_save_looking_for(uuid,bigint,text[],text[]), public.activity_v2_save_interests(uuid,bigint,text[],boolean),
    public.activity_v2_save_filters(uuid,bigint,text[]) to service_role;
-- Basics is server-authenticated too. Members retain their existing self-only grants.
grant select,insert on public.profiles to service_role;
grant update(first_name,job_title,goal,date_of_birth) on public.profiles to service_role;
grant usage on schema auth to service_role;
grant select,update(id) on auth.users to service_role;

-- Snapshot existing selections now; first entry handles any later legacy accounts.
do $$ declare member_id uuid; begin
    for member_id in select id from public.profiles order by id loop
        perform private.activity_initialize(member_id);
    end loop;
end $$;

commit;
