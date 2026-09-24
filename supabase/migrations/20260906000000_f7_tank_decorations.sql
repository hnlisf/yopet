-- F7: visual-only aquarium decorations.
-- Decorations deliberately live beside fish state: placing, moving, or
-- removing one can never update fish satiety, growth, personality, or mood.

begin;

create table if not exists public.tank_decorations (
  id uuid primary key default gen_random_uuid(),
  tank_id uuid not null references public.tanks(id) on delete cascade,
  decoration_code text not null check (decoration_code in (
    'long_plant', 'round_plant', 'ribbon_plant',
    'moss_rock', 'moon_sand', 'arch_rock',
    'driftwood', 'branch_wood', 'rootwood',
    'midnight', 'moonlit', 'aurora'
  )),
  decoration_type text not null check (
    decoration_type in ('plant', 'stone', 'driftwood', 'background')
  ),
  position_x numeric(5, 4) not null default 0.5 check (
    position_x between 0 and 1
  ),
  position_y numeric(5, 4) not null default 0.5 check (
    position_y between 0 and 1
  ),
  placed_at timestamptz not null default now(),
  unique (tank_id, decoration_code)
);

create index if not exists tank_decorations_tank_placed_at_idx
  on public.tank_decorations (tank_id, placed_at);

-- A tank has at most one full-scene background. Object decorations remain
-- independently placeable, one of each approved code per tank.
create unique index if not exists tank_decorations_one_background_per_tank_idx
  on public.tank_decorations (tank_id)
  where decoration_type = 'background';

create or replace function public.validate_tank_decoration_catalog()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if (new.decoration_type = 'plant' and new.decoration_code not in (
    'long_plant', 'round_plant', 'ribbon_plant'
  )) or (new.decoration_type = 'stone' and new.decoration_code not in (
    'moss_rock', 'moon_sand', 'arch_rock'
  )) or (new.decoration_type = 'driftwood' and new.decoration_code not in (
    'driftwood', 'branch_wood', 'rootwood'
  )) or (new.decoration_type = 'background' and new.decoration_code not in (
    'midnight', 'moonlit', 'aurora'
  )) then
    raise exception using
      errcode = '23514',
      message = 'tank_decoration_type_code_mismatch';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_tank_decoration_catalog on public.tank_decorations;
create trigger validate_tank_decoration_catalog
  before insert or update of decoration_code, decoration_type
  on public.tank_decorations
  for each row execute function public.validate_tank_decoration_catalog();

alter table public.tank_decorations enable row level security;

drop policy if exists "users read decorations in own tank"
  on public.tank_decorations;
drop policy if exists "users insert decorations in own tank"
  on public.tank_decorations;
drop policy if exists "users update decorations in own tank"
  on public.tank_decorations;
drop policy if exists "users delete decorations in own tank"
  on public.tank_decorations;

create policy "users read decorations in own tank"
  on public.tank_decorations for select
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = tank_decorations.tank_id
        and tank.owner_id = auth.uid()
    )
  );

create policy "users insert decorations in own tank"
  on public.tank_decorations for insert
  with check (
    exists (
      select 1 from public.tanks tank
      where tank.id = tank_decorations.tank_id
        and tank.owner_id = auth.uid()
    )
  );

create policy "users update decorations in own tank"
  on public.tank_decorations for update
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = tank_decorations.tank_id
        and tank.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.tanks tank
      where tank.id = tank_decorations.tank_id
        and tank.owner_id = auth.uid()
    )
  );

create policy "users delete decorations in own tank"
  on public.tank_decorations for delete
  using (
    exists (
      select 1 from public.tanks tank
      where tank.id = tank_decorations.tank_id
        and tank.owner_id = auth.uid()
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
      and publication_relation.prrelid = 'public.tank_decorations'::regclass
  ) then
    execute 'alter publication supabase_realtime add table public.tank_decorations';
  end if;
end;
$$;

commit;
