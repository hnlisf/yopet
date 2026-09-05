# F7 — 鱼缸装饰

> Status: implementation and verification
> Parent issue: [yopet#7](https://github.com/hnlisf/yopet/issues/7)
> Depends on: F4 tank ownership and F6 live tank canvas

## Outcome

Players arrange visual-only decorations in their single fish tank. The approved
catalogue contains twelve free watercolor assets: three water plants, three
rockwork pieces, three driftwood pieces, and three full-tank backgrounds.
Backgrounds are mutually exclusive; object decorations can be placed, dragged,
and removed. None of these actions may change fish state.

## Data contract

`public.tank_decorations` stores an id, tank id, approved decoration code and
type, normalized x/y position, and placement time. The database validates each
type/code pairing, allows one copy of each object, and enforces one active
background per tank. Four RLS policies limit every operation to the tank owner;
the table participates in Supabase Realtime for cross-device synchronization.

## Flutter flow

1. The fish-tank navigation opens a mobile-friendly decoration drawer.
2. Its four category chips filter a three-item catalogue, avoiding a mixed grid.
3. Tapping an object places it at its approved default location; dragging an
   existing object persists a normalized position; tapping the object removes it.
4. Tapping a background replaces the active background. The drawer also offers
   a deliberate “restore default background” action.
5. Realtime redraws object and background changes without touching fish rows.

## Verification

- SQL test covers type/code validation, one-background rule, owner RLS, and a
  before/after comparison proving placement, movement, and removal do not alter
  fish satiety, growth stage, or traits.
- Dart tests cover the 12-item, four-category catalogue, realtime row mapping,
  and category-filtered drawer placement.
- `dart analyze`, `flutter test`, Web build, and local Supabase SQL test are
  required before handoff.
