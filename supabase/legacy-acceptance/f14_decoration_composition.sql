-- F14 verification: a decoration can retain a player-selected visual size
-- without influencing fish data. Run against the local Supabase database.

begin;

do $$
declare
  test_owner_id uuid := '00000000-0000-0000-0000-000000000014';
  tank_id uuid := '00000000-0000-0000-0000-000000000014';
  decoration_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', test_owner_id,
    'authenticated', 'authenticated', 'f14-decoration@example.test', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  select id into tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;

  if tank_id is null then
    raise exception 'F14 test user should receive an empty tank';
  end if;

  insert into public.tank_decorations (
    tank_id, decoration_code, decoration_type, position_x, position_y,
    scale_factor
  )
  values (tank_id, 'driftwood', 'driftwood', 0.50, 1.00, 0.75)
  returning id into decoration_id;

  update public.tank_decorations
  set scale_factor = 1.35
  where id = decoration_id;

  if (select scale_factor from public.tank_decorations where id = decoration_id)
      <> 1.35 then
    raise exception 'F14 must preserve an edited decoration scale';
  end if;

  begin
    update public.tank_decorations
    set scale_factor = 1.60
    where id = decoration_id;
    raise exception 'F14 must reject an out-of-range decoration scale';
  exception when check_violation then
    null;
  end;
end;
$$;

rollback;
