# yopet — Product Requirements Document

> Status: v0.1 (initial draft after the first two /grill-with-docs rounds)
> Owner: hnlisf
> Last updated: 2026-08-03

## 1. Product overview

**yopet** is a desktop and mobile fish-tank raising game for urban white-collar players seeking low-pressure emotional companionship. The player adopts and cares for 1–5 named fish in a single tank; each fish grows from fry to adult, is fed on a slow-decay schedule, and reacts to the player's presence based on its personality. The product prioritises ambient companionship over management-sim mechanics: nothing in yopet ever causes a fish to become sick or die.

## 2. Target user

**Primary persona**: urban white-collar (25–45), working in tech / finance / consulting, screen-fatigued from meetings, wants a calming 5-minute break ritual, low patience for punishment-loop games. Plays during coffee, before sleep, or when stress peaks.

**Anti-persona**: hardcore aquarium hobbyist who wants real biological simulation; mobile gamer chasing dopamine loops; parent looking for kids' educational content.

## 3. Core value prop

**精神陪伴** — the player feels a fish is noticing them and responding, without the weight of caretaking responsibility. The fish's response is ambient and mood-based, never punitive.

## 4. Platforms

- **Desktop** — Flutter desktop build (macOS / Windows / Linux)
- **Mobile** — Flutter iOS + Android
- **Single Flutter codebase** — see ADR-0004
- **Backend** — Supabase, self-hosted via Docker — see ADR-0004

## 5. User journey (canonical happy path)

```
1. Sign up          → email + password; verify via Inbucket (dev) or real email (prod)
2. Empty tank       → DB auto-creates a tanks row on sign-up; home screen shows empty aquarium
3. Pick a fish      → choose species (curated 8–15 palette), variant (3–5 colour/pattern per species),
                      name it, confirm
4. Watch it grow    → fish appears in the tank; swims based on its 1–3 randomly assigned personality
                      traits (bold / shy / curious / lazy)
5. Feed it          → tap fish → feed button → satiety refills (no fail state — ADR-0001)
6. Decorate         → add stones, plants, driftwood, background (purely aesthetic; fish unaffected)
7. Come back        → if away > 10 minutes, fish greets you (current state only — ADR-0005)
8. Watch it grow up → fry → juvenile (~7 days) → adult (~21 days), accelerated by feeding
9. Real weather     → grant location or pick city → real weather affects tank atmosphere
10. Tune water temp → manual slider; fish activity nudges based on species preference match
```

## 6. Feature list (mapped to tickets)

| # | Feature | Tickets | State |
|---|---|---|---|
| F1 | Local dev environment (Docker Supabase) | [#1](https://github.com/hnlisf/yopet/issues/1) | ready |
| F2 | Flutter project + supabase_flutter | [#2](https://github.com/hnlisf/yopet/issues/2) | blocked by #2 |
| F3 | Email sign-in flow | [#3](https://github.com/hnlisf/yopet/issues/3) | blocked by #3 |
| F4 | Auto-create empty tank on sign-up | [#4](https://github.com/hnlisf/yopet/issues/4) | blocked by #3 |
| F5 | Fish domain data seed (species / variants / traits) | [#5](https://github.com/hnlisf/yopet/issues/5) | blocked by #3 |
| F6 | Adopt a fish (with random 1–3 personality traits) | [#6](https://github.com/hnlisf/yopet/issues/6) | blocked by #4, #5 |
| F7 | Decoration system (place / remove, no functional effect) | [#7](https://github.com/hnlisf/yopet/issues/7) | blocked by #4 |
| F8 | In-presence interaction + return greeting | [#8](https://github.com/hnlisf/yopet/issues/8) | blocked by #6 |
| F9 | Feeding (satiety slow decay, no fail) | [#9](https://github.com/hnlisf/yopet/issues/9) | blocked by #6 |
| F10 | Growth over time (fry → juvenile → adult) | [#10](https://github.com/hnlisf/yopet/issues/10) | blocked by #6 |
| F11 | Real weather affects tank atmosphere | [#11](https://github.com/hnlisf/yopet/issues/11) | blocked by #4 |
| F12 | Manual water-temperature control | [#12](https://github.com/hnlisf/yopet/issues/12) | blocked by #6 |

### 6.1 Inserted phase — UI 原型 (between F2 and F3)

There is a deliberate cross-cutting phase inserted between F2 (Flutter scaffold) and F3 (sign-in flow) that is **not** a numbered F-row, because it is design-validation rather than business functionality.

| | |
|---|---|
| **Scope** | Take [docs/design/ui-design.md](docs/design/ui-design.md) from v0.1 ASCII sketches to runnable Flutter screens — dark canvas, palette tokens, font pair (Fraunces + Manrope), fish-glow signature. Validate on real desktop + mobile that the dark + cyan glow reads correctly before any feature work touches UI. |
| **In scope** | Implement `theme/tokens.dart`, `theme/typography.dart`, `widgets/tank_canvas.dart` skeleton; bring up the home/tank, sign-in, fish-picker, fish-detail, decoration-drawer screens as low-fidelity shells; lock the copy register by writing it into code, not just docs. |
| **Out of scope** | Wiring to Supabase, business logic, growth/feed/weather/temperature logic (these are F3–F12). No new visual-direction decisions — every visual choice must trace back to `ui-design.md`. |
| **State** | scheduled (gated on F2 done) |
| **Origin** | Brainstorm 2026-08-06: leads to lower UI rework on F3–F12 because the dark+glow direction is validated in code, not just ASCII, before any feature touches it. Recorded here so the F2/F3 ordering is explicit, not implicit. |

## 7. Non-goals (deliberately out of scope)

Each maps to a recorded decision.

- **No fish sickness or death** under any system state → ADR-0001
- **No historical memory for fish** (no anniversaries, no "I missed you") → ADR-0005
- **No multi-tank or tank upgrades**; one tank, ≤ 5 fish, decoration-only → ADR-0003 + CONTEXT.md 装饰 term
- **No ORM-tier query flexibility questions** (decided Supabase/Postgres, not MySQL/Firestore) → ADR-0004

## 8. Design decisions

See `docs/adr/` for the full record.

| ADR | Decision |
|---|---|
| [0001](docs/adr/0001-no-punishment-principle.md) | No-punishment principle |
| [0002](docs/adr/0002-cloud-sync-with-account.md) | Multi-device sync via cloud account |
| [0003](docs/adr/0003-tank-capacity-one-to-five.md) | Tank capacity 1–5 |
| [0004](docs/adr/0004-backend-supabase-self-hosted.md) | Backend = Supabase, self-hosted |
| [0005](docs/adr/0005-fish-companion-current-state-only.md) | Fish companion = current state only |

## 9. Domain glossary

See [`CONTEXT.md`](CONTEXT.md) for the 13 domain terms (鱼缸, 鱼, 鱼种, 变体, 城市位置, 天气感知, 喂食, 饱腹度, 水温, 成长阶段, 装饰, 性格特征, 互动反应). All implementation and tickets must use this vocabulary — no synonyms.

## 10. Open questions (deferred to v2)

These came up during /grill-with-docs and are explicitly deferred:

- Monetization (free / one-time / subscription / IAP for new species)
- Localisation (Chinese-only MVP; English later)
- Accessibility (color-blind mode, font-size scaling, screen reader)
- Push notifications ("fish is hungry" reminder copy; off-by-default for low-pressure ethos)
- Ambient sound / background music
- Account providers (Apple ID, Google, etc. — email/password MVP only)
- Distribution channels (App Store / Google Play / sideload-only)

## 11. Success metrics (placeholder, MVP)

Qualitative for v0.1; quantitative after first 100 users:

- A new user completes sign-up → adopts a fish → sees it in their tank **within 5 minutes**
- A returning user notices the greeting animation after being away > 10 min
- The product feels calm — no fail states, no punishment, no urgency
- No critical crashes in a 30-minute idle session