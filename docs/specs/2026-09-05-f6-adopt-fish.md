# F6 — 领养一条鱼

> Status: implementation and verification
> Parent issue: [yopet#6](https://github.com/hnlisf/yopet/issues/6)
> Depends on: F4 tank ownership + F5 catalogue

## Outcome

Signed-in users choose one of the 12 approved fish silhouettes, choose one of
three watercolor treatments, enter a 1–20 character name, and adopt the fish
into their own tank. The database assigns defaults and enforces ownership and
the five-fish capacity. The Flutter tank subscribes to realtime fish rows and
moves each fish through the tank according to its personality traits.

## Data contract

`public.fish` owns per-player fish instances:

- UUID identity and owner tank foreign key
- catalogue species and variant foreign keys, with a trigger that verifies the
  variant belongs to the selected species
- trimmed 1–20 character name
- one to three unique personality-trait UUIDs
- `fry | juvenile | adult` growth stage, default `fry`
- satiety from 0–100, default 80
- creation and last-seen timestamps

The capacity trigger obtains a transaction-scoped advisory lock per tank before
counting. This prevents two devices from concurrently creating fish number 5
and number 6.

## Catalogue and assets

The catalogue contains exactly the 12 silhouettes approved in the UI prototype:
goldfish, guppy, betta, angelfish, koi, discus, neon tetra, zebrafish,
swordtail, molly, tiger barb, and corydoras. Each has three named colour
variants. Flutter ships one reviewed watercolor PNG per silhouette and applies
the variant colour at render time, keeping the asset bundle smaller while the
database still stores an explicit variant.

## Flutter flow

1. `/pick-fish` loads tank, catalogue, traits, and current fish count.
2. The user chooses species and variant, then enters a name.
3. The repository randomly samples 1–3 unique traits and inserts the fish.
4. Realtime adds the new row to `/home`; species + variant + growth stage choose
   the rendered sprite.
5. Trait codes alter swim speed and preferred water layer. Reduced-motion mode
   freezes optional movement.
6. At five fish the CTA is disabled and explains why. The database remains the
   final authority for concurrent requests.

## Verification

- SQL: catalogue counts, defaults, capacity, unique traits, species/variant
  consistency, RLS enabled, and owner-only policy set.
- Dart unit tests: trait sample size/uniqueness and database-model mapping.
- Flutter widget tests: 12-species picker, name validation, successful adoption,
  and full-tank feedback.
- `dart analyze`, `flutter test`, and a web build before handoff.

## Deferred from F6

The approved combination-based custom fish needs its own persisted component
schema (body, tail, pattern, and colour), rather than pretending to be a preset
species/variant row. Tank decoration configuration is also a later feature.
