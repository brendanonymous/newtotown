begin;

-- Moderation data is never exposed through the client Data API.
create table private.profile_reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references public.profiles(id) on delete cascade,
    reported_id uuid not null references public.profiles(id) on delete cascade,
    reason text not null check (reason in ('unwanted_contact', 'inappropriate_content', 'non_platonic', 'spam', 'other')),
    details text check (details is null or char_length(details) <= 1000),
    client_report_id uuid not null,
    created_at timestamptz not null default clock_timestamp(),
    status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
    constraint reports_other_profile check (reporter_id <> reported_id),
    constraint reports_retry_key unique (reporter_id, client_report_id)
);
create index reports_target on private.profile_reports(reported_id);
create index reports_pending on private.profile_reports(created_at, id) where status = 'pending';
alter table private.profile_reports enable row level security;
revoke all on private.profile_reports from public, anon, authenticated, service_role;
grant select, insert on private.profile_reports to service_role;
grant update (status) on private.profile_reports to service_role;

-- Only the Edge handler supplies person after resolving a live Auth identity.
-- Recorded mutual connections remain reportable if visibility or blocking changes.
create function public.pilot_report_profile(person uuid, target uuid, report_reason text, report_details text, retry_id uuid)
returns jsonb language plpgsql volatile security invoker set search_path = '' as $$
declare report private.profile_reports;
begin
    if person is null or target is null or person = target or retry_id is null
        or report_reason is null or report_reason not in ('unwanted_contact', 'inappropriate_content', 'non_platonic', 'spam', 'other')
        or char_length(report_details) > 1000 then
        raise exception 'Invalid report' using errcode = '22023';
    end if;
    if not exists (select 1 from public.connection_decisions
            where user_id = person and target_id = target and choice = 'connect')
        or not exists (select 1 from public.connection_decisions
            where user_id = target and target_id = person and choice = 'connect') then
        raise exception 'Connection unavailable' using errcode = 'P0001';
    end if;
    insert into private.profile_reports(reporter_id, reported_id, reason, details, client_report_id)
        values (person, target, report_reason, report_details, retry_id)
        on conflict (reporter_id, client_report_id) do nothing;
    select * into strict report from private.profile_reports
        where reporter_id = person and client_report_id = retry_id;
    if report.reported_id <> target or report.reason <> report_reason or report.details is distinct from report_details then
        raise exception 'Retry conflict' using errcode = '23505';
    end if;
    return jsonb_build_object('id', report.id);
end;
$$;
revoke all on function public.pilot_report_profile(uuid, uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.pilot_report_profile(uuid, uuid, text, text, uuid) to service_role;

commit;
