-- F10 acceptance checks. Run after F9 migration and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := '9f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  bold_trait_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  owner_tank_id uuid;
  juvenile_fish_id uuid;
  adult_fish_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', test_owner_id,
    'authenticated', 'authenticated', 'f10-owner@example.com', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  select tank.id into owner_tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits, created_at
  ) values (
    owner_tank_id, 'goldfish', 'goldfish_classic', '八天小鱼',
    array[bold_trait_id], now() - interval '8 days'
  ) returning id into juvenile_fish_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits, created_at
  ) values (
    owner_tank_id, 'goldfish', 'goldfish_classic', '二十二天小鱼',
    array[bold_trait_id], now() - interval '22 days'
  ) returning id into adult_fish_id;

  perform set_config('f10_test.owner_tank_id', owner_tank_id::text, true);
  perform set_config('f10_test.juvenile_fish_id', juvenile_fish_id::text, true);
  perform set_config('f10_test.adult_fish_id', adult_fish_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"9f19d1f0-14d0-4e6a-9d0e-1bf389850001","role":"authenticated"}';

select public.sync_tank_growth(current_setting('f10_test.owner_tank_id')::uuid);

do $$
declare
  juvenile_stage public.fish_growth_stage;
  adult_stage public.fish_growth_stage;
begin
  select growth_stage into juvenile_stage
  from public.fish
  where id = current_setting('f10_test.juvenile_fish_id')::uuid;
  if juvenile_stage <> 'juvenile' then
    raise exception 'An eight-day goldfish must become juvenile, got %', juvenile_stage;
  end if;

  select growth_stage into adult_stage
  from public.fish
  where id = current_setting('f10_test.adult_fish_id')::uuid;
  if adult_stage <> 'adult' then
    raise exception 'A twenty-two-day goldfish must become adult, got %', adult_stage;
  end if;
end;
$$;

select set_config('f10_test.visible_growth_log_count', count(*)::text, true)
from public.growth_logs;

reset role;

do $$
begin
  if current_setting('f10_test.visible_growth_log_count') <> '3' then
    raise exception 'Expected juvenile log plus two sequential adult logs';
  end if;

  if not exists (
    select 1 from public.growth_logs
    where fish_id = current_setting('f10_test.adult_fish_id')::uuid
      and from_stage = 'fry'
      and to_stage = 'juvenile'
      and reason = 'time'
  ) then
    raise exception 'Adult promotion must retain the fry to juvenile time log';
  end if;
end;
$$;

rollback;
