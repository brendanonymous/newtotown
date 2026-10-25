"""Real two-session tests. Run only against the disposable auth_fixture.sql database."""
import json
import os
import select
import subprocess
import time
import uuid

PSQL = ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose"]
A = "20000000-0000-0000-0000-000000000001"
B = "20000000-0000-0000-0000-000000000002"
RETRY = "20000000-0000-0000-0000-000000000003"


def query(sql):
    return subprocess.run(PSQL, input=sql, text=True, capture_output=True, timeout=15, check=True).stdout.strip()


def start(sql, name):
    process = subprocess.Popen(PSQL, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, env={**os.environ, "PGAPPNAME": name})
    process.stdin.write(sql.encode())
    process.stdin.flush()
    return process


def ready(process):
    output = b""
    deadline = time.monotonic() + 10
    while b"READY\n" not in output:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
            raise AssertionError("First session did not become ready")
        chunk = os.read(process.stdout.fileno(), 65_536)
        if not chunk:
            raise AssertionError("First session exited: " + process.stderr.read().decode())
        output += chunk
    return output.decode()


def wait_for_lock(name):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        waiting = query(f"select exists(select 1 from pg_stat_activity where application_name = '{name}' and wait_event_type = 'Lock');")
        if waiting == "t":
            return
        time.sleep(0.03)
    raise AssertionError("Second session did not wait for the pair lock")


def finish(process, sql="commit;\n"):
    process.stdin.write(sql.encode())
    process.stdin.flush()
    # communicate closes stdin and drains both output pipes.
    return process.communicate(timeout=15)


def clean():
    query(f"delete from storage.objects where name in ('{A}/profile.jpg', '{B}/profile.jpg'); delete from auth.users where id in ('{A}', '{B}');")


def seed():
    query(f"""
        insert into auth.users(id) values ('{A}'), ('{B}');
        insert into public.profiles(id, first_name, job_title, goal, date_of_birth, city, platonic_agreement)
        select id, 'Alex', 'Designer', 'Find a hiking buddy.', '1990-01-01', 'Scottsdale', true
        from auth.users where id in ('{A}', '{B}');
        insert into storage.objects(bucket_id, name) values ('private-photos', '{A}/profile.jpg'), ('private-photos', '{B}/profile.jpg');
        insert into public.discovery_settings(user_id, visible) values ('{A}', true), ('{B}', true);
        insert into public.connection_decisions(user_id, target_id, choice) values ('{A}', '{B}', 'connect'), ('{B}', '{A}', 'connect');
        """)


def race(first_sql, second_sql, should_fail=False):
    processes = []
    try:
        name = "messaging-test-" + uuid.uuid4().hex
        first = start("begin; set local role service_role; " + first_sql + "; select 'READY';\n", name + "-first")
        processes.append(first)
        first_output = ready(first)
        second = start("set role service_role; " + second_sql + ";\n", name)
        processes.append(second)
        wait_for_lock(name)
        finish(first)
        assert first.returncode == 0, "First transaction failed"
        stdout, stderr = finish(second, "")
        if should_fail:
            assert second.returncode != 0 and b"P0001" in stderr, stderr.decode()
        else:
            assert second.returncode == 0, stderr.decode()
        return first_output, stdout.decode()
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
            process.communicate()


def main():
    if os.environ.get("NEWTOTOWN_TEST_DATABASE") != "1":
        raise SystemExit("Set NEWTOTOWN_TEST_DATABASE=1 for an isolated test database")
    # Real Supabase Auth has many columns; refuse to seed or clean a hosted database.
    assert query("select count(*) from information_schema.columns where table_schema = 'auth' and table_name = 'users';") == "1", "Expected auth_fixture.sql, never production Auth"
    original_review = query("select photo_review_required from public.pilot_features where id;")
    try:
        query("update public.pilot_features set photo_review_required = false;")
        clean()
        seed()
        open_a = f"select public.pilot_messaging_open('{A}', '{B}')"
        open_b = f"select public.pilot_messaging_open('{B}', '{A}')"
        first, second = race(open_a, open_b)
        thread = json.loads(first.splitlines()[0])["id"]
        assert json.loads(second)["id"] == thread
        assert query("select count(*) from private.conversations;") == "1"
        print("PASS simultaneous opens return one conversation")

        send = f"select public.pilot_messaging_send('{A}', '{thread}', '{RETRY}', 'Coffee?')"
        first, second = race(send, send)
        assert json.loads(first.splitlines()[0])["id"] == json.loads(second)["id"]
        assert query("select count(*) from private.messages;") == "1"
        print("PASS simultaneous send retries return one message")

        block = f"select public.pilot_discovery_block('{B}', '{A}')"
        race(block, send, should_fail=True)
        assert query("select count(*) from private.messages;") == "1"
        print("PASS blocked send waits, rechecks access, and fails after block commits")

        clean()
        seed()
        thread = json.loads(query("set role service_role; " + open_a))["id"]
        send = f"select public.pilot_messaging_send('{A}', '{thread}', '{RETRY}', 'Before block')"
        race(send, block)
        denied = subprocess.run(PSQL, input="set role service_role; " + send, text=True, capture_output=True, timeout=15)
        assert denied.returncode != 0 and "P0001" in denied.stderr
        assert query("select count(*) from private.messages;") == "1"
        print("PASS earlier send can commit; subsequent block revokes future access")
        clean()
        seed()
        report = f"select public.pilot_report_profile('{A}', '{B}', 'spam', null, '{RETRY}')"
        first, second = race(report, report)
        assert json.loads(first.splitlines()[0])["id"] == json.loads(second)["id"]
        assert query("select count(*) from private.profile_reports;") == "1"
        print("PASS simultaneous report retries return one report and disconnect")

        clean()
        seed()
        thread = json.loads(query("set role service_role; " + open_a))["id"]
        send = f"select public.pilot_messaging_send('{B}', '{thread}', '{RETRY}', 'After report')"
        race(report, send, should_fail=True)
        assert query("select count(*) from private.messages;") == "0"
        print("PASS report serializes with send and rejects later contact")

        clean()
        seed()
        thread = json.loads(query("set role service_role; " + open_a))["id"]
        send = f"select public.pilot_messaging_send('{B}', '{thread}', '{RETRY}', 'Before report')"
        race(send, report)
        assert query("select count(*) from private.messages;") == "1"
        assert query("select count(*) from private.profile_reports;") == "1"
        assert query(f"set role service_role; select jsonb_array_length(public.pilot_messaging_list('{A}')->'conversations');") == "0"
        print("PASS earlier send can commit while a later report removes access")

    finally:
        clean()
        query(f"update public.pilot_features set photo_review_required = {'true' if original_review == 't' else 'false'};")


if __name__ == "__main__":
    main()
