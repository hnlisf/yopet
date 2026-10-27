-- P0 regression gate: a fresh database must have the complete Yopet domain
-- schema, enforced owner isolation, and a saveable custom fish using "wave".
--
-- supabase test db runs this file with pgTAP in CI.

begin;

select plan(13);

select ok(to_regclass('public.profiles') is not null, 'profiles table exists');
select ok(to_regclass('public.tanks') is not null, 'tanks table exists');
select ok(to_regclass('public.fish') is not null, 'fish table exists');
select ok(to_regclass('public.tank_decorations') is not null, 'tank decorations table exists');
select ok(to_regclass('public.feeding_logs') is not null, 'feeding logs table exists');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.fish'::regclass),
  'fish has row-level security enabled'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fish'
      and policyname = 'users insert fish in own tank'
  ),
  'fish insert policy restricts writes to the owner tank'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fish'::regclass
      and conname = 'fish_custom_appearance_consistency'
      and pg_get_constraintdef(oid) like '%''wave''%'
  ),
  'custom-fish constraint accepts wave'
);

select ok(
  pg_get_functiondef(
    'public.validate_fish_catalog_references()'::regprocedure
  ) like '%''wave''%',
  'custom-fish trigger accepts wave'
);

select ok(
  to_regprocedure('public.feed_tank(uuid)') is not null,
  'tank feeding RPC exists'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    'f0a00000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'p0-owner@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'f0a00000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'p0-other@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  );

select is(
  (select count(*) from public.tanks where owner_id in (
    'f0a00000-0000-4000-8000-000000000001',
    'f0a00000-0000-4000-8000-000000000002'
  )),
  2::bigint,
  'signup triggers create one tank per user'
);

select set_config(
  'p0.owner_tank_id',
  (select id::text from public.tanks
   where owner_id = 'f0a00000-0000-4000-8000-000000000001'),
  true
);

select set_config(
  'p0.other_tank_id',
  (select id::text from public.tanks
   where owner_id = 'f0a00000-0000-4000-8000-000000000002'),
  true
);

set local request.jwt.claims =
  '{"sub":"f0a00000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;

insert into public.fish (
  tank_id,
  species_id,
  variant_id,
  name,
  traits,
  custom_body,
  custom_tail,
  custom_pattern,
  custom_color
) values (
  current_setting('p0.owner_tank_id')::uuid,
  null,
  null,
  '波浪纹回归测试',
  array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid, '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid],
  'disc',
  'fan',
  'wave',
  'orange'
);

select set_config(
  'p0.owner_wave_fish_count',
  (select count(*)::text from public.fish
   where tank_id = current_setting('p0.owner_tank_id')::uuid
     and custom_pattern = 'wave'),
  true
);

reset role;

select is(
  current_setting('p0.owner_wave_fish_count'),
  '1',
  'an owner can save a wave-pattern custom fish'
);

set local request.jwt.claims =
  '{"sub":"f0a00000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;

select set_config(
  'p0.other_visible_owner_fish_count',
  (select count(*)::text from public.fish
   where tank_id = current_setting('p0.owner_tank_id')::uuid),
  true
);

reset role;

select is(
  current_setting('p0.other_visible_owner_fish_count'),
  '0',
  'RLS hides one owner''s fish from another owner'
);

select * from finish();

rollback;
