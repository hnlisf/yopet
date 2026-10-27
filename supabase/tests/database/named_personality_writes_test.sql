begin;
select plan(11);
create temporary table named_probe (id int, personality_code text, traits uuid[]);
-- A pre-migration resident is not automatically rewritten.
insert into named_probe select 9,null,array_agg(id)
  from public.personality_traits where code in ('bold','shy');
create trigger named_probe_sync before insert or update of personality_code, traits
on named_probe for each row execute function public.sync_named_personality();

select lives_ok($$insert into named_probe values (1,'enthusiastic',null)$$,
  'new client can write a single personality code');
select is((select cardinality(traits) from named_probe where id=1),2,
  'server generates the compatibility pair');
select lives_ok($$insert into named_probe select 2,null,array_agg(id order by code)
  from public.personality_traits where code in ('shy','curious')$$,
  'old client can write a supported pair');
select is((select personality_code from named_probe where id=2),'cautious',
  'server infers the authoritative identity');
select throws_ok($$insert into named_probe select 3,null,array_agg(id)
  from public.personality_traits where code in ('bold','shy')$$,
  '23514','choose_one_named_personality','contradictory combinations rejected');
select throws_ok($$insert into named_probe select 4,null,array_agg(id)
  from public.personality_traits where code='bold'$$,
  '23514','choose_one_named_personality','single legacy trait cannot create a new resident');
select lives_ok($$update named_probe set personality_code='quiet' where id=1$$,
  'explicit personality changes are supported');
select is((select array_agg(t.code order by t.code) from named_probe p
  join public.personality_traits t on t.id=any(p.traits) where p.id=1),
  array['lazy','shy'],'compatibility traits follow the changed identity');
select lives_ok($$update named_probe set id=10 where id=9$$,
  'unrelated writes to a legacy resident are not blocked');
select is((select personality_code from named_probe where id=10),null::text,
  'ambiguous legacy identity is not guessed');
select lives_ok($$update named_probe set personality_code='gentle' where id=10$$,
  'owner can explicitly resolve an ambiguous legacy identity');
select * from finish();
rollback;
