# F5 — Fish domain data seed (species / variants / personality traits)

> Status: in-progress
> Parent issue: [yopet#5](https://github.com/hnlisf/yopet/issues/5) (鱼种 / 变体 / 性格特征 domain data seed)
> Depends on: F3 (issue #3 closed) — done (RLS helpers + auth.uid() are wired)
> Implements: PRD §6.5 (fish_species / fish_variants / personality_traits tables)

## Context

F3 wired sign-in. F4 created a per-user empty tank. F6 (领养鱼, issue #6) needs **fish to adopt from** — that's what F5 ships. Three global tables that any authenticated user can read but nobody can write to (the app is read-only at runtime; reference data lives in SQL).

The PRD §6.5 schema is the source of truth; F5 hardens it for production, seeds 8+ species with 3-5 variants each, and 4 personality traits. Flutter does nothing for F5 (the data is fetched later by F6). F5 is **all DB work**.

## User stories

1. As a developer running `supabase db reset`, the 3 tables are recreated with seed data populated, so F6 has fish to adopt from immediately.
2. As an authenticated user, I can `select * from fish_species` and see 8+ rows.
3. As a Studio user, I can browse the 3 tables and see fish_species / fish_variants / personality_traits with realistic seed data (Chinese names per the project's domain glossary).
4. As an unauthenticated user, I can NOT read fish_species (per the issue's "all authenticated user can read" RLS rule).

## Solution

**Database (postgres DB — lesson from F3/F4)**

Three tables in `postgres` (where F3 profiles + F4 tanks live; GoTrue + future RLS helpers all run there):

```sql
-- personality_traits: 4 reference rows (bold, shy, curious, lazy)
create table public.personality_traits (
  id uuid primary key,
  code text not null unique check (code in ('bold','shy','curious','lazy')),
  name_zh text not null,
  name_en text not null,
  description text not null,
  behavior_hint jsonb not null default '{}'::jsonb
);

-- fish_species: 8 curated rows
create table public.fish_species (
  id text primary key,
  common_name_zh text not null,
  common_name_en text not null,
  scientific_name text not null,
  asset_base_path text not null,
  preferred_temp_min numeric not null default 22.0,
  preferred_temp_max numeric not null default 26.0,
  growth_days_to_juvenile int not null default 7,
  growth_days_to_adult int not null default 21
);

-- fish_variants: 3-5 per species
create table public.fish_variants (
  id text primary key,
  species_id text not null references public.fish_species(id) on delete cascade,
  variant_label text not null,
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  asset_filename text not null,
  unique (species_id, variant_label)
);
```

**RLS** — read-only for authenticated:

```sql
alter table public.fish_species      enable row level security;
alter table public.fish_variants     enable row level security;
alter table public.personality_traits enable row level security;

create policy "authenticated read fish_species"
  on public.fish_species for select
  using (auth.role() = 'authenticated');

create policy "authenticated read fish_variants"
  on public.fish_variants for select
  using (auth.role() = 'authenticated');

create policy "authenticated read personality_traits"
  on public.personality_traits for select
  using (auth.role() = 'authenticated');
```

No INSERT / UPDATE / DELETE policy = no one (including service_role used by the supabase client) can write through PostgREST. The seed data is loaded only by `supabase db reset` or a manual psql run.

**Seed data** — 8 species, 3-4 variants each, 4 personality traits

| code | name_zh | name_en | description | behavior_hint |
|---|---|---|---|---|
| `bold` | 大胆 | Bold | 这条鱼对玩家的在场反应直接,靠近时游得更急,常浮到水面 | `{"swim_speed":"fast","surface_preference":"high","reaction_radius":"large"}` |
| `shy` | 害羞 | Shy | 这条鱼倾向躲在装饰物后,玩家靠近时游远 | `{"swim_speed":"slow","surface_preference":"low","reaction_radius":"small"}` |
| `curious` | 好奇 | Curious | 这条鱼被移动的物体吸引,会主动游向光标或装饰 | `{"swim_speed":"medium","surface_preference":"mid","reaction_radius":"large"}` |
| `lazy` | 慵懒 | Lazy | 这条鱼动得少,常停在缸中段,只在喂食时明显动 | `{"swim_speed":"slow","surface_preference":"mid","reaction_radius":"small"}` |

| id | common_name_zh | common_name_en | scientific_name | preferred (min,max) | growth (juv,adult) |
|---|---|---|---|---|---|
| `goldfish` | 金鱼 | Goldfish | Carassius auratus | 18,28 | 7,21 |
| `guppy` | 孔雀鱼 | Guppy | Poecilia reticulata | 22,28 | 7,21 |
| `tropical` | 热带鱼 | Tropical fish | Paracheirodon innesi | 24,28 | 7,21 |
| `betta` | 斗鱼 | Betta | Betta splendens | 24,30 | 7,21 |
| `koi` | 锦鲤 | Koi | Cyprinus rubrofuscus | 16,28 | 14,42 |
| `puffer` | 河豚 | Puffer | Tetraodon nigroviridis | 24,28 | 14,42 |
| `angel` | 神仙鱼 | Angelfish | Pterophyllum scalare | 24,30 | 14,42 |
| `tetra` | 灯科鱼 | Tetra | Paracheirodon axelrodi | 22,28 | 7,21 |

Each species gets 3-4 variants (24+ variant rows total). Color palette is the yopet aquatic-friendly set the design spec calls out (mostly soft, with one accent per species).

## User-flow diagram

```
supabase db reset
  ↓
fresh postgres DB
  ↓
migrations/*.sql run (F3/F4 + F5 create tables + RLS)
  ↓
seed.sql run (insert 4 traits + 8 species + 24+ variants)
  ↓
Authenticated user queries public.fish_species
  ↓
RLS policy "authenticated read fish_species" passes
  ↓
Result returned
```

## Implementation decisions

### Postgres DB, not _supabase

Per F3 / F4 lessons: the fish tables live in `postgres` (where GoTrue + the existing F3 profiles + F4 tanks already are). `auth.uid()` and `auth.role()` RLS helpers are populated by the supabase-auth GoTrue container, so they work the same way regardless of which DB.

### Stable IDs: text for catalogue items, UUID for traits

`fish_species.id` and `fish_variants.id` are text (for example `'goldfish'` and `'goldfish_classic'`), so Flutter can map them directly to catalogue and asset identifiers. `personality_traits.id` is a stable UUID, while its unique `code` remains the readable business key. This matches F6's `fish.traits uuid[]` contract without forcing future fish rows to store string codes.

### Color hex regex constraint

`color_hex TEXT NOT NULL CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')` — a literal regex catch on the canonical CSS-hex form. Catches `#FFF` (3-char) and `#FFFFFFFF` (8-char with alpha) before they hit the UI layer. The Flutter side does `Color(int.parse('FF$color', radix: 16))` after stripping the `#`.

### `behavior_hint` jsonb shape

Per trait, a small object with a few stable keys. F5 ships 3 keys per trait (`swim_speed`, `surface_preference`, `reaction_radius`). F6 reads them to compute fish motion. Future tickets can add keys (e.g. `feeding_responsiveness`) without a migration.

### Asset paths are placeholders, not real files

`asset_base_path` and `asset_filename` are strings the F6 (fish picker) will use to load fish sprite images. F5 ships paths like `assets/fish/goldfish/` and `goldfish_classic.png`, but the actual image files do not exist yet (F6 is the ticket that adds them). `asset_base_path` is a directory path; `asset_filename` is the file under it. The convention is `assets/fish/{species_id}/{variant_id}.png`.

### RLS — read-only for `authenticated`

The issue says "all authenticated user can read, RLS limited to read-only". Implementation:
- SELECT policy uses `auth.role() = 'authenticated'` (works for any user with a valid JWT)
- No INSERT / UPDATE / DELETE policies → PostgREST refuses those operations on the table
- Service role (used by supabase db reset) bypasses RLS so the seed itself can INSERT

`anon` (unauthenticated) gets nothing — appropriate for a paid-product model where seeing the catalogue is part of the signed-in experience.

## Acceptance mapping (issue #5 ↔ spec)

| acceptance | spec landing |
|---|---|
| fish_species 表 | `supabase/migrations/20260831000000_f5_fish_domain.sql` |
| fish_variants 表 | `supabase/migrations/20260831000000_f5_fish_domain.sql` |
| personality_traits 表（UUID 主键，code 唯一） | `supabase/migrations/20260831000000_f5_fish_domain.sql` |
| seed ≥ 8 species + 3-5 variants + ≥ 4 traits | `supabase/seed.sql` inline `insert into` statements |
| RLS: auth read only, no write | F5 migration 中的 3 条 SELECT policy |
| 自动化验证 | `supabase/tests/f5_fish_domain.sql` |
| Studio 验证 | T3 e2e: connect Studio to `postgres` DB, confirm 8 / 24+ / 4 row counts |

## Out of scope

- **No Flutter code** — F5 is pure DB work; F6 reads the data through supabase_flutter.
- **No asset images** — `asset_base_path` / `asset_filename` are strings pointing at files that do not exist yet. F6 (fish picker) ships the actual PNGs.
- **No fish table** (`public.fish` per-fish-instance owned by a user) — F6 decides per-fish schema.
- **No i18n of personality names** — `name_zh` + `name_en` are static; a future i18n ticket moves these to a JSON dictionary if we ship other languages.
- **No edits to fish_species / fish_variants at runtime** — read-only is intentional. A future ticket that lets curators add new species via a backend admin UI would also need to relax the RLS policies.

## Further notes

- **Postgres DB, not _supabase** — applies the F3 / F4 lesson. Apply with `docker exec -i supabase-db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < supabase-local/supabase/seed.sql` (after running the migration).
- **Supabase db reset auto-runs seed.sql** when the file is in `supabase/seed.sql` of the supabase project (the `supabase-local` repo's `supabase/` directory). Verified by running `supabase db reset` locally and checking the 3 tables.
- **Realtime publication NOT added** — fish data is global / read-only and rarely changes. F6 reads via plain `from('fish_species').select()` not via `stream()`. If we later add a "new species available" push, we add `alter publication supabase_realtime add table public.fish_species;` in a separate migration.
- **`uuid-ossp` / `pgcrypto` not required** — F5 uses four fixed UUID literals for the immutable trait catalogue, so it has no UUID-generation extension dependency.

## Reference

- Issue: yopet#5 鱼种 / 变体 / 性格特征 domain data seed
- Spec: `docs/specs/2026-08-22-f3-email-signin.md` (F3, F5 reads via `currentUserProvider`)
- Spec: `docs/specs/2026-08-28-f4-empty-tank-on-signup.md` (F4, F5 doesn't depend on F4 directly)
- Domain glossary: `CONTEXT.md` §鱼种 / §变体 / §性格特征
- PRD: §6.5 fish_species / fish_variants / personality_traits schema
- F3 fix commit: `60fa6545` (postgres DB lesson)
- F4 fix commit: `422fd972` (postgres DB lesson, same)
