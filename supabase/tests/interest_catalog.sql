begin;

insert into auth.users(id) values
    ('62000000-0000-0000-0000-000000000001'),
    ('62000000-0000-0000-0000-000000000002');
insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a coffee buddy.', current_date - interval '30 years', 'Scottsdale', true
from auth.users where id::text like '62000000-%';

set local role service_role;
do $$
declare
    a uuid := '62000000-0000-0000-0000-000000000001';
    b uuid := '62000000-0000-0000-0000-000000000002';
    choices text[] := array['gun_range', 'combat_sports', 'tsls', 'dive_bars', 'diy', 'mogging', 'poker'];
    result jsonb;
begin
    result := public.pilot_interests_save(a, 'profile', choices);
    if jsonb_array_length(result->'profile_option_ids') <> 7 then
        raise exception 'Expanded catalog choices could not be saved together';
    end if;
    if not exists (
        select 1 from jsonb_array_elements(result->'categories') category,
            jsonb_array_elements(category->'options') option
        where option->>'id' = 'tsls' and option->>'title' = 'TSL''s'
    ) then raise exception 'Punctuated title or stable option ID lost in API projection'; end if;

    begin
        perform public.pilot_interests_save(a, 'profile', array['golf', 'gun_range', 'combat_sports', 'gym']);
        raise exception 'Expanded sports catalog bypassed three-choice limit';
    exception when invalid_parameter_value then null;
    end;
    if jsonb_array_length(public.pilot_interests(a)->'profile_option_ids') <> 7 then
        raise exception 'Rejected replacement lost expanded choices';
    end if;
    perform public.pilot_interests_save(b, 'profile', array['diy']);
    perform public.pilot_interests_save(a, 'filters', array['diy']);
    if not private.discovery_interests_allowed(a, b) then
        raise exception 'New interest did not participate in Discovery matching';
    end if;
end $$;
reset role;

-- Inactive catalog rows stay stored but cannot be offered or newly selected.
update private.interest_options set active = false where id = 'diy';
set local role service_role;
do $$
declare a uuid := '62000000-0000-0000-0000-000000000001'; result jsonb;
begin
    result := public.pilot_interests(a);
    if exists (
        select 1 from jsonb_array_elements(result->'categories') category,
            jsonb_array_elements(category->'options') option where option->>'id' = 'diy'
    ) or (result->'profile_option_ids') ? 'diy' or (result->'filter_option_ids') ? 'diy' then
        raise exception 'Inactive option remained exposed';
    end if;
    if not exists(select 1 from private.profile_interest_selections where user_id = a and option_id = 'diy') then
        raise exception 'Retirement deleted existing choices';
    end if;
    begin
        perform public.pilot_interests_save(a, 'filters', array['diy']);
        raise exception 'Inactive choice was selectable';
    exception when invalid_parameter_value then null;
    end;
end $$;
reset role;

update private.interest_options set active = true where id = 'diy';
set local role service_role;
do $$ declare result jsonb; begin
    result := public.pilot_interests('62000000-0000-0000-0000-000000000001');
    if not (result->'profile_option_ids') ? 'diy' or not (result->'filter_option_ids') ? 'diy' then
        raise exception 'Reactivating an option did not restore retained choices';
    end if;
end $$;
reset role;
rollback;
