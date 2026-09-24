-- Accept the vertical wave marking introduced by the custom-fish studio.
--
-- Existing custom fish retain their original eight patterns; this only extends
-- the allowed set used by the appearance consistency constraint.

begin;

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
      and custom_body = any (array['round', 'light', 'diamond', 'disc', 'torpedo', 'bottom', 'box', 'eel'])
      and custom_tail = any (array['petal', 'fan', 'ribbon'])
      and custom_pattern = any (array['cloud', 'pearl', 'tiger', 'zebra', 'neon', 'saddle', 'eye', 'wave', 'belly'])
      and custom_color = any (array['orange', 'yellow', 'red', 'coral', 'pink', 'green', 'mint', 'teal', 'cyan', 'blue', 'violet', 'indigo'])
    )
  );

-- The before-insert trigger maintains the same catalogue/custom-appearance
-- contract separately from the table constraint. Keep the two allow-lists in
-- lockstep so a valid new pattern is not rejected after the constraint passes.
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
      and new.custom_pattern in ('cloud', 'pearl', 'tiger', 'zebra', 'neon', 'saddle', 'eye', 'wave', 'belly')
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

commit;
