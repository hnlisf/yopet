# Yopet custom fish, layered joint, and decoration design QA

## Evidence

- Approved design-system source: `C:\\Users\\tangx\\.codex\\generated_images\\01a0533d-797a-7f91-9b9e-a7be61f4a603\\exec-ac4eb42b-9ce1-4372-b62b-a24cf08c6372.png` (`852 x 1846`), normalized as `artifacts/source-adoption-normalized-393x852.png`.
- Current-run pre-change audit captures: `artifacts/audit-current-custom-screen.png` and `artifacts/audit-current-decor-screen.png` (`393 x 852`).
- User-reported joint defect evidence: `artifacts/joint-before-default-screen.png` and `artifacts/joint-seam-before-screen.png` (`393 x 852`); the first implementation retained a closed rear socket, while the next hard-masked version left a visible straight seam.
- Final rendered implementation: `artifacts/joint-seam-default-final-screen.png`, `artifacts/joint-seam-pass2-screen.png`, `artifacts/implementation-decor-water-screen.png`, and `artifacts/implementation-decor-aurora-cold-screen.png` (`393 x 852`).
- Full-view comparison evidence: `artifacts/comparison-custom-seam-final.png`, `artifacts/joint-feather-matrix-final.png`, and `artifacts/comparison-decor-water-final.png`.
- Focused comparison evidence: `artifacts/comparison-custom-seam-focused-final.png`; the fish preview was checked closely for the closed socket seam, hard crop line, joint continuity, overlap, tail-to-body scale, ink clarity, and watercolor boundaries.
- Asset contact sheets: `artifacts/custom-layer-composite-check.png` and `artifacts/decor-expansion-contact-sheet.png`.
- Current expansion source/build comparison: `qa/custom-expansion-reference-vs-build.png`; the approved dark watercolor aquarium reference and the rendered expanded creator are normalized to the same `528 x 1140` content size and placed side by side.
- Current expansion browser capture: `qa/custom-expansion-build.jpg`; additional browser checks covered every body, pattern, and watercolor option before handoff.

## Viewport and states

- Browser viewport: `1400 x 1200`, device scale factor `1`.
- Verified iPhone screen: `393 x 852` CSS px at scale `1`.
- Verified Pixel 10 screen: `427 x 952` CSS px; the selected background and `完成布置` action remained visible.
- Custom default: round body + petal tail + cloud pattern + warm orange.
- Current contrast state: disc body + ribbon tail + eye-spot pattern + rose pink.
- Historical joint matrix: all nine combinations across the former round/light/tall set and petal/fan/ribbon tails.
- Current expansion states: all eight bodies with petal tail; all eight patterns on the round body; all twelve watercolors on the same pearl-pattern body; disc + ribbon + eye-spot used as the extreme joint/clipping check.
- Decoration states: water-plant inventory and teal-aurora full-tank background.

## Findings

- No actionable P0, P1, or P2 findings remain.
- User acceptance: the expanded custom-fish prototype was explicitly approved on 2026-09-05 and is now the production-reference baseline.
- The custom-fish preview now composes three independent raster layers. Selecting a body no longer changes the tail or pattern; selecting a tail or pattern replaces only that layer, and watercolor changes the shared color treatment.
- Body choices now total `8` and use visibly different natural-fish structures: round, streamlined, diamond, disc, torpedo, bottom-dwelling, box, and eel forms. The former near-duplicate tall option is no longer selectable.
- Pattern choices now total `8`. The rejected mist pattern is no longer selectable; cloud, pearl spots, vertical tiger bands, horizontal stripes, neon lateral line, saddle patches, eye-spots, and two-tone belly follow recognizable fish-marking logic.
- Every pattern layer is masked by the currently selected body asset at render time (`mask-size: contain`). Pattern pixels cannot render outside the chosen body, including on the smallest and tallest silhouettes.
- Watercolors now total `12` and span warm orange/yellow, red/coral/pink, green/mint/teal, cyan/blue, and violet/indigo groups. Browser comparison confirmed meaningful hue changes in the preview rather than label-only variants.
- Every body and tail now meets at a shared visual anchor. The body's closed rear socket is masked at that anchor, each tail root uses only a small intentional underlap, and all three tails are normalized below the body scale rather than being left at full source-canvas size.
- The body exit and tail entry now cross-feather through an overlapping watercolor band. No hard vertical crop or flat tail-root edge remains visible in the nine-combination matrix.
- The exact body/tail/pattern IDs remain identical after saving into the aquarium and after opening the fish detail view.
- Decoration tabs now expose separate inventories instead of a shared mixed grid: water plants `4`, rockwork `4`, driftwood `3`, backgrounds `3`.
- Object selections preview as movable aquarium objects; background selections preview a full-tank raster treatment.

## Required fidelity surfaces

- Fonts and typography: the established serif display hierarchy and sans supporting copy are unchanged. New inventory counts, category labels, and custom-trait labels remain readable without changing the calm density.
- Spacing and layout rhythm: custom controls retain the approved three-column rhythm. The filtered decoration drawer removes unrelated cards, shortens scan distance, and keeps the primary action clear.
- Colors and tokens: new assets stay within midnight navy, deep teal, pale cyan, muted coral, sage, sand, and translucent watercolor tokens. Full-background options keep header and swimming zones low-detail.
- Image quality and asset fidelity: custom fish use nineteen purpose-built transparent raster layers (eight bodies, three tails, eight patterns). Newly generated body and pattern assets were pixel-checked for real alpha transparency; two false checkerboard backgrounds were corrected before use. The renderer aligns body-specific roots, keeps the prior short alpha cross-feather at the tail joint, and clips patterns with the selected body alpha. The decoration expansion uses five transparent object assets and two full-screen raster backgrounds. All inspected assets loaded with non-zero natural sizes; no placeholder, emoji, CSS-drawn fish, or handcrafted SVG art was used.
- Copy and content: copy now states that the fish is assembled, identifies the active traits, reports per-category decoration counts, and distinguishes object placement from full-tank background preview.

## UX and accessibility checks

- Custom controls expose pressed states and maintain a visible text summary of the selected body, tail, and pattern.
- A custom fish saved with `custom-tail-ribbon.png`, `custom-body-light.png`, and `custom-pattern-star.png` preserved those same three sources in the aquarium and detail view.
- A final tall-body + ribbon-tail fish saved into the aquarium and opened in detail with the same `body-tall`, `tail-ribbon`, joint mask, and normalized tail transform.
- Naming with the simulated keyboard and tapping save once completes the action and dismisses the keyboard.
- Decoration category changes update both grid content and item count; background cards expose pressed state and update the visible tank preview.
- Generated art remains decorative inside labeled buttons; composed fish expose one consolidated accessible image label rather than three noisy layer labels.
- The expanded creator exposes `8` body buttons, `3` tail buttons, `8` pattern buttons, and `12` color buttons with pressed states. Legends state the option counts and selected body note without hiding the core save action.
- Browser console errors/warnings checked: `0`.
- Protected runtime integrity: `28` files passed.

## Comparison history

### Iteration 1 — blocked

- [P1] Custom-trait selectors mapped to complete preset-species images, so the core promise of modular creation was not represented.
- [P2] Decoration tabs changed only their active styling while the same six mixed items remained visible.
- Fixes: introduced a persisted `FishParts` contract and real aligned body/tail/pattern layers; restructured decoration data into four filtered inventories and added full-background preview behavior.
- Evidence: `artifacts/audit-current-custom-screen.png` and `artifacts/audit-current-decor-screen.png`.

### Iteration 2 — blocked

- [P2] The mist overlay sat above the body details and reduced eye/ink clarity. A hard rectangular safety crop fixed the eye but introduced an obvious vertical edge.
- Fix: restored the overlay above the body, then scaled and shifted the naturally transparent pattern asset into the body-safe zone so the eye remains clear without a crop seam.
- Intermediate evidence: `artifacts/comparison-custom-combinations-pass2.png` and `artifacts/comparison-custom-combinations-pass3.png`.

### Iteration 3 — passed

- Final evidence: `artifacts/implementation-custom-layered-default-final2-screen.png`, `artifacts/implementation-custom-layered-combo-final2-screen.png`, `artifacts/comparison-custom-combinations-final2.png`, and `artifacts/implementation-decor-aurora-cold-screen.png`.
- Eye, mouth, and outline remain clear; pattern transitions are naturally transparent; body and tail combinations remain visibly distinct; category filtering and background preview are stable.

### Iteration 4 — blocked

- [P1] The body asset still displayed its closed oval rear socket, so the custom result read as two separate parts even where the layers touched.
- [P1] Tail source canvases used different root positions and remained at full size; the renderer compensated with substantial hidden overlap, leaving petal and fan tails larger than some bodies.
- Evidence: `artifacts/joint-before-default-screen.png`, `artifacts/implementation-custom-layered-combo-final2-screen.png`, and `artifacts/custom-layer-composite-check.png`.
- Fix: added explicit body and tail IDs to the shared renderer, introduced body-specific joint anchors, masked the closed socket at the joint, aligned each measured tail root to that anchor with a small underlap, and normalized petal/fan/ribbon scales to `0.50`/`0.46`/`0.42`.

### Iteration 5 — passed

- Final evidence: `artifacts/joint-pass3-default-screen.png`, `artifacts/joint-pass3-combo-screen.png`, `artifacts/comparison-custom-joint-final.png`, `artifacts/comparison-custom-joint-focused-final.png`, and `artifacts/joint-matrix-final.png`.
- All nine body-tail combinations connect without the former socket seam, no tail exceeds its paired body, and the existing watercolor-geometric art direction is unchanged.

### Iteration 6 — blocked

- [P1] The closed socket was gone, but its replacement used a hard vertical `clip-path`. The resulting straight edge remained visible, especially on the light-body + ribbon-tail combination, and still made the fish read as two assembled stickers.
- Evidence: `artifacts/joint-seam-before-screen.png` and the middle panel of `artifacts/comparison-custom-seam-focused-final.png`.
- Fix: replaced the hard clip with complementary alpha masks, feathered the body exit over `5.2%` of the shared canvas, feathered each tail root over `5.5%`, and increased the hidden underlap so both layers remain visually opaque during the transition.

### Iteration 7 — passed

- Final evidence: `artifacts/joint-seam-default-final-screen.png`, `artifacts/joint-seam-pass2-screen.png`, `artifacts/comparison-custom-seam-final.png`, `artifacts/comparison-custom-seam-focused-final.png`, and `artifacts/joint-feather-matrix-final.png`.
- The straight seam is absent in the focused before/after comparison and across all nine body-tail combinations. The joint now reads as a soft watercolor transition without changing fish silhouettes, controls, spacing, or the approved dark aquarium treatment.

### Iteration 8 — passed

- User findings: the original round/light/tall bodies were too similar and too few; mist could exceed the body and did not read as a fish marking; the original three warm colors were too close.
- Fixes: expanded the creator to eight natural-structure body silhouettes, replaced the selectable pattern set with eight fish-derived markings, added a selected-body alpha mask to the pattern layer, and expanded watercolor selection to twelve hues across red, yellow, green, blue, and purple regions.
- Functional check: a round + petal + pearl + indigo fish named `青岚` saved once, increased aquarium capacity from `3 / 5` to `4 / 5`, appeared in the swimming group, and surfaced the success toast.
- Final evidence: `qa/custom-expansion-reference-vs-build.png`, `qa/custom-expansion-build.jpg`, browser DOM counts (`8 / 3 / 8 / 12`), active body-mask inspection, and zero console warnings/errors.
- Acceptance: user reviewed the delivered prototype and confirmed this iteration can pass on 2026-09-05.

## Production handoff notes

- Persist `bodyId`, `tailId`, `patternId`, and `colorId` as the canonical custom-species appearance contract.
- Use one shared layered renderer for creator, aquarium, list thumbnails, and detail screens so saved appearance cannot drift.
- Production may flatten/cached-render the layers for performance, but should retain the source part IDs for editing.

## Implementation checklist

- [x] Real body/tail/pattern layer composition.
- [x] Watercolor changes without switching preset species.
- [x] Saved composition persists across aquarium and detail views.
- [x] Shared joint anchors, closed-socket masking, normalized tail scales, and all nine body-tail combinations verified.
- [x] Hard joint crop replaced with body-tail cross-feathering; straight seam regression check passes.
- [x] Eight structurally distinct natural-fish body choices, with body-specific joint anchors.
- [x] Eight fish-derived patterns; rejected mist removed and every pattern clipped to the active body alpha.
- [x] Twelve visibly separated watercolor choices covering red, yellow, green, blue, and purple regions.
- [x] Four functional decoration categories with at least three options each.
- [x] Full-tank background preview.
- [x] iPhone and Pixel 10 checks, build, runtime integrity, asset loading, keyboard flow, and console checks passed.

final result: passed
