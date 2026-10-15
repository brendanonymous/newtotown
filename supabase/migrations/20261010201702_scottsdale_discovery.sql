begin;

create table public.discovery_settings (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    visible boolean not null default false,
    consent_version text not null default 'discovery-v1' check (consent_version = 'discovery-v1'),
    accepted_at timestamptz not null default now()
);
create table public.connection_decisions (
    user_id uuid references public.profiles(id) on delete cascade,
    target_id uuid references public.profiles(id) on delete cascade,
    choice text not null check (choice in ('connect', 'pass')),
    created_at timestamptz not null default now(),
    primary key (user_id, target_id), check (user_id <> target_id)
);
create index connection_decisions_target on public.connection_decisions(target_id, user_id);
create table public.profile_blocks (
    user_id uuid references public.profiles(id) on delete cascade,
    target_id uuid references public.profiles(id) on delete cascade,
    primary key (user_id, target_id), check (user_id <> target_id)
);
create index profile_blocks_target on public.profile_blocks(target_id, user_id);

alter table public.discovery_settings enable row level security;
alter table public.connection_decisions enable row level security;
alter table public.profile_blocks enable row level security;
revoke all on public.discovery_settings, public.connection_decisions, public.profile_blocks from anon, authenticated;
grant select on public.discovery_settings, public.connection_decisions, public.profile_blocks to authenticated;
grant all on public.discovery_settings, public.connection_decisions, public.profile_blocks to service_role;
create policy "Owners read discovery settings" on public.discovery_settings
    for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owners read outgoing decisions" on public.connection_decisions
    for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owners read outgoing blocks" on public.profile_blocks
    for select to authenticated using ((select auth.uid()) = user_id);

-- Internal helpers are outside the Data API. Only the trusted Edge Function role
-- can query other profiles. Public RPCs below are SECURITY INVOKER and service-only.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private, public, storage to service_role;
grant usage on schema private to authenticated;
grant select on public.profiles, public.profile_access, public.pilot_features,
    public.photo_consents, storage.objects to service_role;

create function private.photo_eligibility(person uuid) returns text
language sql stable security invoker set search_path = '' as $$
    select case
        when not exists (select 1 from public.profiles where id = person) then 'needs_profile'
        when exists (select 1 from public.profile_access where user_id = person and (suspended or rejected)) then 'restricted'
        when not exists (select 1 from storage.objects where bucket_id = 'private-photos' and name = person::text || '/profile.jpg') then 'needs_photo'
        when not exists (select 1 from public.pilot_features where id) then 'needs_review'
        when exists (select 1 from public.pilot_features where id and photo_review_required)
            and not exists (
                select 1 from public.profile_access access
                join storage.objects photo on photo.id = access.approved_profile_id
                    and photo.updated_at = access.approved_profile_updated_at
                    and photo.bucket_id = 'private-photos' and photo.name = person::text || '/profile.jpg'
                join storage.objects selfie on selfie.id = access.approved_selfie_id
                    and selfie.updated_at = access.approved_selfie_updated_at
                    and selfie.bucket_id = 'private-photos' and selfie.name = person::text || '/selfie.jpg'
                where access.user_id = person
            ) then 'needs_review'
        else 'ready'
    end;
$$;

-- Reuse the same review/moderation logic for the self-only flag primitive.
-- Invoker RLS means authenticated callers can evaluate only their own profile.
create or replace function public.is_own_profile_discoverable() returns boolean
language sql stable security invoker set search_path = '' as $$
    select private.photo_eligibility((select auth.uid())) = 'ready';
$$;

create function private.discovery_state(person uuid) returns text
language plpgsql stable security invoker set search_path = '' as $$
declare eligibility text := private.photo_eligibility(person);
begin
    if eligibility in ('needs_profile', 'restricted') then return eligibility; end if;
    if not exists (select 1 from public.discovery_settings where user_id = person and visible) then return 'hidden'; end if;
    return eligibility;
end;
$$;

create function private.discovery_pair_allowed(person uuid, target uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
    select person <> target
        and private.discovery_state(person) = 'ready'
        and private.discovery_state(target) = 'ready'
        and not exists (select 1 from public.profile_blocks
            where (user_id = person and target_id = target) or (user_id = target and target_id = person));
$$;

create function public.pilot_discovery_feed(person uuid) returns jsonb
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
                order by greatest(outgoing.created_at, incoming.created_at) desc, profile.id limit 50
            ) connection
        ), '[]'::jsonb) else '[]'::jsonb end
    );
end;
$$;

create function public.pilot_discovery_visibility(person uuid, enabled boolean) returns void
language plpgsql security invoker set search_path = '' as $$
begin
    if not exists (select 1 from public.profiles where id = person) then
        raise exception 'Profile unavailable' using errcode = 'P0001';
    end if;
    if enabled then
        insert into public.discovery_settings (user_id, visible, accepted_at)
            values (person, true, clock_timestamp())
            on conflict (user_id) do update set visible = true, accepted_at = excluded.accepted_at;
    else
        update public.discovery_settings set visible = false where user_id = person;
    end if;
end;
$$;

create function public.pilot_discovery_decide(person uuid, target uuid, decision text) returns void
language plpgsql security invoker set search_path = '' as $$
declare previous text;
begin
    if decision not in ('connect', 'pass') or decision is null
        or not private.discovery_pair_allowed(person, target) then
        raise exception 'Profile unavailable' using errcode = 'P0001';
    end if;
    -- Immutable decisions make a lost-response retry safe. Reciprocal connects
    -- define a match; no mutable match rows or race-prone match creation are needed.
    insert into public.connection_decisions (user_id, target_id, choice)
        values (person, target, decision) on conflict do nothing;
    select choice into previous from public.connection_decisions where user_id = person and target_id = target;
    if previous <> decision then raise exception 'Decision already recorded' using errcode = 'P0001'; end if;
end;
$$;

create function public.pilot_discovery_block(person uuid, target uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
    if person = target or not exists (select 1 from public.profiles where id = person)
        or not exists (select 1 from public.profiles where id = target) then
        raise exception 'Profile unavailable' using errcode = 'P0001';
    end if;
    insert into public.profile_blocks (user_id, target_id) values (person, target) on conflict do nothing;
end;
$$;

revoke all on function private.photo_eligibility(uuid), private.discovery_state(uuid), private.discovery_pair_allowed(uuid, uuid)
    from public, anon, authenticated;
grant execute on function private.photo_eligibility(uuid) to authenticated, service_role;
grant execute on function private.discovery_state(uuid), private.discovery_pair_allowed(uuid, uuid) to service_role;
revoke all on function public.pilot_discovery_feed(uuid), public.pilot_discovery_visibility(uuid, boolean),
    public.pilot_discovery_decide(uuid, uuid, text), public.pilot_discovery_block(uuid, uuid) from public, anon, authenticated;
grant execute on function public.pilot_discovery_feed(uuid), public.pilot_discovery_visibility(uuid, boolean),
    public.pilot_discovery_decide(uuid, uuid, text), public.pilot_discovery_block(uuid, uuid) to service_role;
commit;
