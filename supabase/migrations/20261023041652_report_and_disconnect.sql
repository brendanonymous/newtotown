begin;

-- A confirmed report now also prevents further contact for this pair.
create or replace function public.pilot_report_profile(person uuid, target uuid, report_reason text, report_details text, retry_id uuid)
returns jsonb language plpgsql volatile security invoker set search_path = '' as $$
declare report private.profile_reports;
begin
    if person is null or target is null or person = target or retry_id is null
        or report_reason is null or report_reason not in ('unwanted_contact', 'inappropriate_content', 'non_platonic', 'spam', 'other')
        or char_length(report_details) > 1000 then
        raise exception 'Invalid report' using errcode = '22023';
    end if;
    perform private.lock_messaging_pair(person, target);
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
    -- Same transaction and pair lock as messaging: either both changes commit or neither does.
    perform public.pilot_discovery_block(person, target);
    return jsonb_build_object('id', report.id);
end;
$$;

commit;
