-- F3: profiles table, RLS, and on-auth-signup trigger.
-- Spec: docs/specs/2026-08-22-f3-email-signin.md §"Implementation decisions".
--
-- IMPORTANT: apply against the `postgres` database, not `_supabase`.
-- GoTrue (supabase-auth) connects to `postgres` by default
-- (GOTRUE_DB_DATABASE_URL=...@db:54322/postgres), and the trigger
-- fires on auth.users INSERT. _supabase.auth.users is empty — the
-- trigger would never fire there.

-- profiles: one row per auth.users; auto-created by trigger on signup.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text null,
  avatar_url text null,
  locale text not null default 'zh-CN',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- RLS: users can read and update their own row. Insert is reserved
-- for the trigger (security definer) so client cannot spoof profiles.
drop policy if exists "users read own profile" on public.profiles;
drop policy if exists "users update own profile" on public.profiles;

create policy "users read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "users update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a profile row whenever an auth.users row is inserted.
-- Runs as security definer so RLS doesn't block it. on conflict guards
-- against duplicate rows if (in a future ticket) the same user signs up
-- via multiple paths.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
