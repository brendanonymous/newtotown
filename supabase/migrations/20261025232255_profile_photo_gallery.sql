begin;

-- Keep the main photo's existing path; the selfie is never a profile-gallery slot.
drop policy "Owners read private photos" on storage.objects;
drop policy "Owners upload consented photos" on storage.objects;
drop policy "Owners replace consented photos" on storage.objects;
drop policy "Owners remove private photos" on storage.objects;

create policy "Owners read private photos" on storage.objects
    for select to authenticated using (
        bucket_id = 'private-photos'
        and name in (
            (select auth.uid())::text || '/profile.jpg',
            (select auth.uid())::text || '/profile-2.jpg',
            (select auth.uid())::text || '/profile-3.jpg',
            (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners upload consented photos" on storage.objects
    for insert to authenticated with check (
        bucket_id = 'private-photos'
        and name in (
            (select auth.uid())::text || '/profile.jpg',
            (select auth.uid())::text || '/profile-2.jpg',
            (select auth.uid())::text || '/profile-3.jpg',
            (select auth.uid())::text || '/selfie.jpg')
        and (exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
            or exists (select 1 from public.account_agreements where user_id = (select auth.uid()) and version = 'onboarding-v1'))
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners replace consented photos" on storage.objects
    for update to authenticated using (
        bucket_id = 'private-photos'
        and name in (
            (select auth.uid())::text || '/profile.jpg',
            (select auth.uid())::text || '/profile-2.jpg',
            (select auth.uid())::text || '/profile-3.jpg',
            (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    ) with check (
        bucket_id = 'private-photos'
        and name in (
            (select auth.uid())::text || '/profile.jpg',
            (select auth.uid())::text || '/profile-2.jpg',
            (select auth.uid())::text || '/profile-3.jpg',
            (select auth.uid())::text || '/selfie.jpg')
        and (exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
            or exists (select 1 from public.account_agreements where user_id = (select auth.uid()) and version = 'onboarding-v1'))
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners remove private photos" on storage.objects
    for delete to authenticated using (
        bucket_id = 'private-photos'
        and name in (
            (select auth.uid())::text || '/profile.jpg',
            (select auth.uid())::text || '/profile-2.jpg',
            (select auth.uid())::text || '/profile-3.jpg',
            (select auth.uid())::text || '/selfie.jpg')
    );

-- The Edge Functions supply already-authorized public profile IDs. This lookup
-- batches metadata only; clients cannot invoke it or list someone else's folder.
create function public.pilot_profile_photo_paths(people uuid[]) returns setof text
language plpgsql stable security invoker set search_path = '' as $$
begin
    if people is null or cardinality(people) > 70 or array_position(people, null) is not null then
        raise exception 'Invalid profile batch' using errcode = '22023';
    end if;
    return query
    select object.name
    from (select distinct unnest(people) as id) as person
    cross join lateral (values
        (person.id::text || '/profile.jpg', 1),
        (person.id::text || '/profile-2.jpg', 2),
        (person.id::text || '/profile-3.jpg', 3)
    ) as slot(path, position)
    join storage.objects as object on object.bucket_id = 'private-photos' and object.name = slot.path
    cross join public.pilot_features as features
    where features.id and (slot.position = 1 or not features.photo_review_required)
    order by person.id, slot.position;
end;
$$;
revoke all on function public.pilot_profile_photo_paths(uuid[]) from public, anon, authenticated;
grant execute on function public.pilot_profile_photo_paths(uuid[]) to service_role;

commit;
