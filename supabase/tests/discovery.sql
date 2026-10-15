begin;
insert into auth.users (id) values
    ('00000000-0000-0000-0000-000000000021'),
    ('00000000-0000-0000-0000-000000000022'),
    ('00000000-0000-0000-0000-000000000023');
insert into public.profiles (id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true
from auth.users where id in ('00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000023');
insert into storage.objects (bucket_id, name)
select 'private-photos', id::text || '/profile.jpg' from public.profiles where id::text like '00000000-0000-0000-0000-00000000002%';
update public.pilot_features set photo_review_required = false;
set local role service_role;
do $$
declare a uuid := '00000000-0000-0000-0000-000000000021';
    b uuid := '00000000-0000-0000-0000-000000000022';
    c uuid := '00000000-0000-0000-0000-000000000023';
    feed jsonb;
begin
    feed := public.pilot_discovery_feed(a);
    if feed->>'state' <> 'hidden' or jsonb_array_length(feed->'candidates') <> 0 then raise exception 'Hidden caller sees profiles'; end if;
    perform public.pilot_discovery_visibility(a, true);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 then raise exception 'Non-consenting candidates exposed'; end if;
    perform public.pilot_discovery_visibility(b, true);
    perform public.pilot_discovery_visibility(c, true);
    feed := public.pilot_discovery_feed(a);
    if jsonb_array_length(feed->'candidates') <> 2 then raise exception 'Eligible candidates missing'; end if;
    if (feed->'candidates'->0) ? 'date_of_birth' or (feed->'candidates'->0) ? 'verification_status' then raise exception 'Private projection exposed'; end if;
    perform public.pilot_discovery_decide(a, b, 'connect');
    perform public.pilot_discovery_decide(a, b, 'connect');
    if (select count(*) from public.connection_decisions where user_id = a and target_id = b) <> 1 then raise exception 'Retry duplicated a decision'; end if;
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 0 then raise exception 'One-sided connect matched'; end if;
    perform public.pilot_discovery_decide(b, a, 'connect');
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 1 or jsonb_array_length(public.pilot_discovery_feed(b)->'matches') <> 1 then raise exception 'Mutual connect did not match'; end if;
    perform public.pilot_discovery_decide(a, c, 'pass');
    perform public.pilot_discovery_decide(c, a, 'connect');
    if jsonb_array_length(public.pilot_discovery_feed(a)->'candidates') <> 0 or jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 1 then raise exception 'Pass ignored'; end if;
    begin
        perform public.pilot_discovery_decide(a, c, 'connect');
        raise exception 'Immutable choice was changed';
    exception when sqlstate 'P0001' then
        if sqlerrm = 'Immutable choice was changed' then raise; end if;
    end;
    begin
        perform public.pilot_discovery_decide(a, a, 'connect');
        raise exception 'Self connection allowed';
    exception when sqlstate 'P0001' then
        if sqlerrm = 'Self connection allowed' then raise; end if;
    end;
    perform public.pilot_discovery_visibility(b, false);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 0 then raise exception 'Hidden connection exposed'; end if;
    if public.pilot_discovery_feed(b)->>'state' <> 'hidden' then raise exception 'Caller could not hide'; end if;
    perform public.pilot_discovery_visibility(b, true);
    perform public.pilot_discovery_block(b, a);
    if jsonb_array_length(public.pilot_discovery_feed(a)->'matches') <> 0 or jsonb_array_length(public.pilot_discovery_feed(b)->'matches') <> 0 then raise exception 'Block did not filter both directions'; end if;
    begin
        perform public.pilot_discovery_decide(a, b, 'connect');
        raise exception 'Blocked connection allowed';
    exception when sqlstate 'P0001' then
        if sqlerrm = 'Blocked connection allowed' then raise; end if;
    end;
    insert into public.profile_access (user_id, suspended) values (c, true);
    if public.pilot_discovery_feed(c)->>'state' <> 'restricted' then raise exception 'Suspended caller not restricted'; end if;
    if private.discovery_pair_allowed(a, c) then raise exception 'Suspended candidate eligible'; end if;
    update public.pilot_features set photo_review_required = true;
    if public.pilot_discovery_feed(a)->>'state' <> 'needs_review' then raise exception 'Review flag bypassed'; end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
do $$ begin
    if (select count(*) from public.discovery_settings) <> 1 then raise exception 'Other visibility row exposed'; end if;
    if (select count(*) from public.connection_decisions) <> 2 then raise exception 'Incoming decisions exposed'; end if;
    if exists (select 1 from public.profile_blocks) then raise exception 'Incoming block exposed'; end if;
    if private.photo_eligibility('00000000-0000-0000-0000-000000000022') <> 'needs_profile' then raise exception 'Eligibility helper bypassed RLS'; end if;
    begin
        perform public.pilot_discovery_feed('00000000-0000-0000-0000-000000000022');
        raise exception 'Client impersonated caller';
    exception when insufficient_privilege then null; end;
    begin
        insert into public.connection_decisions (user_id, target_id, choice) values (auth.uid(), '00000000-0000-0000-0000-000000000023', 'connect');
        raise exception 'Direct decision write bypassed server';
    exception when insufficient_privilege then null; end;
    begin
        update public.discovery_settings set visible = true;
        raise exception 'Direct visibility write bypassed consent';
    exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
    begin
        perform public.pilot_discovery_feed('00000000-0000-0000-0000-000000000021');
        raise exception 'Anonymous feed permitted';
    exception when insufficient_privilege then null; end;
end $$;
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-000000000021';
do $$ begin
    if exists (select 1 from public.discovery_settings where user_id = '00000000-0000-0000-0000-000000000021')
        or exists (select 1 from public.connection_decisions where user_id = '00000000-0000-0000-0000-000000000021' or target_id = '00000000-0000-0000-0000-000000000021')
        or exists (select 1 from public.profile_blocks where user_id = '00000000-0000-0000-0000-000000000021' or target_id = '00000000-0000-0000-0000-000000000021') then raise exception 'Deleted user discovery data remains'; end if;
end $$;
rollback;
