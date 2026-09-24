-- F18 acceptance checks. The feature reuses F6's owner-only fish delete
-- policy; this test protects the farewell and cascade contract.

begin;

do $$
declare
  test_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850118';
  test_other_owner_id constant uuid := '8f19d1f0-14d0-4e6a-9d0e-1bf389850119';
  bold_trait_id constant uuid := '5f19d1f0-14d0-4e6a-9d0e-1bf389850001';
  owner_tank_id uuid;
  other_tank_id uuid;
  owner_fish_id uuid;
  other_fish_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (
      '00000000-0000-0000-0000-000000000000', test_owner_id,
      'authenticated', 'authenticated', 'f18-owner@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000', test_other_owner_id,
      'authenticated', 'authenticated', 'f18-other@example.com', '',
      now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    );

  select id into owner_tank_id from public.tanks where owner_id = test_owner_id;
  select id into other_tank_id from public.tanks where owner_id = test_other_owner_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits
  ) values (
    owner_tank_id, 'goldfish', 'goldfish_classic', 'F18 送别测试鱼',
    array[bold_trait_id]
  ) returning id into owner_fish_id;

  insert into public.fish (
    tank_id, species_id, variant_id, name, traits
  ) values (
    other_tank_id, 'goldfish', 'goldfish_classic', 'F18 其他人的鱼',
    array[bold_trait_id]
  ) returning id into other_fish_id;

  insert into public.feeding_logs (fish_id, amount)
  values (owner_fish_id, 25);
  insert into public.growth_logs (fish_id, from_stage, to_stage, reason)
  values (owner_fish_id, 'fry', 'juvenile', 'time');

  perform set_config('f18.owner_fish_id', owner_fish_id::text, true);
  perform set_config('f18.other_fish_id', other_fish_id::text, true);
end;
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"8f19d1f0-14d0-4e6a-9d0e-1bf389850118","role":"authenticated"}';

do $$
declare
  affected_rows integer;
begin
  delete from public.fish
  where id = current_setting('f18.owner_fish_id')::uuid;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Owner must be able to release exactly their selected fish';
  end if;

  delete from public.fish
  where id = current_setting('f18.other_fish_id')::uuid;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'Owner must not release another owner''s fish';
  end if;
end;
$$;

reset role;

do $$
begin
  if exists (
    select 1 from public.feeding_logs
    where fish_id = current_setting('f18.owner_fish_id')::uuid
  ) then
    raise exception 'Farewell must cascade to feeding logs';
  end if;
  if exists (
    select 1 from public.growth_logs
    where fish_id = current_setting('f18.owner_fish_id')::uuid
  ) then
    raise exception 'Farewell must cascade to growth logs';
  end if;
  if not exists (
    select 1 from public.fish
    where id = current_setting('f18.other_fish_id')::uuid
  ) then
    raise exception 'Another owner''s fish must remain in its tank';
  end if;
end;
$$;

rollback;
