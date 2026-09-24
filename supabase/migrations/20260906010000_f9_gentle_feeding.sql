-- F9: gentle feeding and elapsed-time satiety decay.
-- Satiety only changes presentation. Reaching zero never creates illness,
-- removal, or any other failure state (ADR-0001).

begin;

alter table public.fish
  add column if not exists satiety_updated_at timestamptz not null default now();

create table if not exists public.feeding_logs (
  id uuid primary key default gen_random_uuid(),
  fish_id uuid not null references public.fish(id) on delete cascade,
  fed_at timestamptz not null default now(),
  amount smallint not null default 25 check (amount between 1 and 100)
);

create index if not exists feeding_logs_fish_fed_at_idx
  on public.feeding_logs (fish_id, fed_at desc);

alter table public.feeding_logs enable row level security;

drop policy if exists "users read feeding logs for own fish" on public.feeding_logs;
create policy "users read feeding logs for own fish"
  on public.feeding_logs for select
  using (
    exists (
      select 1
      from public.fish fish
      join public.tanks tank on tank.id = fish.tank_id
      where fish.id = feeding_logs.fish_id
        and tank.owner_id = auth.uid()
    )
  );

-- The amount is intentionally not a client parameter. The product has one
-- gentle feeding action (+25), and this function keeps the state update and
-- log insert atomic.
create or replace function public.feed_fish(target_fish_id uuid)
returns public.fish
language plpgsql
security definer
set search_path = public
as $$
declare
  fed_fish public.fish;
begin
  update public.fish fish
  set
    satiety = least(100, fish.satiety + 25),
    satiety_updated_at = now()
  where fish.id = target_fish_id
    and exists (
      select 1
      from public.tanks tank
      where tank.id = fish.tank_id
        and tank.owner_id = auth.uid()
    )
  returning fish.* into fed_fish;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'fish_not_found_or_forbidden';
  end if;

  insert into public.feeding_logs (fish_id, amount)
  values (fed_fish.id, 25);

  return fed_fish;
end;
$$;

-- This is explicitly invoked by the app when it opens its tank. It is not a
-- cron job or trigger. Advancing by whole intervals preserves a partial
-- interval across repeated opens, preventing double decay on multiple devices.
create or replace function public.sync_tank_satiety(
  target_tank_id uuid,
  observed_at timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.tanks tank
    where tank.id = target_tank_id
      and tank.owner_id = auth.uid()
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'tank_not_found_or_forbidden';
  end if;

  with elapsed as (
    select
      fish.id,
      floor(
        greatest(
          0,
          extract(epoch from observed_at - fish.satiety_updated_at) / 1800
        )
      )::integer as intervals
    from public.fish fish
    where fish.tank_id = target_tank_id
  )
  update public.fish fish
  set
    satiety = greatest(0, fish.satiety - elapsed.intervals),
    satiety_updated_at = fish.satiety_updated_at +
      elapsed.intervals * interval '30 minutes'
  from elapsed
  where fish.id = elapsed.id
    and elapsed.intervals > 0;
end;
$$;

revoke all on function public.feed_fish(uuid) from public;
revoke all on function public.sync_tank_satiety(uuid, timestamptz) from public;
grant execute on function public.feed_fish(uuid) to authenticated;
grant execute on function public.sync_tank_satiety(uuid, timestamptz) to authenticated;

commit;
