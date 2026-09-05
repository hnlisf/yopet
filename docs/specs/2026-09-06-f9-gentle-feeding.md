# F9 — 温和喂食与饱食度

> Implements: GitHub issue [#9](https://github.com/hnlisf/yopet/issues/9), ADR-0001

## Purpose

Feeding is a small, pleasant check-in rather than an obligation. It raises a
fish's satiety, while elapsed time only changes the fish's activity and tank
atmosphere. A fish can never become ill, die, disappear, or produce a failure
state because it was not fed.

## Data and security

`feeding_logs` records the fish, time and standard amount (25) of each meal.
`fish.satiety_updated_at` records the calculation baseline, preserving partial
30-minute intervals between app launches.

The app calls `sync_tank_satiety` once as the tank opens. It subtracts one
satiety point for each completed 30-minute interval, never below zero, without
a cron task or database trigger. `feed_fish` is a SECURITY DEFINER RPC which
checks the caller owns the fish, caps the new satiety at 100, and atomically
inserts the log. Direct table policies expose feeding logs only to that fish's
owner.

## Experience

1. A hit-tested tap still starts the F8 personality reaction and now opens the
   fish action sheet.
2. The sheet shows the current satiety bar and a single `喂食 +25` action. At
   100, it calmly says the fish is satisfied instead of asking for another
   action.
3. Below 30, the sheet says `小鱼有点饿了。` in amber. In the tank the fish
   slows and drifts toward a quiet corner; this is visual mood only.
4. A successful feed uses the RPC response immediately, while the existing
   realtime stream keeps other devices in sync.

## Verification

- SQL checks validate five-hour decay from 35 to 25, capped feeding from 90 to
  100, the log amount, owner isolation and `feeding_logs` RLS.
- Dart tests cover capped feeding, five-hour low-satiety mood and 30-minute
  interval rounding.
- No code creates disease, death, removal, alerts or scheduled punishment.
