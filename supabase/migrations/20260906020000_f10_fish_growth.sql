-- F10: time-led fish growth with a gentle feeding acceleration.

begin;

alter table public.fish_species
  add column if not exists growth_days_to_juvenile_with_feed_acceleration integer
    not null default 5 check (growth_days_to_juvenile_with_feed_acceleration > 0),
  add column if not exists growth_days_to_adult_with_feed_acceleration integer
    not null default 15 check (growth_days_to_adult_with_feed_acceleration > 0);

create table if not exists public.growth_logs (
  id uuid primary key default gen_random_uuid(),
  fish_id uuid not null references public.fish(id) on delete cascade,
  from_stage public.fish_growth_stage not null,
  to_stage public.fish_growth_stage not null,
  triggered_at timestamptz not null default now(),
  reason text not null check (reason in ('time', 'feeding_acceleration')),
  check (from_stage <> to_stage)
);

create index if not exists growth_logs_fish_triggered_at_idx
  on public.growth_logs (fish_id, triggered_at desc);

alter table public.growth_logs enable row level security;

drop policy if exists "users read growth logs for own fish" on public.growth_logs;
create policy "users read growth logs for own fish"
  on public.growth_logs for select
  using (
    exists (
      select 1
      from public.fish fish
      join public.tanks tank on tank.id = fish.tank_id
      where fish.id = growth_logs.fish_id
        and tank.owner_id = auth.uid()
    )
  );

-- Called when the player opens the tank. Time is the primary signal. A meal
-- contributes half an effective day, but only when at least one meal exists;
-- accelerated targets are still configured per species and never skip logs.
create or replace function public.sync_tank_growth(target_tank_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  fish_record record;
  current_stage public.fish_growth_stage;
  age_days integer;
  effective_days integer;
  juvenile_reason text;
  adult_reason text;
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

  for fish_record in
    select
      fish.id,
      fish.growth_stage,
      fish.created_at,
      species.growth_days_to_juvenile,
      species.growth_days_to_adult,
      species.growth_days_to_juvenile_with_feed_acceleration,
      species.growth_days_to_adult_with_feed_acceleration,
      count(feeding_log.id)::integer as feeding_count
    from public.fish fish
    join public.fish_species species on species.id = fish.species_id
    left join public.feeding_logs feeding_log on feeding_log.fish_id = fish.id
    where fish.tank_id = target_tank_id
    group by fish.id, species.id
  loop
    age_days := floor(extract(epoch from now() - fish_record.created_at) / 86400)::integer;
    effective_days := age_days + floor(fish_record.feeding_count / 2.0)::integer;
    current_stage := fish_record.growth_stage;
    juvenile_reason := case
      when age_days >= fish_record.growth_days_to_juvenile then 'time'
      else 'feeding_acceleration'
    end;
    adult_reason := case
      when age_days >= fish_record.growth_days_to_adult then 'time'
      else 'feeding_acceleration'
    end;

    if current_stage = 'fry' and (
      age_days >= fish_record.growth_days_to_juvenile
      or (
        fish_record.feeding_count > 0
        and effective_days >= fish_record.growth_days_to_juvenile_with_feed_acceleration
      )
    ) then
      update public.fish set growth_stage = 'juvenile' where id = fish_record.id;
      insert into public.growth_logs (fish_id, from_stage, to_stage, reason)
      values (fish_record.id, 'fry', 'juvenile', juvenile_reason);
      current_stage := 'juvenile';
    end if;

    if current_stage = 'juvenile' and (
      age_days >= fish_record.growth_days_to_adult
      or (
        fish_record.feeding_count > 0
        and effective_days >= fish_record.growth_days_to_adult_with_feed_acceleration
      )
    ) then
      update public.fish set growth_stage = 'adult' where id = fish_record.id;
      insert into public.growth_logs (fish_id, from_stage, to_stage, reason)
      values (fish_record.id, 'juvenile', 'adult', adult_reason);
    end if;
  end loop;
end;
$$;

revoke all on function public.sync_tank_growth(uuid) from public;
grant execute on function public.sync_tank_growth(uuid) to authenticated;

commit;
