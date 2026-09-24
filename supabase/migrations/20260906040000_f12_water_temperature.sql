-- F12: a tank-level, manually controlled water-temperature setting.
--
-- Temperature is a gentle ambience input only. Existing owner RLS and tank
-- realtime publication cover this field automatically; no fish health state,
-- penalty, or event history is introduced.

begin;

alter table public.tanks
  add column if not exists water_temperature_c smallint not null default 24;

alter table public.tanks
  drop constraint if exists tanks_water_temperature_range;

alter table public.tanks
  add constraint tanks_water_temperature_range
  check (water_temperature_c between 18 and 30);

comment on column public.tanks.water_temperature_c is
  'Manual aquarium temperature in Celsius. Used only for gentle animation cues.';

commit;
