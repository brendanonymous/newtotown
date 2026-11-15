"""Two-session v2 saves and direct constraint races; disposable Auth fixture only."""
import json
import os
import uuid

from messaging_concurrency import query, start, ready, wait_for_lock, finish

OWNER = '72000000-0000-0000-0000-000000000001'


def race(first_sql, second_sql, error_code):
    processes = []
    try:
        name = 'activity-v2-' + uuid.uuid4().hex
        first = start('begin; set local role service_role; ' + first_sql + "; select 'READY';\n", name + '-first')
        processes.append(first)
        ready(first)
        second = start('set role service_role; ' + second_sql + ';\n', name)
        processes.append(second)
        wait_for_lock(name)
        _, error = finish(first)
        assert first.returncode == 0, error.decode()
        _, error = finish(second, '')
        assert second.returncode != 0 and error_code.encode() in error, error.decode()
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
            process.communicate()


def main():
    if os.environ.get('NEWTOTOWN_TEST_DATABASE') != '1':
        raise SystemExit('Set NEWTOTOWN_TEST_DATABASE=1 for an isolated test database')
    assert query("select count(*) from information_schema.columns where table_schema='auth' and table_name='users';") == '1', 'Expected local Auth fixture'
    try:
        query(f"""
            insert into auth.users(id) values ('{OWNER}');
            insert into public.profiles(id,first_name,job_title,goal,date_of_birth,platonic_agreement)
                values ('{OWNER}','Sam','Designer','Find a coffee buddy.','1990-01-01',true);
            set role service_role;
            select public.activity_v2_owner('{OWNER}');
        """)
        race(f"select public.activity_v2_save_interests('{OWNER}',0,array['golf','chess'],false)",
             f"select public.activity_v2_save_interests('{OWNER}',0,array['hiking'],false)", '40001')
        result = json.loads(query(f"set role service_role; select public.activity_v2_owner('{OWNER}');"))
        assert result['interest_ids'] == ['golf', 'chess']
        assert result['setup']['selection_revision'] == 1
        print('PASS concurrent replacement rejects stale revision without lost updates')

        # Different editors still share a revision; a stale filter draft needs review.
        race(f"select public.activity_v2_save_looking_for('{OWNER}',1,array['gym'],array['gym'])",
             f"select public.activity_v2_save_filters('{OWNER}',1,array['golf'])", '40001')
        result = json.loads(query(f"set role service_role; select public.activity_v2_owner('{OWNER}');"))
        assert result['category_ids'] == ['gym'] and result['filter_ids'] == []
        assert result['interest_ids'] == ['golf', 'chess']
        print('PASS distinct editors cannot silently save stale account state')

        query(f"set role service_role; select public.activity_v2_save_looking_for('{OWNER}',2,array['gym','sports','hobby','events'],array[]::text[]);")
        race(f"insert into private.profile_looking_for(user_id,category_id) values ('{OWNER}','weekend')",
             f"insert into private.profile_looking_for(user_id,category_id) values ('{OWNER}','outdoor')", '23514')
        assert query(f"select count(*) from private.profile_looking_for where user_id='{OWNER}';") == '5'
        print('PASS privileged concurrent inserts cannot exceed five categories')
    finally:
        query(f"delete from auth.users where id='{OWNER}';")


if __name__ == '__main__':
    main()
