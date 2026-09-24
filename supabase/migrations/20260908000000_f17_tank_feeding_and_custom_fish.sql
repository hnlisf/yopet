-- F17: feed the aquarium as one gentle action and persist modular custom fish.
--
-- The client experiences one sprinkling action, while each resident keeps its
-- own satiety update and feeding log. A custom fish intentionally has no
-- catalogue species/variant: its visual identity is the four stored parts.

begin;

alter table public.fish
  add column if not exists custom_body text,
  add column if not exists custom_tail text,
  add column if not exists custom_pattern text,
  add column if not exists custom_color text;

alter table public.fish
  alter column species_id drop not null,
  alter column variant_id drop not null;

alter table public.fish
  drop constraint if exists fish_custom_appearance_consistency;

alter table public.fish
  add constraint fish_custom_appearance_consistency check (
    (
      species_id is not null
      and variant_id is not null
      and custom_body is null
      and custom_tail is null
      and custom_pattern is null
      and custom_color is null
    )
    or
    (
      species_id is null
      and variant_id is null
      and custom_body in ('round', 'light', 'diamond', 'disc', 'torpedo', 'bottom', 'box', 'eel')
      and custom_tail in ('petal', 'fan', 'ribbon')
      and custom_pattern in ('cloud', 'pearl', 'tiger', 'zebra', 'neon', 'saddle', 'eye', 'belly')
      and custom_color in (
        'orange', 'yellow', 'red', 'coral', 'pink', 'green',
        'mint', 'teal', 'cyan', 'blue', 'violet', 'indigo'
      )
    )
  );

-- F6's catalogue validation now has a second, strict path for modular fish.
-- Keeping it in the existing trigger preserves trait validation and capacity
-- guarantees for both kinds of fish.
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

  if new.species_id is null or new.variant_id is null then
    if not (
      new.species_id is null
      and new.variant_id is null
      and new.custom_body in ('round', 'light', 'diamond', 'disc', 'torpedo', 'bottom', 'box', 'eel')
      and new.custom_tail in ('petal', 'fan', 'ribbon')
      and new.custom_pattern in ('cloud', 'pearl', 'tiger', 'zebra', 'neon', 'saddle', 'eye', 'belly')
      and new.custom_color in (
        'orange', 'yellow', 'red', 'coral', 'pink', 'green',
        'mint', 'teal', 'cyan', 'blue', 'violet', 'indigo'
      )
    ) then
      raise exception using
        errcode = '23514',
        message = 'fish_custom_appearance_invalid';
    end if;
    return new;
  end if;

  if new.custom_body is not null
      or new.custom_tail is not null
      or new.custom_pattern is not null
      or new.custom_color is not null then
    raise exception using
      errcode = '23514',
      message = 'fish_catalog_and_custom_appearance_conflict';
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
  before insert or update of
    species_id, variant_id, traits,
    custom_body, custom_tail, custom_pattern, custom_color
  on public.fish
  for each row execute function public.validate_fish_catalog_references();

create or replace function public.feed_tank(target_tank_id uuid)
returns setof public.fish
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.tanks tank
    where tank.id = target_tank_id
      and tank.owner_id = auth.uid()
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'tank_not_found_or_forbidden';
  end if;

  return query
  with fed as (
    update public.fish fish
    set
      satiety = least(100, fish.satiety + 25),
      satiety_updated_at = now()
    where fish.tank_id = target_tank_id
    returning fish.*
  ),
  logged as (
    insert into public.feeding_logs (fish_id, amount)
    select id, 25 from fed
  )
  select * from fed;
end;
$$;

revoke all on function public.feed_tank(uuid) from public;
grant execute on function public.feed_tank(uuid) to authenticated;

commit;
