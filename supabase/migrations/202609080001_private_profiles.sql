begin;

-- Keep this onboarding table private. Future discovery must expose only approved,
-- public fields; date_of_birth must never be included in that projection.
create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    first_name text not null check (char_length(btrim(first_name)) between 1 and 40),
    job_title text not null check (char_length(btrim(job_title)) between 1 and 80),
    goal text not null check (char_length(btrim(goal)) between 10 and 280),
    date_of_birth date not null check (
        date_of_birth + interval '18 years' <= (current_timestamp at time zone 'UTC')::date
    ),
    city text not null default 'Scottsdale' check (city = 'Scottsdale'),
    platonic_agreement boolean not null check (platonic_agreement),
    verification_status text not null default 'unsubmitted'
        check (verification_status in ('unsubmitted', 'pending', 'approved', 'rejected')),
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
    on public.profiles to authenticated;
grant update (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
    on public.profiles to authenticated;

create policy "Owners read their profile" on public.profiles
    for select to authenticated using ((select auth.uid()) = id);
create policy "Owners create their profile" on public.profiles
    for insert to authenticated with check ((select auth.uid()) = id);
create policy "Owners edit their profile" on public.profiles
    for update to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

-- No client grants allow changing verification_status, created_at, or deleting
-- profiles. Account deletion will be a separate authenticated server operation.
commit;
