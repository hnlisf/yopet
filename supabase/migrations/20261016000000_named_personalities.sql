alter table public.fish add column personality_code text
  check (personality_code in ('enthusiastic','gentle','cautious','quiet'));

create function public.named_personality_codes(value text)
returns text[] language sql immutable set search_path = public as $$
  select case value
    when 'enthusiastic' then array['bold','curious']
    when 'gentle' then array['bold','lazy']
    when 'cautious' then array['curious','shy']
    when 'quiet' then array['lazy','shy'] end;
$$;

-- Only exact old combinations are mapped. Ambiguous residents stay untouched.
update public.fish f set personality_code = p.code
from (values ('enthusiastic'),('gentle'),('cautious'),('quiet')) p(code)
where (select array_agg(t.code order by t.code) from public.personality_traits t
       where t.id = any(f.traits)) = public.named_personality_codes(p.code)
  and cardinality(f.traits) = 2;

create function public.sync_named_personality()
returns trigger language plpgsql set search_path = public as $$
declare codes text[]; chosen text; ids uuid[];
begin
  -- Old clients may send only the compatible pair. Infer the single identity.
  if new.personality_code is null or
     (tg_op = 'UPDATE' and new.traits is distinct from old.traits
      and new.personality_code is not distinct from old.personality_code) then
    select array_agg(t.code order by t.code) into codes
      from public.personality_traits t where t.id = any(new.traits);
    select p into chosen from unnest(array['enthusiastic','gentle','cautious','quiet']) p
      where public.named_personality_codes(p) = codes and cardinality(new.traits) = 2;
    new.personality_code := chosen;
  end if;
  if new.personality_code is null then
    raise exception using errcode = '23514', message = 'choose_one_named_personality';
  end if;
  select array_agg(id order by code) into ids from public.personality_traits
    where code = any(public.named_personality_codes(new.personality_code));
  if cardinality(ids) is distinct from 2 then
    raise exception 'personality_catalog_incomplete';
  end if;
  new.traits := ids;
  return new;
end;
$$;
-- Sort before existing catalogue/compatibility validators.
create trigger a_named_personality before insert or update of personality_code, traits
on public.fish for each row execute function public.sync_named_personality();
