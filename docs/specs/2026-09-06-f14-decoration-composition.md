# F14 — 布景组合编辑

> Status: implementation and verification
> Extends: F7 tank decorations

## Outcome

Players can place a decoration flush with the fish-tank floor and tune its
visual scale without risking accidental deletion. A tap selects an object;
dragging repositions it; the compact selected-object control offers decrease,
increase, and an explicit remove action. Decorations stay visual-only.

## Data contract

`public.tank_decorations.scale_factor` is a persisted number between `0.65`
and `1.55`, defaulting to `1.00`. It is independent of fish state and travels
through Realtime like the existing normalized x/y coordinates.

## Visual treatment

Existing watercolor decoration assets receive a restrained underwater tint and
slight opacity so plants, stones, and driftwood share the tank background's
deep teal atmosphere while retaining their individual silhouette.

## Verification

- Widget regression tests prove that a drag can reach the floor, selection
  exposes bounded size controls, and removal requires the explicit action.
- SQL verification proves the persisted scale can be updated and rejects an
  out-of-range value.
- Full Flutter tests, static analysis, and a Web preview are required before
  handoff.
