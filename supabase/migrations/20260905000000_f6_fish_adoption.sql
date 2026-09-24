-- F6: adopt a named fish into the signed-in user's tank.

begin;

do $$
begin
  create type public.fish_growth_stage as enum ('fry', 'juvenile', 'adult');
exception
  when duplicate_object then null;
end;
$$;

create table if not exists public.fish (
  id uuid primary key default gen_random_uuid(),
  tank_id uuid not null references public.tanks(id) on delete cascade,
  species_id text not null references public.fish_species(id),
  variant_id text not null references public.fish_variants(id),
  name text not null check (
    name = btrim(name)
    and char_length(name) between 1 and 20
  ),
  traits uuid[] not null check (cardinality(traits) between 1 and 3),
  growth_stage public.fish_growth_stage not null default 'fry',
  satiety smallint not null default 80 check (satiety between 0 and 100),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists fish_tank_created_at_idx
  on public.fish (tank_id, created_at);

create or replace function public.validate_fish_catalog_references()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (select count(distinct trait_id) from unnest(new.traits) trait_id)
      <> cardinality(new.traits) then
    raise exception using
      errcode = '23514',
      message = 'fish_traits_must_be_unique';
  end if;

  if exists (
    select 1
    from unnest(new.traits) trait_id
    left join public.personality_traits trait on trait.id = trait_id
    where trait.id is null
  ) then
    raise exception using
      errcode = '23503',
      message = 'fish_trait_not_found';
  end if;

  if not exists (
    select 1
    from public.fish_variants variant
    where variant.id = new.variant_id
      and variant.species_id = new.species_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'fish_variant_species_mismatch';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_fish_catalog_references on public.fish;
create trigger validate_fish_catalog_references
  before insert or update of species_id, variant_id, traits on public.fish
  for each row execute function public.validate_fish_catalog_references();

create or replace function public.enforce_tank_fish_capacity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Serialize writes per tank so two devices cannot both create fish #5/#6.
  perform pg_advisory_xact_lock(hashtextextended(new.tank_id::text, 0));

  if tg_op = 'INSERT' then
    if (select count(*) from public.fish where tank_id = new.tank_id) >= 5 then
      raise exception using
        errcode = 'P0001',
        message = 'tank_capacity_exceeded';
    end if;
  elsif new.tank_id is distinct from old.tank_id then
    if (select count(*) from public.fish where tank_id = new.tank_id) >= 5 then
      raise exception using
        errcode = 'P0001',
        message = 'tank_capacity_exceeded';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_tank_fish_capacity on public.fish;
create trigger enforce_tank_fish_capacity
  before insert or update of tank_id on public.fish
  for each row execute function public.enforce_tank_fish_capacity();

alter table public.fish enable row level security;

drop policy if exists "users read fish in own tank" on public.fish;
drop policy if exists "users insert fish in own tank" on public.fish;
drop policy if exists "users update fish in own tank" on public.fish;
drop policy if exists "users delete fish in own tank" on public.fish;

create policy "users read fish in own tank"
  on public.fish for select
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = fish.tank_id and tank.owner_id = auth.uid()
    )
  );

create policy "users insert fish in own tank"
  on public.fish for insert
  with check (
    exists (
      select 1 from public.tanks tank
      where tank.id = fish.tank_id and tank.owner_id = auth.uid()
    )
  );

create policy "users update fish in own tank"
  on public.fish for update
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = fish.tank_id and tank.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.tanks tank
      where tank.id = fish.tank_id and tank.owner_id = auth.uid()
    )
  );

create policy "users delete fish in own tank"
  on public.fish for delete
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = fish.tank_id and tank.owner_id = auth.uid()
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_publication_rel publication_relation
    join pg_publication publication
      on publication.oid = publication_relation.prpubid
    where publication.pubname = 'supabase_realtime'
      and publication_relation.prrelid = 'public.fish'::regclass
  ) then
    execute 'alter publication supabase_realtime add table public.fish';
  end if;
end;
$$;

commit;
