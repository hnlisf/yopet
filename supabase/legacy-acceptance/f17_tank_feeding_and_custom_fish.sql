-- F17 acceptance checks. Run after migrations and seed.sql.

begin;

do $$
declare
  test_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850017';
  test_other_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850018';
  bold_trait_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  owner_tank_id uuid;
  other_tank_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (
      '00000000-0000-0000-0000-000000000000', test_owner_id,
      'authenticated', 'authenticated', 'f17-owner@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000', test_other_owner_id,
      'authenticated', 'authenticated', 'f17-other@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    );

  select id into owner_tank_id from public.tanks where owner_id = test_owner_id;
  select id into other_tank_id from public.tanks where owner_id = test_other_owner_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits, satiety
  ) values
    (owner_tank_id, 'goldfish', 'goldfish_classic', '整缸测试一号', array[bold_trait_id], 50),
    (owner_tank_id, 'guppy', 'guppy_lagoon', '整缸测试二号', array[bold_trait_id], 90),
    (other_tank_id, 'goldfish', 'goldfish_classic', '其他人的鱼', array[bold_trait_id], 40);

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits,
    custom_body, custom_tail, custom_pattern, custom_color
  ) values (
    owner_tank_id, null, null, '云尾', array[bold_trait_id],
    'round', 'petal', 'cloud', 'orange'
  );

  perform set_config('f17.owner_tank_id', owner_tank_id::text, true);
  perform set_config('f17.other_tank_id', other_tank_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"8f19d1f0-14d0-4e6a-9d0e-1bf389850017","role":"authenticated"}';

select public.feed_tank(current_setting('f17.owner_tank_id')::uuid);

do $$
declare
  first_satiety smallint;
  second_satiety smallint;
  custom_count integer;
  log_count integer;
begin
  select satiety into first_satiety from public.fish where name = '整缸测试一号';
  select satiety into second_satiety from public.fish where name = '整缸测试二号';
  select count(*) into custom_count
  from public.fish
  where name = '云尾'
    and species_id is null
    and variant_id is null
    and custom_body = 'round'
    and custom_tail = 'petal'
    and custom_pattern = 'cloud'
    and custom_color = 'orange';
  select count(*) into log_count
  from public.feeding_logs log
  join public.fish fish on fish.id = log.fish_id
  where fish.tank_id = current_setting('f17.owner_tank_id')::uuid;

  if first_satiety <> 75 or second_satiety <> 100 then
    raise exception 'Tank feeding must update every owned fish and cap at 100';
  end if;
  if custom_count <> 1 then
    raise exception 'A custom fish must persist its four visual choices';
  end if;
  if log_count <> 3 then
    raise exception 'Tank feeding must write one log per resident';
  end if;
end;
$$;

do $$
begin
  begin
    perform public.feed_tank(current_setting('f17.other_tank_id')::uuid);
    raise exception 'Owner should not be able to feed another owner''s tank';
  exception
    when raise_exception then
      if sqlerrm <> 'tank_not_found_or_forbidden' then raise; end if;
  end;
end;
$$;

reset role;
rollback;
