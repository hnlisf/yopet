begin;
select plan(3);
-- Exercise the same trigger function without mutating any resident fish.
create temporary table personality_probe (traits uuid[]);
create trigger probe_compatibility before insert or update of traits
on personality_probe for each row execute function public.validate_personality_compatibility();
select throws_ok(
  $$insert into personality_probe select array_agg(id) from public.personality_traits where code in ('bold', 'shy')$$,
  '23514', 'fish_personality_conflict', 'bold and shy cannot coexist');
select lives_ok(
  $$insert into personality_probe select array_agg(id) from public.personality_traits where code in ('bold', 'curious')$$,
  'bold and curious remain compatible');
select throws_ok(
  $$update personality_probe set traits = (select array_agg(id) from public.personality_traits where code in ('bold', 'shy'))$$,
  '23514', 'fish_personality_conflict', 'updates cannot introduce conflict');
select * from finish();
rollback;
