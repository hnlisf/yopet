-- Existing residents are deliberately left unchanged.
create or replace function public.validate_personality_compatibility()
returns trigger language plpgsql set search_path = public as $$
begin
  if exists (select 1 from public.personality_traits
      where id = any(new.traits) and code = 'bold')
    and exists (select 1 from public.personality_traits
      where id = any(new.traits) and code = 'shy') then
    raise exception using errcode = '23514', message = 'fish_personality_conflict';
  end if;
  return new;
end;
$$;
create trigger fish_personality_compatibility
before insert or update of traits on public.fish
for each row execute function public.validate_personality_compatibility();
