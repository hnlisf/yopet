-- F11 acceptance checks. Run after F10 and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := 'af19d1f0-14d0-4e6a-9d0e-1bf389850001';
  owner_tank_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', test_owner_id,
    'authenticated', 'authenticated', 'f11-owner@example.com', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  select tank.id into owner_tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;

  perform set_config('f11_test.owner_tank_id', owner_tank_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"af19d1f0-14d0-4e6a-9d0e-1bf389850001","role":"authenticated"}';

update public.tanks
set
  weather_city_name = '上海',
  weather_latitude = 31.2304,
  weather_longitude = 121.4737,
  weather_code = 63,
  weather_temperature_c = 24.5,
  weather_is_day = true,
  weather_observed_at = now()
where id = current_setting('f11_test.owner_tank_id')::uuid;

do $$
declare
  snapshot record;
begin
  select
    weather_city_name,
    weather_code,
    weather_temperature_c,
    weather_is_day,
    weather_observed_at
  into snapshot
  from public.tanks
  where id = current_setting('f11_test.owner_tank_id')::uuid;

  if snapshot.weather_city_name <> '上海'
      or snapshot.weather_code <> 63
      or snapshot.weather_temperature_c <> 24.5
      or snapshot.weather_is_day is not true
      or snapshot.weather_observed_at is null then
    raise exception 'Tank must retain a complete selected-city weather snapshot';
  end if;
end;
$$;

do $$
begin
  begin
    update public.tanks
    set weather_code = null
    where id = current_setting('f11_test.owner_tank_id')::uuid;
    raise exception 'A partial weather snapshot must not be accepted';
  exception
    when check_violation then null;
  end;
end;
$$;

reset role;

do $$
begin
  if not exists (
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'tanks'
      and relation.relrowsecurity
  ) then
    raise exception 'Weather snapshots must remain inside tanks RLS';
  end if;
end;
$$;

rollback;
