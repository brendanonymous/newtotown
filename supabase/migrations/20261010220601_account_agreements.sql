begin;

-- Account-level acceptance survives sign-out/reinstall and may precede a profile.
-- Existing receipts are retained; no acceptance is fabricated for pilot members.
create table public.account_agreements (
    user_id uuid primary key references auth.users(id) on delete cascade,
    version text not null check (version = 'onboarding-v1'),
    accepted_at timestamptz not null default now()
);
alter table public.account_agreements enable row level security;
revoke all on public.account_agreements from anon, authenticated;
grant select on public.account_agreements to authenticated;
grant insert (user_id, version) on public.account_agreements to authenticated;
grant all on public.account_agreements to service_role;
create policy "Owners read account agreement" on public.account_agreements
    for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owners accept account agreement" on public.account_agreements
    for insert to authenticated with check ((select auth.uid()) = user_id);

-- Preserve old consent for older pilot clients while new clients accept up front.
drop policy "Owners upload consented photos" on storage.objects;
drop policy "Owners replace consented photos" on storage.objects;
create policy "Owners upload consented photos" on storage.objects
    for insert to authenticated with check (
        bucket_id = 'private-photos'
        and name in ((select auth.uid())::text || '/profile.jpg', (select auth.uid())::text || '/selfie.jpg')
        and (exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
            or exists (select 1 from public.account_agreements where user_id = (select auth.uid()) and version = 'onboarding-v1'))
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
        and (exists (select 1 from public.photo_consents where user_id = (select auth.uid()) and version = 'pilot-v1')
            or exists (select 1 from public.account_agreements where user_id = (select auth.uid()) and version = 'onboarding-v1'))
        and exists (select 1 from public.profiles where id = (select auth.uid()))
    );
commit;
