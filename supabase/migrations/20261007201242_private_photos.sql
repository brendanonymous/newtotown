begin;

create table public.photo_consents (
    user_id uuid primary key references auth.users(id) on delete cascade,
    version text not null check (version = 'pilot-v1'),
    accepted_at timestamptz not null default now()
);
alter table public.photo_consents enable row level security;
revoke all on public.photo_consents from anon, authenticated;
grant select on public.photo_consents to authenticated;
grant insert (user_id, version) on public.photo_consents to authenticated;
create policy "Owners read photo consent" on public.photo_consents
    for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owners accept photo consent" on public.photo_consents
    for insert to authenticated with check (
        (select auth.uid()) = user_id
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('private-photos', 'private-photos', false, 3145728, array['image/jpeg']);

-- Exactly two owner-scoped keys; no folder listing outside the caller's prefix.
create policy "Owners read private photos" on storage.objects
    for select to authenticated using (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners upload consented photos" on storage.objects
    for insert to authenticated with check (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners replace consented photos" on storage.objects
    for update to authenticated using (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    ) with check (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
        and exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
create policy "Owners remove private photos" on storage.objects
    for delete to authenticated using (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
    );
commit;
