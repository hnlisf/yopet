# F4 — Auto-create empty tank on signup

> Status: ready-for-agent
> Parent issue: [yopet#4](https://github.com/hnlisf/yopet/issues/4) (注册时自动建一个空鱼缸)
> Depends on: F3 (issue #3 closed) — done
> Implements: PRD §5 step 2 ("空鱼缸 / 注册时 DB 自动建一条 tanks")

## Context

F3 delivered sign-in & sign-up with a `profiles` row auto-created on `auth.users` insert. F3's home screen currently shows the user's email + Sign out — but **the actual tank (the product surface) isn't loaded yet**. This ticket creates the `tanks` row on the same `auth.users` trigger, and makes the home screen load and render that tank.

**Post-F3 lesson applied here**: GoTrue connects to the `postgres` database (not `_supabase`). Both F3's `profiles` table AND F4's `tanks` table must live in `postgres` for the trigger on `auth.users` to fire.

**Idempotency**: a user might re-trigger (e.g. if the trigger is replayed in a migration, or if a future F-sidekick adds another `on_auth_user_created` flow). The `on conflict (owner_id) do nothing` guard makes the trigger safe to re-run — and per `CONTEXT.md` §tank, "1–5 fish per tank" but the F4 spec has only one tank per user, so a unique constraint on `owner_id` is fine.

## User stories

1. As a new player, after signing up I land on `/home` and see an empty fish tank placeholder — not a blank page.
2. As a new player, I see a primary button "选你的第一条鱼" that will take me to the fish-picker flow (that's F6; for F4 the button can be present but disabled, or a no-op route).
3. As a returning player, after signing back in I see the same tank I had before — the trigger didn't make a second tank on a second sign-up.

## Solution

**Database (postgres DB)**

A second trigger on `auth.users` (separate function from F3's `handle_new_user`) inserts one row into `public.tanks`:

```sql
create table public.tanks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  decoration_settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.tanks enable row level security;

create policy "users read own tank"
  on public.tanks for select using (auth.uid() = owner_id);

create policy "users insert own tank"
  on public.tanks for insert with check (auth.uid() = owner_id);

create policy "users update own tank"
  on public.tanks for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create or replace function public.handle_new_user_tank()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.tanks (owner_id) values (new.id)
  on conflict (owner_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created_tank
  after insert on auth.users
  for each row execute function public.handle_new_user_tank();
```

**Flutter**

- New `tankStreamProvider` (`StreamProvider<Tank?>`) in `auth_providers.dart` (or a new `tank_providers.dart` — pick the smaller file; tank is auth-adjacent, so keep it in `auth_providers.dart` for F4).
- `HomeScreen` swaps its body for: a centered card with the dark canvas, a heading "还没有鱼" (per ui-design §8 empty-state copy register), a one-line subline explaining the situation, and a primary button "选你的第一条鱼" that pushes a placeholder route (a real fish-picker doesn't exist until F6; for F4 the button is wired to a no-op `context.go('/pick-fish')` and F6 will fill that route).
- The stream subscribes to changes on `public.tanks` for the current user; on sign-out, the subscription is torn down by Riverpod's autoDispose.

## User-flow diagram

```
User signs up (F3)
  ↓
auth.users insert (postgres DB)
  ↓
F3 trigger: handle_new_user → public.profiles insert
F4 trigger: handle_new_user_tank → public.tanks insert
  ↓
signUp returns session (ENABLE_EMAIL_AUTOCONFIRM=true)
  ↓
router redirect → /home
  ↓
HomeScreen builds:
  - ref.watch(currentUserProvider) → User
  - ref.watch(tankStreamProvider) → Tank? (post-subscribe: Tank)
  - render "empty tank" placeholder
```

## Implementation decisions

### Project structure (F4 additions)

```
lib/
├── core/
│   ├── supabase.dart            (existing)
│   └── router.dart              (existing)
├── features/
│   ├── auth/
│   │   ├── auth_providers.dart   (extend with tankStreamProvider)
│   │   └── auth_screen.dart      (existing)
│   ├── home/
│   │   └── home_screen.dart      (rewrite: empty-tank placeholder)
│   └── (future F6) pick_fish/   (placeholder; F4 ships the button only)
```

### Profile trigger (F3) + tank trigger (F4) — separate functions, not a single mega-function

Per separation of concerns: F3's `handle_new_user` only inserts profile. F4 adds `handle_new_user_tank` that only inserts tank. Two triggers, two functions. A future ticket that adds a third side-effect (e.g. default preferences row) gets a third function, not a re-write of `handle_new_user`.

### Idempotency

- `tanks` has `unique` constraint on `owner_id` (a user has at most one tank).
- `handle_new_user_tank` uses `on conflict (owner_id) do nothing` (covers both the unique-constraint conflict and re-runs of the migration on an existing row).

### Empty tank UI

Reuses existing `Tokens` palette. Copy register per `ui-design.md` §9 — F4 uses:
- Heading: "还没有鱼" (Manrope 600 18sp, `Tokens.text`)
- Subline: "从下方选一只开始" (Manrope 400 15sp, `Tokens.textDim`)
- Primary button: "选你的第一条鱼" (per spec; uses `Tokens.tankGlow` bg + `Tokens.primaryBg` text per `Button — primary`)
- Layout: centered card, max-width 420, dark canvas (per the auth screen pattern in F3)

### `tankStreamProvider` design

```dart
final tankStreamProvider = StreamProvider<Tank?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();
  final client = getSupabase();
  return client.from('tanks')
      .stream(primaryKey: ['owner_id'])
      .eq('owner_id', user.id)
      .map((rows) => rows.isEmpty ? null : Tank.fromMap(rows.first))
      .asBroadcastStream();
});
```

The Supabase realtime channel subscribes to row changes for this user. On sign-out the provider is autoDispose'd (or just returns `Stream.empty()`), the stream closes.

`Tank` is a hand-rolled model class (no freezed/json_serializable yet — F4 stays YAGNI, F5 will introduce the codegen toolchain).

## Acceptance mapping (issue #4 ↔ spec)

| acceptance | spec landing |
|---|---|
| tanks 表 schema | `create table public.tanks` with `id`, `owner_id`, `decoration_settings`, `created_at` |
| RLS: own row only | 3 policies (SELECT, INSERT, UPDATE) all gated on `auth.uid() = owner_id` |
| sign-up DB trigger | `on_auth_user_created_tank` after insert on `auth.users` calls `handle_new_user_tank()` |
| Flutter home tank 查询 | `tankStreamProvider` streamed from `public.tanks where owner_id = current_user.id` |
| 空鱼缸占位 UI | `HomeScreen` body — heading + subline + primary button per ui-design copy register |
| 多次登录 1 个 tank | `unique` on `owner_id` + `on conflict do nothing` |
| psql 验证 | included in T3 (F4-T3) e2e: signup → select count from tanks for new user → assert 1 |

## Out of scope

- **F4 does not create the `/pick-fish` route.** The button is present but the route is a no-op until F6 (issue #6 — 领养一条鱼).
- **No tank update / decoration_settings editor yet** — F7 (issue #7) is decoration system.
- **No freezed / json_serializable codegen yet** — F4 ships a hand-rolled `Tank` class; F5 will introduce codegen toolchain.
- **No realtime schema grant on `tanks`** — Supabase realtime needs `supabase_realtime` publication entry on `tanks` for the stream to work. The migration grants that as part of `create table`. (A future ticket if missing.)

## Further notes

- **Postgres DB, not _supabase** — applies the F3 lesson. `tanks` and the trigger live in `postgres` (where GoTrue is connected). Verified by e2e signup → `select count(*) from public.tanks where owner_id = <new user id>` returns 1.
- **`Tank.fromMap` factory** — F4 ships a hand-rolled `Tank` class in `lib/features/home/tank.dart`. It has 4 fields (id, ownerId, decorationSettings, createdAt) and a `fromMap` factory. F5 (fish domain data) will replace this with a freezed model and JSON serialization.
- **Realtime channel for `tanks`** — handled by Supabase's `stream()` API. Requires `tanks` to be added to `supabase_realtime` publication. The migration includes `alter publication supabase_realtime add table public.tanks;` to make the stream work; without it the provider would receive no updates.
- **The router redirect already works for F3** — F4 only changes the home screen body, not the router. `/home` is already wired.

## Reference

- Issue: yopet#4 注册时自动建空鱼缸
- Spec: `docs/specs/2026-08-22-f3-email-signin.md` (F3, parent)
- Runbook: `docs/setup/local-supabase.md` §11 (F1 gaps)
- Domain glossary: `CONTEXT.md` §tank (1–5 fish per tank)
- UI design: `docs/design/ui-design.md` §7 (Button — primary tokens)
- F3 fix: commit `60fa6545` (profiles migration to `postgres` DB)
