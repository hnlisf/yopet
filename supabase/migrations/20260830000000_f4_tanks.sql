-- F4: tanks table, RLS, on-auth-signup tank trigger, realtime publication.
-- Spec: docs/specs/2026-08-28-f4-empty-tank-on-signup.md
--
-- IMPORTANT: apply against the `postgres` database, NOT `_supabase`.
-- GoTrue (supabase-auth) connects to `postgres` (GOTRUE_DB_DATABASE_URL=
-- ...@db:54322/postgres). The trigger fires on auth.users INSERT,
-- which happens in `postgres`. _supabase.auth.users is empty (and would
-- stay empty after this migration), so the trigger would never fire
-- there. See commit 60fa6545 (F3 fix) for the full explanation.

create table if not exists public.tanks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  decoration_settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.tanks enable row level security;

-- RLS: a user can only see / modify their own tank.
drop policy if exists "users read own tank" on public.tanks;
drop policy if exists "users insert own tank" on public.tanks;
drop policy if exists "users update own tank" on public.tanks;

create policy "users read own tank"
  on public.tanks for select
  using (auth.uid() = owner_id);

create policy "users insert own tank"
  on public.tanks for insert
  with check (auth.uid() = owner_id);

create policy "users update own tank"
  on public.tanks for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Auto-create a tank row whenever an auth.users row is inserted.
-- Separate from F3's handle_new_user (which creates the profile row);
-- each side-effect gets its own function, single responsibility.
-- Runs as security definer so RLS doesn't block it. on conflict guards
-- against duplicate rows for the rare case a second signup path tries
-- to create a second tank for the same user.
create or replace function public.handle_new_user_tank()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tanks (owner_id) values (new.id)
  on conflict (owner_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_tank on auth.users;

create trigger on_auth_user_created_tank
  after insert on auth.users
  for each row execute function public.handle_new_user_tank();

-- Realtime: add the table to the supabase_realtime publication so
-- the Flutter `tankStreamProvider` actually receives row updates.
-- Without this, the stream would never fire (no error, just silence).
do $$
begin
  if not exists (
    select 1
    from pg_publication_rel publication_relation
    join pg_publication publication
      on publication.oid = publication_relation.prpubid
    where publication.pubname = 'supabase_realtime'
      and publication_relation.prrelid = 'public.tanks'::regclass
  ) then
    execute 'alter publication supabase_realtime add table public.tanks';
  end if;
end;
$$;
