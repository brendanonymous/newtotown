begin;

-- One server-owned pilot configuration. Clients can read but never change it.
create table public.pilot_features (
    id boolean primary key default true check (id),
    photo_review_required boolean not null default false
);
alter table public.pilot_features enable row level security;
revoke all on public.pilot_features from anon, authenticated;
grant select on public.pilot_features to authenticated;
grant all on public.pilot_features to service_role;
create policy "Signed-in users read pilot features" on public.pilot_features
    for select to authenticated using (true);
insert into public.pilot_features (id, photo_review_required) values (true, false);

-- Reserved for trusted moderation/review operations; no client writes.
-- Approval records the exact Storage objects and versions, not just the person.
create table public.profile_access (
    user_id uuid primary key references auth.users(id) on delete cascade,
    suspended boolean not null default false,
    rejected boolean not null default false,
    approved_profile_id uuid,
    approved_profile_updated_at timestamptz,
    approved_selfie_id uuid,
    approved_selfie_updated_at timestamptz,
    check (num_nonnulls(approved_profile_id, approved_profile_updated_at,
        approved_selfie_id, approved_selfie_updated_at) in (0, 4))
);
alter table public.profile_access enable row level security;
revoke all on public.profile_access from anon, authenticated;
grant select on public.profile_access to authenticated;
grant all on public.profile_access to service_role;
create policy "Owners read profile access" on public.profile_access
    for select to authenticated using ((select auth.uid()) = user_id);

-- A self-only eligibility primitive for the discovery feature to reuse server-side.
-- SECURITY INVOKER keeps profile, access-state, and Storage RLS in force.
-- This function does not publish profiles or grant access to anyone else's photos.
create function public.is_own_profile_discoverable() returns boolean
language sql stable security invoker set search_path = '' as $$
    select coalesce((
        select not coalesce(access.suspended, false)
            and not coalesce(access.rejected, false)
            and (
                not features.photo_review_required
                or (
                    profile_photo.id = access.approved_profile_id
                    and profile_photo.updated_at = access.approved_profile_updated_at
                    and selfie.id = access.approved_selfie_id
                    and selfie.updated_at = access.approved_selfie_updated_at
                )
            )
        from public.profiles as profile
        cross join public.pilot_features as features
        join storage.objects as profile_photo
            on profile_photo.bucket_id = 'private-photos'
            and profile_photo.name = profile.id::text || '/profile.jpg'
        left join storage.objects as selfie
            on selfie.bucket_id = 'private-photos'
            and selfie.name = profile.id::text || '/selfie.jpg'
        left join public.profile_access as access on access.user_id = profile.id
        where profile.id = (select auth.uid()) and features.id
    ), false);
$$;
revoke all on function public.is_own_profile_discoverable() from public, anon;
grant execute on function public.is_own_profile_discoverable() to authenticated;
commit;
