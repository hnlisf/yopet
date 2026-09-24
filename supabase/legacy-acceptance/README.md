# Legacy domain acceptance SQL

These files are the original transactional psql acceptance checks retained
from the former ignored backend worktree. They are now version-controlled with
the migrations they verify.

They sit outside supabase/tests on purpose: the Supabase CLI passes files under
that directory to pgTAP. CI intentionally executes only
supabase/tests/database/p0_schema_and_rls_test.sql for now. Convert each legacy
scenario to pgTAP before placing it in the CI test directory; do not silently
treat an unexecuted SQL file as passing coverage.
