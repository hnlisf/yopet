-- F17/F18 lifecycle regression gate. This keeps the owner-checked whole-tank
-- feed transaction and the irreversible-but-gentle farewell contract in the
-- versioned pgTAP suite instead of relying on a manual acceptance script.

begin;

select plan(11);

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
    'f1700000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'f17f18-owner@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'f1700000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'f17f18-other@example.test',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(),
    now()
  );

select set_config(
  'f17f18.owner_tank_id',
  (
    select id::text
    from public.tanks
    where owner_id = 'f1700000-0000-4000-8000-000000000001'
  ),
  true
);

select set_config(
  'f17f18.other_tank_id',
  (
    select id::text
    from public.tanks
    where owner_id = 'f1700000-0000-4000-8000-000000000002'
  ),
  true
);

insert into public.fish (
  tank_id,
  species_id,
  variant_id,
  name,
  traits,
  satiety,
  custom_body,
  custom_tail,
  custom_pattern,
  custom_color
) values
  (
    current_setting('f17f18.owner_tank_id')::uuid,
    'goldfish',
    'goldfish_classic',
    'F17 饥饿鱼',
    array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid, '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid],
    40,
    null,
    null,
    null,
    null
  ),
  (
    current_setting('f17f18.owner_tank_id')::uuid,
    'goldfish',
    'goldfish_classic',
    'F17 接近饱腹鱼',
    array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid, '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid],
    90,
    null,
    null,
    null,
    null
  ),
  (
    current_setting('f17f18.owner_tank_id')::uuid,
    null,
    null,
    'F18 送别测试鱼',
    array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid, '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid],
    100,
    'disc',
    'fan',
    'wave',
    'orange'
  );

insert into public.fish (
  tank_id,
  species_id,
  variant_id,
  name,
  traits
) values (
  current_setting('f17f18.other_tank_id')::uuid,
  'goldfish',
  'goldfish_classic',
  'F18 其他人的鱼',
  array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid, '5f19d1f0-14d0-4e6a-9d0e-1bf389850003'::uuid]
);

select set_config(
  'f17f18.owner_fish_id',
  (
    select id::text
    from public.fish
    where name = 'F18 送别测试鱼'
  ),
  true
);

select set_config(
  'f17f18.other_fish_id',
  (
    select id::text
    from public.fish
    where name = 'F18 其他人的鱼'
  ),
  true
);

insert into public.growth_logs (fish_id, from_stage, to_stage, reason)
values (
  current_setting('f17f18.owner_fish_id')::uuid,
  'fry',
  'juvenile',
  'time'
);

set local request.jwt.claims =
  '{"sub":"f1700000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;

select set_config(
  'f17f18.feed_result_count',
  (
    select count(*)::text
    from public.feed_tank(current_setting('f17f18.owner_tank_id')::uuid)
  ),
  true
);

select set_config(
  'f17f18.feed_satiety',
  (
    select format(
      '%s,%s,%s',
      max(satiety) filter (where name = 'F17 饥饿鱼'),
      max(satiety) filter (where name = 'F17 接近饱腹鱼'),
      max(satiety) filter (where name = 'F18 送别测试鱼')
    )
    from public.fish
    where tank_id = current_setting('f17f18.owner_tank_id')::uuid
  ),
  true
);

select set_config(
  'f17f18.owner_log_count',
  (
    select count(*)::text
    from public.feeding_logs log
    join public.fish fish on fish.id = log.fish_id
    where fish.tank_id = current_setting('f17f18.owner_tank_id')::uuid
  ),
  true
);

select set_config(
  'f17f18.owner_log_amounts',
  (
    select string_agg(amount::text, ',' order by amount)
    from public.feeding_logs log
    join public.fish fish on fish.id = log.fish_id
    where fish.tank_id = current_setting('f17f18.owner_tank_id')::uuid
  ),
  true
);

reset role;

set local request.jwt.claims =
  '{"sub":"f1700000-0000-4000-8000-000000000002","role":"authenticated"}';
set local role authenticated;

do $$
begin
  begin
    perform public.feed_tank(current_setting('f17f18.owner_tank_id')::uuid);
    perform set_config('f17f18.cross_feed_rejected', 'false', true);
  exception
    when raise_exception then
      if sqlerrm <> 'tank_not_found_or_forbidden' then
        raise;
      end if;
      perform set_config('f17f18.cross_feed_rejected', 'true', true);
  end;
end;
$$;

do $$
declare
  deleted_rows integer;
begin
  delete from public.fish
  where id = current_setting('f17f18.owner_fish_id')::uuid;
  get diagnostics deleted_rows = row_count;
  perform set_config('f17f18.cross_delete_count', deleted_rows::text, true);
end;
$$;

reset role;

set local request.jwt.claims =
  '{"sub":"f1700000-0000-4000-8000-000000000001","role":"authenticated"}';
set local role authenticated;

do $$
declare
  deleted_rows integer;
begin
  delete from public.fish
  where id = current_setting('f17f18.owner_fish_id')::uuid;
  get diagnostics deleted_rows = row_count;
  perform set_config('f17f18.owner_delete_count', deleted_rows::text, true);
end;
$$;

reset role;

select is(
  current_setting('f17f18.feed_result_count'),
  '3',
  'feed_tank updates every resident in one call'
);

select is(
  current_setting('f17f18.feed_satiety'),
  '65,100,100',
  'feed_tank adds 25 and caps satiety at 100'
);

select is(
  current_setting('f17f18.owner_log_count'),
  '3',
  'feed_tank creates one feeding log for each resident'
);

select is(
  current_setting('f17f18.owner_log_amounts'),
  '25,25,25',
  'each whole-tank feeding log records the standard amount'
);

select is(
  current_setting('f17f18.cross_feed_rejected'),
  'true',
  'another owner cannot feed this tank'
);

select is(
  current_setting('f17f18.cross_delete_count'),
  '0',
  'another owner cannot release this fish'
);

select is(
  current_setting('f17f18.owner_delete_count'),
  '1',
  'the owner can release exactly the selected fish'
);

select is(
  (
    select count(*)
    from public.fish
    where id = current_setting('f17f18.owner_fish_id')::uuid
  ),
  0::bigint,
  'the released fish leaves the tank'
);

select is(
  (
    select count(*)
    from public.feeding_logs
    where fish_id = current_setting('f17f18.owner_fish_id')::uuid
  ),
  0::bigint,
  'farewell cascades to feeding logs'
);

select is(
  (
    select count(*)
    from public.growth_logs
    where fish_id = current_setting('f17f18.owner_fish_id')::uuid
  ),
  0::bigint,
  'farewell cascades to growth logs'
);

select is(
  (
    select count(*)
    from public.fish
    where id = current_setting('f17f18.other_fish_id')::uuid
  ),
  1::bigint,
  'another owner''s fish remains in its tank'
);

select * from finish();

rollback;
