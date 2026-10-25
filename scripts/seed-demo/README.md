# Fifty demo profiles

macOS command-line tool for the isolated `newtotown-test` project only
(`acmrnolvakubxnaxwpzt`). It creates fifty fictional Auth accounts, private
profiles, separate profile interests/Discovery filters, and private profile
photos. Every biography begins “Demo profile.” These are fixtures, not people
who can respond to messages. No email/SMS invitations are sent.

## Prepare portraits

1. Obtain fifty adult male portraits with rights covering your intended use.
   Prefer synthetic faces. Generated Photos offers commercial licensing; UI
   Faces free images are intended for design mockups, while paid collections
   cover live products. Keep your license/source records. The script does not
   scrape a site or download images through Unsplash's API.
2. Put one image per account in `scripts/seed-demo/photos/01.jpg` through
   `50.jpg`. This folder is ignored by Git. PNG/JPEG inputs are supported;
   change the corresponding `photo.file` in `profiles.json` if needed.
3. Fill each `photo.source_url` (HTTPS source page) and `photo.license` (license
   name or your permission record) in `profiles.json`. Review the personas and
   interest choices; these files are ordinary editable JSON. Preserve unique
   `demo_id` values across reruns.

Sources: https://generated.photos/faq and https://www.uifaces.co/licenses. Photo
rights are not granted by this script.

## Dry run

Install Deno 2, PostgreSQL's `psql`, and Xcode command-line tools. From the
repository root:

```sh
deno run --allow-read=scripts/seed-demo scripts/seed-demo/seed.ts --dry-run
```

Dry run is also the default. It validates fixture fields and reports missing
photo/source preparation. It performs no network requests, reads no secrets and
makes no changes. Active catalog membership and per-category limits are checked
against the test database before apply; the server validates each save again.

## Apply

The test project's migrations, private photo bucket and deployed functions must
already exist. Keep photo review off for these fixtures; the tool never
fabricates a selfie or review approval. Test-only agreement records belong only
to its generated identities, not to real users.

Create a local `.env.seed` at the repository root (ignored by Git). Copy the
connection values from **the test project's** Connect dialog. Use its database
password and server-side service-role/secret API key:

```dotenv
SUPABASE_SERVICE_ROLE_KEY=YOUR_TEST_SERVER_KEY
PGHOST=db.acmrnolvakubxnaxwpzt.supabase.co
PGPORT=5432
PGUSER=postgres
PGPASSWORD=YOUR_TEST_DATABASE_PASSWORD
PGDATABASE=postgres
```

If direct IPv6 connectivity is unavailable, use the dashboard's session pooler
host/port and `PGUSER=postgres.acmrnolvakubxnaxwpzt`. The guard accepts only
this project's direct host or its pooler username, database `postgres`, and
forces TLS. API requests always target the pinned test project. Never put these
administrative credentials in an xcconfig, app bundle, PR, or chat.

```sh
deno run --env-file=.env.seed --allow-read --allow-write --allow-env --allow-run \
  --allow-net=acmrnolvakubxnaxwpzt.supabase.co \
  scripts/seed-demo/seed.ts --apply
```

Before any writes, the tool checks for account collisions, validates all choices
against the current catalog, checks review requirements and decodes every image.
It compiles the small native normalizer once, resizes to at most 1200 pixels,
writes a fresh JPEG at 0.8 quality without source metadata, and enforces the
app's 3 MiB limit. Temporary output is removed on success or failure. Photos
stay in the existing private bucket; visibility is enabled only after upload
succeeds.

Reruns reuse only accounts with matching reserved `.invalid` email addresses
**and server-owned seed tags**. They update fixture fields, choices and images
without creating duplicate users. Do not rename IDs to update an existing
persona. The run is not one distributed transaction across
Auth/Storage/Postgres: if a request fails, stop and rerun to complete the marked
accounts. Existing profiles and fixtures outside this dataset are left alone.
Changing fixtures does not reset existing passes, reports, conversations, or
moderation restrictions.

## Remove the fixtures

```sh
deno run --env-file=.env.seed --allow-read --allow-env --allow-run \
  --allow-net=acmrnolvakubxnaxwpzt.supabase.co \
  scripts/seed-demo/seed.ts --cleanup
```

Cleanup finds only matching identities in this dataset, removes their Storage
bytes first, then deletes Auth accounts so profile/interest/connection/message
records cascade. Failed photo cleanup stops account deletion. Repeating cleanup
is safe. No portrait files or license fields are required for cleanup.

## Validation and limits

```sh
deno check scripts/seed-demo/seed.ts
deno lint scripts/seed-demo
deno test --allow-read=scripts/seed-demo scripts/seed-demo
```

Tests cover fixture validation, database guards, seed ownership, Admin account
creation and cleanup ordering/failure behavior with fake HTTP. The normalizer is
checked locally against a generated image. A complete hosted fifty-account run
still requires your portrait files and local admin/database credentials. The
iPhone interest editor is a separate feature; the seed can populate the approved
schema before that UI exists. Discovery shows up to twenty eligible candidates
per request, so all fifty need not appear at once.
