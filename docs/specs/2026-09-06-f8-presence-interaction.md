# F8 — 在场互动反应与回归问候

> Implements: GitHub issue [#8](https://github.com/hnlisf/yopet/issues/8), ADR-0005

## Purpose

The aquarium should notice a player who is here now, without pretending to
remember their past. Tapping a visible fish starts a short trait-based reaction.
Returning after ten minutes away starts a brief greeting for every fish.

## Behaviour

1. The tank maintains the current normalized position of every swimming fish.
   A tank tap only selects a fish when it lands inside that fish's visual hit
   radius; taps on open water do nothing.
2. Reactions last about 1.5 seconds and a newer tap replaces the previous one.
   `curious` approaches the touch point, `shy` moves away, `bold` approaches
   the viewer, and `lazy` deliberately does nothing. Fish carrying multiple
   traits resolve predictably as lazy, shy, bold, then curious.
3. Fish use a gentle tail-like sway during an active reaction. After the
   duration they resume their existing free-swimming path.
4. When the app pauses, it updates the existing `fish.last_seen_at` field for
   the fish currently in the player's tank. No interaction or history table is
   written.
5. When the app resumes at least ten minutes later, all visible fish sway and
   move toward the center for about two seconds. The threshold is the exported
   `presenceGreetingThreshold` constant, making it adjustable without a schema
   change.

## Boundaries

- No Supabase migration is needed: F6 created `last_seen_at` and owner-only
  `UPDATE` RLS already permits this state update.
- Decorations, satiety, growth stage, trait assignments and fish inventory are
  not changed by either a tap or a greeting.
- The feature intentionally adds no `fish_events` or memory mechanism, in
  accordance with ADR-0005.

## Verification

`test/presence_interaction_test.dart` covers all four trait branches,
multi-trait priority, destinations and the ten-minute threshold. The existing
Flutter test suite and web release build remain the integration checks.
