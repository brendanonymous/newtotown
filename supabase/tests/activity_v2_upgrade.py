"""Migrate a populated legacy database, isolated from the policy/concurrency fixtures."""
import json
import os
from pathlib import Path
import subprocess
import uuid

from messaging_concurrency import query, PSQL

ROOT = Path(__file__).resolve().parents[2]
OWNER = '73000000-0000-0000-0000-000000000001'


def main():
    if os.environ.get('NEWTOTOWN_TEST_DATABASE') != '1':
        raise SystemExit('Set NEWTOTOWN_TEST_DATABASE=1 for an isolated test database')
    assert query("select count(*) from information_schema.columns where table_schema='auth' and table_name='users';") == '1', 'Expected local Auth fixture'
    database = 'activity_upgrade_' + uuid.uuid4().hex
    query('create database ' + database + ';')
    env = {**os.environ, 'PGDATABASE': database}

    def run(sql):
        result = subprocess.run(PSQL, input=sql, env=env, text=True, capture_output=True, timeout=30)
        if result.returncode:
            raise AssertionError(result.stderr)
        return result.stdout.strip()

    try:
        # Roles are cluster-wide and already exist in the parent fixture database.
        fixture = (ROOT / 'supabase/tests/auth_fixture.sql').read_text()
        run('\n'.join(line for line in fixture.splitlines() if not line.startswith('create role ')))
        migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
        boundary = next(i for i, path in enumerate(migrations) if path.name.endswith('_activity_v2_catalog_tables.sql'))
        for path in migrations[:boundary]:
            run(path.read_text())
        run(f"""
            insert into auth.users(id) values ('{OWNER}');
            insert into public.profiles(id,first_name,job_title,goal,date_of_birth,platonic_agreement)
                values ('{OWNER}','Sam','Designer','Meet people for weekend hikes.','1990-01-01',true);
            insert into storage.objects(bucket_id,name) values ('private-photos','{OWNER}/profile.jpg');
            select public.pilot_interests_save('{OWNER}','profile',array['golf','coffee','craft_beer']);
            insert into private.profile_interest_selections(user_id,category_id,option_id)
                values ('{OWNER}','social_hobbies','board_games');
            select public.pilot_interests_save('{OWNER}','filters',array['golf','coffee']);
            select public.pilot_discovery_save_preferences('{OWNER}',40,55);
        """)
        for path in migrations[boundary:]:
            run(path.read_text())
        # Check raw state BEFORE invoking v2 load: this proves the migration imports it.
        result = json.loads(run(f"select private.activity_owner_state('{OWNER}');"))
        assert result['setup']['legacy_imported_at'] is not None
        assert result['setup']['entry_kind'] == 'existing'
        assert result['setup']['basics_complete'] and result['setup']['photos_complete']
        assert not result['setup']['looking_for_complete'] and result['category_ids'] == []
        assert result['interest_ids'] == ['golf']
        assert result['filter_ids'] == ['golf'] and result['setup']['filters_need_review']
        assert set(result['unavailable_legacy_interest_ids']) == {'coffee', 'craft_beer', 'board_games'}
        assert run(f"select count(*) from private.profile_interest_selections where user_id='{OWNER}';") == '4'
        assert run('select count(*) from public.account_agreements;') == '0'
        assert run(f"select minimum_age || ':' || maximum_age from public.discovery_settings where user_id='{OWNER}';") == '40:55'
        print('PASS populated legacy upgrade imports exact active IDs once, retains retired/hidden history and requires filter review')
    finally:
        query('drop database ' + database + ' with (force);')


if __name__ == '__main__':
    main()
