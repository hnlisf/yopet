-- F9 acceptance checks. Run after migrations and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  test_other_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850002';
  bold_trait_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  owner_tank_id uuid;
  other_tank_id uuid;
  owner_fish_id uuid;
  fed_fish_id uuid;
  other_fish_id uuid;
  synced_satiety smallint;
  fed_satiety smallint;
  visible_log_count integer;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (
      '00000000-0000-0000-0000-000000000000', test_owner_id,
      'authenticated', 'authenticated', 'f9-owner@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000', test_other_owner_id,
      'authenticated', 'authenticated', 'f9-other@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    );

  select tank.id into owner_tank_id
  from public.tanks tank
  where tank.owner_id = test_owner_id;
  select tank.id into other_tank_id
  from public.tanks tank
  where tank.owner_id = test_other_owner_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits, satiety, satiety_updated_at
  ) values (
    owner_tank_id, 'goldfish', 'goldfish_classic', '低饱食测试鱼',
    array[bold_trait_id], 35, now() - interval '5 hours'
  ) returning id into owner_fish_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits, satiety, satiety_updated_at
  ) values (
    owner_tank_id, 'goldfish', 'goldfish_classic', '饱食上限测试鱼',
    array[bold_trait_id], 90, now()
  ) returning id into fed_fish_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits
  ) values (
    other_tank_id, 'goldfish', 'goldfish_classic', '别人的测试鱼',
    array[bold_trait_id]
  ) returning id into other_fish_id;

  perform set_config('f9_test.owner_tank_id', owner_tank_id::text, true);
  perform set_config('f9_test.owner_fish_id', owner_fish_id::text, true);
  perform set_config('f9_test.fed_fish_id', fed_fish_id::text, true);
  perform set_config('f9_test.other_fish_id', other_fish_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"8f19d1f0-14d0-4e6a-9d0e-1bf389850001","role":"authenticated"}';

select public.sync_tank_satiety(current_setting('f9_test.owner_tank_id')::uuid);

do $$
declare
  current_satiety smallint;
begin
  select satiety into current_satiety
  from public.fish
  where id = current_setting('f9_test.owner_fish_id')::uuid;
  if current_satiety <> 25 then
    raise exception 'Five hours must decay 35 satiety to 25, got %', current_satiety;
  end if;
end;
$$;

select public.feed_fish(current_setting('f9_test.fed_fish_id')::uuid);

do $$
declare
  current_satiety smallint;
  log_amount smallint;
begin
  select satiety into current_satiety
  from public.fish
  where id = current_setting('f9_test.fed_fish_id')::uuid;
  if current_satiety <> 100 then
    raise exception 'Feeding must cap satiety at 100, got %', current_satiety;
  end if;

  select amount into log_amount
  from public.feeding_logs
  where fish_id = current_setting('f9_test.fed_fish_id')::uuid;
  if log_amount <> 25 then
    raise exception 'Feeding log must store the default amount 25';
  end if;
end;
$$;

do $$
begin
  begin
    perform public.feed_fish(current_setting('f9_test.other_fish_id')::uuid);
    raise exception 'Owner should not be able to feed another owner''s fish';
  exception
    when raise_exception then
      if sqlerrm <> 'fish_not_found_or_forbidden' then raise; end if;
  end;
end;
$$;

select set_config('f9_test.visible_log_count', count(*)::text, true)
from public.feeding_logs;

reset role;

do $$
begin
  if current_setting('f9_test.visible_log_count') <> '1' then
    raise exception 'Owner must only read their own feeding logs';
  end if;

  if not exists (
    select 1 from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'feeding_logs'
      and relation.relrowsecurity
  ) then
    raise exception 'feeding_logs must have RLS enabled';
  end if;
end;
$$;

rollback;
