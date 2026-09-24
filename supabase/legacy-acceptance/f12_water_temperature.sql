-- F12 acceptance checks. Run after F11 and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := 'af19d1f0-14d0-4e6a-9d0e-1bf389850002';
  owner_tank_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', test_owner_id,
    'authenticated', 'authenticated', 'f12-owner@example.com', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  select tank.id into owner_tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;

  perform set_config('f12_test.owner_tank_id', owner_tank_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"af19d1f0-14d0-4e6a-9d0e-1bf389850002","role":"authenticated"}';

do $$
declare
  stored_temperature smallint;
begin
  select water_temperature_c into stored_temperature
  from public.tanks
  where id = current_setting('f12_test.owner_tank_id')::uuid;

  if stored_temperature <> 24 then
    raise exception 'New tanks must begin with a comfortable 24°C default';
  end if;
end;
$$;

update public.tanks
set water_temperature_c = 28
where id = current_setting('f12_test.owner_tank_id')::uuid;

do $$
begin
  if not exists (
    select 1 from public.tanks
    where id = current_setting('f12_test.owner_tank_id')::uuid
      and water_temperature_c = 28
  ) then
    raise exception 'Tank owner must be able to save a selected temperature';
  end if;
end;
$$;

do $$
begin
  begin
    update public.tanks
    set water_temperature_c = 31
    where id = current_setting('f12_test.owner_tank_id')::uuid;
    raise exception 'Out-of-range water temperature must not be accepted';
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
    raise exception 'Water temperature must remain inside tanks RLS';
  end if;
end;
$$;

rollback;
