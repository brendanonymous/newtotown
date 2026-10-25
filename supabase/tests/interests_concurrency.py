"""Real row-lock races against auth_fixture.sql only; never a hosted project."""
import json
import os

from messaging_concurrency import query, race

OWNER = "62000000-0000-0000-0000-000000000001"


def main():
    if os.environ.get("NEWTOTOWN_TEST_DATABASE") != "1":
        raise SystemExit("Set NEWTOTOWN_TEST_DATABASE=1 for an isolated test database")
    assert query("select count(*) from information_schema.columns where table_schema='auth' and table_name='users';") == "1", "Expected local Auth fixture"
    try:
        query(f"""
            insert into auth.users(id) values ('{OWNER}');
            insert into public.profiles(id,first_name,job_title,goal,date_of_birth,platonic_agreement)
                values ('{OWNER}','Sam','Designer','Find a coffee buddy.','1990-01-01',true);
        """)
        first = f"select public.pilot_interests_save('{OWNER}','profile',array['golf','gym','tennis'])"
        second = f"select public.pilot_interests_save('{OWNER}','profile',array['running','basketball','pickleball'])"
        race(first, second)
        result = json.loads(query(f"set role service_role; select public.pilot_interests('{OWNER}');"))
        assert result["profile_option_ids"] == ["basketball", "pickleball", "running"]
        assert query(f"select count(*) from private.profile_interest_selections where user_id='{OWNER}';") == "3"
        print("PASS concurrent replacements serialize; the later save wins without combining six choices")

        filters = f"select public.pilot_interests_save('{OWNER}','filters',array['coffee','cooking'])"
        race(first, filters)
        result = json.loads(query(f"set role service_role; select public.pilot_interests('{OWNER}');"))
        assert result["profile_option_ids"] == ["golf", "gym", "tennis"]
        assert result["filter_option_ids"] == ["coffee", "cooking"]
        print("PASS concurrent profile and filter saves remain separate")
    finally:
        query(f"delete from auth.users where id='{OWNER}';")


if __name__ == "__main__":
    main()
