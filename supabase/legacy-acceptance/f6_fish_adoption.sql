-- F6 acceptance checks. Run after migrations and seed.sql.

begin;

do $$
begin
  if (select count(*) from public.fish_species) <> 12 then
    raise exception 'Expected 12 approved preset species';
  end if;

  if (select count(*) from public.fish_variants) <> 36 then
    raise exception 'Expected three variants for each preset species';
  end if;
end;
$$;

do $$
declare
  test_owner_id constant uuid := '6f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  other_owner_id constant uuid := '6f19d1f0-14d0-4e6a-9d0e-1bf389850002';
  owner_tank_id uuid;
  other_tank_id uuid;
  bold_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', test_owner_id,
    'authenticated', 'authenticated', 'f6-owner@example.com', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', other_owner_id,
    'authenticated', 'authenticated', 'f6-other@example.com', '',
    now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
  );

  select tank.id
    into owner_tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;

  select tank.id
    into other_tank_id
  from public.tanks tank
  where tank.owner_id = other_owner_id;

  perform set_config('f6_test.other_tank_id', other_tank_id::text, true);

  for fish_number in 1..5 loop
    insert into public.fish (
      tank_id, species_id, variant_id, name, traits
    ) values (
      owner_tank_id,
      'goldfish',
      'goldfish_classic',
      '测试鱼' || fish_number,
      array[bold_id]
    );
  end loop;

  if (select count(*) from public.fish where tank_id = owner_tank_id) <> 5 then
    raise exception 'Expected exactly five fish in the owner tank';
  end if;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits
  ) values (
    other_tank_id, 'angel', 'angel_silver', '别人的鱼', array[bold_id]
  );

  begin
    insert into public.fish (
      tank_id, species_id, variant_id, name, traits
    ) values (
      owner_tank_id, 'goldfish', 'goldfish_classic', '第六条', array[bold_id]
    );
    raise exception 'Sixth fish should have been rejected';
  exception
    when raise_exception then
      if sqlerrm <> 'tank_capacity_exceeded' then raise; end if;
  end;

  begin
    update public.fish
    set traits = array[bold_id, bold_id]
    where tank_id = owner_tank_id
      and name = '测试鱼1';
    raise exception 'Duplicate traits should have been rejected';
  exception
    when check_violation then
      if sqlerrm <> 'fish_traits_must_be_unique' then raise; end if;
  end;

  begin
    update public.fish
    set species_id = 'guppy', variant_id = 'goldfish_classic'
    where tank_id = owner_tank_id
      and name = '测试鱼1';
    raise exception 'Mismatched species and variant should have been rejected';
  exception
    when foreign_key_violation then
      if sqlerrm <> 'fish_variant_species_mismatch' then raise; end if;
  end;

  if exists (
    select 1 from public.fish
    where growth_stage <> 'fry' or satiety <> 80
  ) then
    raise exception 'Fish defaults must be fry and 80 satiety';
  end if;
end;
$$;

-- Exercise the policies as a real JWT-authenticated database role: only the
-- five rows in the signed-in owner's tank are visible, and an insert into a
-- different owner's tank is rejected.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"6f19d1f0-14d0-4e6a-9d0e-1bf389850001","role":"authenticated"}';

select set_config('f6_test.visible_fish_count', count(*)::text, true)
from public.fish;

do $$
begin
  begin
    insert into public.fish (
      tank_id, species_id, variant_id, name, traits
    ) values (
      current_setting('f6_test.other_tank_id')::uuid,
      'goldfish',
      'goldfish_classic',
      '越界领养',
      array['5f19d1f0-14d0-4e6a-9d0e-1bf389850001'::uuid]
    );
    raise exception 'Owner should not insert fish into another tank';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

do $$
begin
  if current_setting('f6_test.visible_fish_count') <> '5' then
    raise exception 'Owner must only see fish in their own tank';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'fish'
      and relation.relrowsecurity
  ) then
    raise exception 'RLS must be enabled on fish';
  end if;

  if (select count(*) from pg_policies
      where schemaname = 'public' and tablename = 'fish') <> 4 then
    raise exception 'Expected four owner-only fish policies';
  end if;
end;
$$;

rollback;
