-- F5 acceptance checks. Run after F3/F4 migrations, the F5 migration, and
-- supabase/seed.sql with:
-- docker exec -i supabase-db psql -U supabase_admin -d postgres \
--   -v ON_ERROR_STOP=1 < supabase/tests/f5_fish_domain.sql

begin;

do $$
begin
  if (select count(*) from public.personality_traits) <> 4 then
    raise exception 'Expected 4 personality traits';
  end if;

  if (select count(*) from public.fish_species) < 8 then
    raise exception 'Expected at least 8 fish species';
  end if;

  if (select count(*) from public.fish_variants) < 24 then
    raise exception 'Expected at least 24 fish variants';
  end if;

  if exists (
    select 1
    from public.fish_variants variant
    left join public.fish_species species on species.id = variant.species_id
    where species.id is null
  ) then
    raise exception 'Every fish variant must reference an existing species';
  end if;

  if exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in ('personality_traits', 'fish_species', 'fish_variants')
      and not relation.relrowsecurity
  ) then
    raise exception 'RLS must be enabled on all F5 tables';
  end if;

  if (select count(*) from pg_policies
      where schemaname = 'public'
        and tablename in ('personality_traits', 'fish_species', 'fish_variants')) <> 3 then
    raise exception 'Expected exactly three F5 policies';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in ('personality_traits', 'fish_species', 'fish_variants')
      and cmd <> 'SELECT'
  ) then
    raise exception 'F5 tables must not have write policies';
  end if;

  if exists (
    select 1
    from public.personality_traits
    where id is null
  ) then
    raise exception 'Every personality trait must have a UUID id';
  end if;
end;
$$;

set local role anon;
select set_config('f5_test.anon_species_count', count(*)::text, true)
from public.fish_species;
reset role;

do $$
begin
  if current_setting('f5_test.anon_species_count') <> '0' then
    raise exception 'Anonymous users must not read fish_species';
  end if;
end;
$$;

set local role authenticated;
set local request.jwt.claims = '{"role":"authenticated"}';
select set_config('f5_test.authenticated_species_count', count(*)::text, true)
from public.fish_species;
reset role;

do $$
begin
  if current_setting('f5_test.authenticated_species_count')::int < 8 then
    raise exception 'Authenticated users must read fish_species';
  end if;
end;
$$;

rollback;
