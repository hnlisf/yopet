-- F7 acceptance checks. Run after F3-F7 migrations and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := '7f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  test_other_owner_id constant uuid := '7f19d1f0-14d0-4e6a-9d0e-1bf389850002';
  owner_tank_id uuid;
  other_tank_id uuid;
  bold_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  fish_satiety smallint;
  fish_stage public.fish_growth_stage;
  fish_traits uuid[];
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    ('00000000-0000-0000-0000-000000000000', test_owner_id,
     'authenticated', 'authenticated', 'f7-owner@example.com', '',
     now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', test_other_owner_id,
     'authenticated', 'authenticated', 'f7-other@example.com', '',
     now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

  select tank.id into owner_tank_id
  from public.tanks tank where tank.owner_id = test_owner_id;
  select tank.id into other_tank_id
  from public.tanks tank where tank.owner_id = test_other_owner_id;
  perform set_config('f7_test.other_tank_id', other_tank_id::text, true);

  insert into public.fish (tank_id, species_id, variant_id, name, traits)
  values (
    owner_tank_id, 'goldfish', 'goldfish_classic', '装饰旁的鱼', array[bold_id]
  );

  select satiety, growth_stage, traits
    into fish_satiety, fish_stage, fish_traits
  from public.fish where tank_id = owner_tank_id;

  insert into public.tank_decorations (
    tank_id, decoration_code, decoration_type, position_x, position_y
  ) values (owner_tank_id, 'long_plant', 'plant', 0.30, 0.75);

  update public.tank_decorations
  set position_x = 0.42, position_y = 0.68
  where tank_id = owner_tank_id and decoration_code = 'long_plant';

  delete from public.tank_decorations
  where tank_id = owner_tank_id and decoration_code = 'long_plant';

  if exists (
    select 1 from public.fish
    where tank_id = owner_tank_id
      and (satiety <> fish_satiety
        or growth_stage <> fish_stage
        or traits <> fish_traits)
  ) then
    raise exception 'Decorations must not change fish state';
  end if;

  insert into public.tank_decorations (
    tank_id, decoration_code, decoration_type
  ) values (owner_tank_id, 'midnight', 'background');

  begin
    insert into public.tank_decorations (
      tank_id, decoration_code, decoration_type
    ) values (owner_tank_id, 'aurora', 'background');
    raise exception 'A tank should only have one active background';
  exception
    when unique_violation then null;
  end;

  begin
    insert into public.tank_decorations (
      tank_id, decoration_code, decoration_type
    ) values (owner_tank_id, 'long_plant', 'stone');
    raise exception 'Decoration code and type mismatch should be rejected';
  exception
    when check_violation then
      if sqlerrm <> 'tank_decoration_type_code_mismatch' then raise; end if;
  end;
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"7f19d1f0-14d0-4e6a-9d0e-1bf389850001","role":"authenticated"}';

select set_config('f7_test.visible_decorations', count(*)::text, true)
from public.tank_decorations;

do $$
begin
  begin
    insert into public.tank_decorations (
      tank_id, decoration_code, decoration_type
    ) values (
      current_setting('f7_test.other_tank_id')::uuid,
      'long_plant', 'plant'
    );
    raise exception 'Owner should not decorate another users tank';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

do $$
begin
  if current_setting('f7_test.visible_decorations') <> '1' then
    raise exception 'Owner must only see decorations in their own tank';
  end if;

  if not exists (
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'tank_decorations'
      and relation.relrowsecurity
  ) then
    raise exception 'RLS must be enabled on tank_decorations';
  end if;

  if (select count(*) from pg_policies
      where schemaname = 'public' and tablename = 'tank_decorations') <> 4 then
    raise exception 'Expected four owner-only decoration policies';
  end if;
end;
$$;

rollback;
