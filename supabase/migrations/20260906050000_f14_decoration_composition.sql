-- F14: compositions keep a player-selected visual scale for every placed
-- object. Scale remains visual-only and never changes fish state.

begin;

alter table public.tank_decorations
  add column if not exists scale_factor numeric(4, 2) not null default 1.00
  check (scale_factor between 0.65 and 1.55);

commit;
