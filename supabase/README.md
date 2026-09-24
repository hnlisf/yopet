# Yopet database source of truth

supabase/ is the only version-controlled source for Yopet's domain database:

- migrations/ defines schema, functions, triggers, and RLS policies;
- seed.sql defines the development fish catalogue;
- tests/database/ contains pgTAP tests run in CI;
- legacy-acceptance/ preserves historical transactional acceptance scripts.
  Their active F17/F18 lifecycle coverage now lives in the pgTAP suite.

The sibling ../supabase-local directory is a local Docker runtime and
credential holder only. It must not gain Yopet domain migrations or tests.
Likewise, .backend-yopet-supabase/ is an ignored historical worktree, not a
schema source.

## Fresh local database

Install the Supabase CLI and Docker Desktop, then run from the repository root:

~~~powershell
supabase start
supabase db reset --local
supabase test db
supabase db lint --local --level error --fail-on error
~~~

This is a clean, disposable CLI stack. Do not point a production-like or
existing local tank at it without a planned data migration; db reset removes
local database contents.

## Adding a schema change

Create one timestamped migration in supabase/migrations/, add or update a
pgTAP test in supabase/tests/database/, and run the four commands above.
Never edit a previously applied migration.
