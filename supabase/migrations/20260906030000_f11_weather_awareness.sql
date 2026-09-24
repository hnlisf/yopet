-- F11: a player-selected city and its latest real-weather snapshot.
--
-- Weather stays in the atmosphere layer. These fields never represent fish
-- health, a warning, or a task; they only let every signed-in device render
-- the same light, water texture, and activity pacing for the tank.

begin;

alter table public.tanks
  add column if not exists weather_city_name text,
  add column if not exists weather_latitude double precision,
  add column if not exists weather_longitude double precision,
  add column if not exists weather_code integer,
  add column if not exists weather_temperature_c double precision,
  add column if not exists weather_is_day boolean,
  add column if not exists weather_observed_at timestamptz;

alter table public.tanks
  drop constraint if exists tanks_weather_city_name_length,
  drop constraint if exists tanks_weather_latitude_range,
  drop constraint if exists tanks_weather_longitude_range,
  drop constraint if exists tanks_weather_code_range,
  drop constraint if exists tanks_weather_temperature_range,
  drop constraint if exists tanks_weather_snapshot_complete;

alter table public.tanks
  add constraint tanks_weather_city_name_length check (
    weather_city_name is null
    or char_length(btrim(weather_city_name)) between 1 and 80
  ),
  add constraint tanks_weather_latitude_range check (
    weather_latitude is null
    or weather_latitude between -90 and 90
  ),
  add constraint tanks_weather_longitude_range check (
    weather_longitude is null
    or weather_longitude between -180 and 180
  ),
  add constraint tanks_weather_code_range check (
    weather_code is null
    or weather_code between 0 and 99
  ),
  add constraint tanks_weather_temperature_range check (
    weather_temperature_c is null
    or weather_temperature_c between -90 and 70
  ),
  add constraint tanks_weather_snapshot_complete check (
    (
      weather_city_name is null
      and weather_latitude is null
      and weather_longitude is null
      and weather_code is null
      and weather_temperature_c is null
      and weather_is_day is null
      and weather_observed_at is null
    )
    or
    (
      weather_city_name is not null
      and weather_latitude is not null
      and weather_longitude is not null
      and weather_code is not null
      and weather_temperature_c is not null
      and weather_is_day is not null
      and weather_observed_at is not null
    )
  );

commit;
