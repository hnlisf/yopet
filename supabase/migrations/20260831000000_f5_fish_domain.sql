-- F5: fish catalogue schema and read-only access policies.
--
-- This migration is deliberately re-runnable. Earlier local F5 work created
-- personality_traits with `code` as its primary key. F6 stores trait UUIDs on
-- each fish instance, so this migration upgrades that table in place: `id` is
-- the stable UUID primary key and `code` remains the human-readable unique key.

begin;

create table if not exists public.personality_traits (
  id uuid primary key,
  code text not null unique check (code in ('bold', 'shy', 'curious', 'lazy')),
  name_zh text not null,
  name_en text not null,
  description text not null,
  behavior_hint jsonb not null default '{}'::jsonb
);

-- Upgrade the pre-F5 local table without deleting its four reference rows.
alter table public.personality_traits add column if not exists id uuid;

update public.personality_traits
set id = case code
  when 'bold' then '5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid
  when 'shy' then '5f19d1f0-14d0-4e6a-9d0e-1bf389850002'::uuid
  when 'curious' then '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid
  when 'lazy' then '5f19d1f0-14d0-4e6a-9d0e-1bf389850004'::uuid
end
where id is null;

alter table public.personality_traits alter column id set not null;

do $$
declare
  primary_key_column text;
begin
  select attribute.attname
    into primary_key_column
  from pg_constraint constraint_definition
  join pg_attribute attribute
    on attribute.attrelid = constraint_definition.conrelid
   and attribute.attnum = constraint_definition.conkey[1]
  where constraint_definition.conrelid = 'public.personality_traits'::regclass
    and constraint_definition.contype = 'p';

  if primary_key_column = 'code' then
    alter table public.personality_traits
      drop constraint personality_traits_pkey;
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_definition
    join pg_attribute attribute
      on attribute.attrelid = constraint_definition.conrelid
     and attribute.attnum = constraint_definition.conkey[1]
    where constraint_definition.conrelid = 'public.personality_traits'::regclass
      and constraint_definition.contype = 'p'
      and attribute.attname = 'id'
  ) then
    alter table public.personality_traits
      add constraint personality_traits_pkey primary key (id);
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_definition
    join pg_attribute attribute
      on attribute.attrelid = constraint_definition.conrelid
     and attribute.attnum = constraint_definition.conkey[1]
    where constraint_definition.conrelid = 'public.personality_traits'::regclass
      and constraint_definition.contype = 'u'
      and attribute.attname = 'code'
  ) then
    alter table public.personality_traits
      add constraint personality_traits_code_key unique (code);
  end if;
end;
$$;

create table if not exists public.fish_species (
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

create table if not exists public.fish_variants (
  id text primary key,
  species_id text not null references public.fish_species(id) on delete cascade,
  variant_label text not null,
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  asset_filename text not null,
  unique (species_id, variant_label)
);

alter table public.personality_traits enable row level security;
alter table public.fish_species enable row level security;
alter table public.fish_variants enable row level security;

drop policy if exists "authenticated read personality_traits"
  on public.personality_traits;
drop policy if exists "authenticated read fish_species" on public.fish_species;
drop policy if exists "authenticated read fish_variants" on public.fish_variants;

create policy "authenticated read personality_traits"
  on public.personality_traits for select
  using (auth.role() = 'authenticated');

create policy "authenticated read fish_species"
  on public.fish_species for select
  using (auth.role() = 'authenticated');

create policy "authenticated read fish_variants"
  on public.fish_variants for select
  using (auth.role() = 'authenticated');

commit;
