# Formal B workspace integration · Design QA (2026-09-20)

## Source, implementation, and normalization

- Source visual truth: the user-approved B「水下工作台」at `http://127.0.0.1:4196/#/prototype/custom-fish-flow?variant=B`, whose earlier normalized implementation capture is `artifacts/product-design/option2-implementation.png`.
- Rendered shared-workspace evidence: the B route was reopened after the production integration at a 1280 × 720 browser viewport, with the 430 px-wide mobile canvas centered in the page. The observed state was tiger pattern, density 58 and softness 64. The header, central fish canvas, five tools, pattern rail, sliders, and completion action were all visible without overflow.
- Production implementation: `CustomFishScreen` now composes the same `CustomFishStudio` component, adds the real fish-count badge, back navigation, name validation, and repository save callback, and intentionally hides the non-persisted “换个个体” action. `test/custom_fish_screen_test.dart` drives the production widget through body, tail, pattern, color, name, and save at the default 800 × 600 test surface.
- Authenticated save verification: after the earlier unsigned-browser capture, a signed-in user saved a `wave` custom fish through `/custom-fish` and confirmed it appeared in the tank. This closes the real persistence-path check without inspecting or altering auth storage.

## Findings and comparison history

- **P1, production-flow mismatch — resolved.** The earlier production screen was a tall sequence of choice chips, not the approved B workspace. It now reuses the exact B workspace component, so preview, tool sheet, visual tokens, selected states, and pattern sliders no longer diverge between study and product paths.
- **P1, persistence honesty — resolved.** B’s prototype-only individual-randomization control was not part of the four-field saved appearance. The formal editor hides that control rather than showing a preview state that could change after saving.
- **P2, constrained-height overflow — resolved.** The first formal-widget test surfaced an 81 px vertical overflow at 800 × 600. The fish canvas now switches to a compact 185 px artwork with tighter spacing below 350 px available height. The post-fix widget run has no overflow exceptions while the B browser capture retains the full-height composition.
- **Verification boundary.** There are no remaining actionable visual differences in the shared B component. The signed-in `wave` save path has been confirmed in the product; the automated coverage remains the regression guard for all other combinations.

## Required fidelity surfaces

- **Fonts and typography:** the B title, helper copy, tool labels, slider labels/values, fish summary, and lavender CTA retain the established hierarchy. The formal route changes only contextual copy: real count and “完成并放入鱼缸”.
- **Spacing and layout rhythm:** the centered 430 px mobile surface, open-water fish canvas, rounded tool tray, horizontal pattern rail, and bottom CTA are shared. The new compact-height branch prevents clipping rather than changing the normal mobile rhythm.
- **Colors and visual tokens:** aquarium navy, cyan selections, and lavender primary CTA are shared. A-watercolor markings, including body-derived wave pigment, stay in the common sprite renderer.
- **Image quality and asset fidelity:** the formal page uses the same joined fish assets, torso masks, translucent fins, and body-relative paint as the approved prototype. No substitute or placeholder artwork was added.
- **Copy and content:** the production route uses the B copy, replaces the preview-only completion language with an actual save action, and omits non-persisted individual variation.

## Automated verification

- Static analysis: `dart analyze` on the workspace, formal editor, and relevant tests — passed.
- Widget paths: formal B save flow plus pattern-layout regression suite — 11 tests passed. The save test confirms box body + fan tail + zebra + deep-sea blue + custom name are persisted.
- Browser interaction: B prototype slider, pattern rail, wave color changes, compact-height visual state, and the signed-in formal `wave` save path were inspected on the local server.

## Implementation checklist

- [x] Reuse the approved B workspace in the formal `/custom-fish` editor.
- [x] Attach real save, validation, tank-capacity, and back-navigation behavior.
- [x] Preserve only states that can be saved and restored.
- [x] Verify the complete real save callback with a widget test.
- [x] With a signed-in local account, save a `wave` custom fish and confirm it returns to the tank with the same exterior.

final result: passed

---

# Custom fish skin redesign · Design QA (2026-09-17)

## Source, implementation, and normalization

- Source visual truth: the user's defect screenshots `C:\Users\tangx\AppData\Local\Temp\codex-clipboard-7bff4f46-3bd8-48f7-8190-6ba49d969b80.png` (disc/fan/tiger) and `C:\Users\tangx\AppData\Local\Temp\codex-clipboard-5ebb9aa4-d28b-4248-bdb0-63fb2e225b1f.png` (disc/fan/two-tone belly), plus the other nine supplied examples. These are *before* evidence, not a target to copy; the design target is the selected B workspace with body-grown, fin-free pigmentation.
- Rendered implementation: `D:\myworkspace\claude-workspace\yopet\artifacts\product-design\custom-fish-qa-20260917\disc-tiger.png` and `D:\myworkspace\claude-workspace\yopet\artifacts\product-design\custom-fish-qa-20260917\disc-belly.png` at `http://127.0.0.1:4193/#/prototype/custom-fish-flow?variant=B`.
- Full-view side-by-side inputs: `artifacts/product-design/custom-fish-qa-20260917/disc-tiger-comparison.png` and `disc-belly-comparison.png`. Focused fish-region inputs: `disc-tiger-focus.png` and `disc-belly-focus.png` in the same directory.
- Source captures: 830 × 1596 and 864 × 1600 physical px. Browser chrome was cropped (top 160/180 px), then the app area was normalized to 435 × 731 px. Implementation: 443 × 731 px at 443 × 731 CSS viewport, device density 1 in the in-app browser. The source was approximately 2× density and normalized to comparable CSS size; an 8 px width difference remains and is not judged as design drift.
- Matched state: B, round-disc body, fan tail, warm-orange color, pattern density 83, softness 60; tiger and two-tone belly are compared separately. Pattern rail scroll position and selected card were aligned.

## Findings and iteration history

1. **P1, pigment geometry — resolved.** Source tiger bars fused into one rectangular brown slab; the first revision still fused on a disc. The final implementation bounds band width by spacing, reduces lateral sway, and uses warmer lower-opacity pigment. The focused tiger comparison shows discrete torso stripes, with no paint on the dorsal or caudal fin.
2. **P1, lower-body treatment — resolved.** Source two-tone belly was a hard white triangle that crossed the expected belly zone. A first linear-gradient revision exposed the angular interior torso mask; a second revision made a pale central halo. The final warm, elliptical falloff sits lower on the torso and fades before the mask edge. The focused belly comparison shows no polygon boundary or fin overlap.
3. **P1, selected color fidelity — resolved.** The original orange master was multiplied by blue/green swatches, producing muddy brown fish. Hue-and-saturation recoloring plus source-alpha restoration now gives blue, sage-green, and indigo bodies without an opaque background block; the established orange rendering is retained. A rendered-pixel regression test checks blue skin and transparent corners.
4. **P2, other pattern families — resolved in shared renderer.** Cloud marks changed from white dots to feathered same-hue patches; saddles became separated shallow dorsal patches; lateral lines span the torso rather than appearing as short central brush strokes; neon is a slim teal band rather than a white wedge; ocelli use a warm dark center and one default posterior spot instead of multiple purple rings. All forms use the dedicated torso alpha mask.

## Required fidelity surfaces

- **Fonts and typography:** B's existing title, fish summary, tab labels, slider values, and CTA remain unchanged and legible in both full-view comparisons.
- **Spacing and layout:** Stage and tool sheet remain aligned; the 443 × 731 view keeps all controls visible. Differences in outer crop come from normalization, not implementation drift.
- **Colors and tokens:** The dark aquarium, cyan selection, and lavender CTA remain intact. Pigment hues now derive from the chosen body color except for the intentionally contrasting teal neon family.
- **Image quality and transparency:** The one-piece fish asset keeps its illustrated silhouette and texture. Pattern pigment is body-relative and clipped by the torso-only mask; selected blue/green/indigo fish were checked on the dark water without rectangular backgrounds.
- **Copy/content:** B's labels and completion language are unchanged; no explanatory prompt text was added to the interface.
- **Interaction/accessibility:** Body and pattern cards, color selection, and the density/softness sliders responded in the browser. Existing semantic/card behavior was not altered by this renderer-only change.

## Verification and remaining scope

- Browser states inspected: torpedo and disc silhouettes; tiger, cloud, saddle, neon, eye-spot, and belly families; warm orange, blue, sage green, and indigo colors. The provided screenshots cover further body/tail examples. The remaining combinations were not individually judged by eye.
- Automated layout contract evaluates **8 bodies × 3 tails × 8 patterns × 12 colors = 2,304 combinations**, including protected face/tail bounds and the torso mask policy. Custom-fish sprite, layout, and save-flow suites: **15 tests passed**. Flutter analysis: **no issues**.
- Follow-up polish (P3): the strength of a few softly blended patterns, especially saddle and belly, may be tuned after user playtesting; this is a preference trade-off between clear labels and naturally subtle pigmentation, not a clipping or layout defect.

final result: passed

---

# Historical Option 2 QA (before the 2026-09-17 skin redesign)

## Comparison target

- Source visual truth: `C:\Users\tangx\.codex\generated_images\01a0533d-797a-7f91-9b9e-a7be61f4a603\exec-33aa77c3-cedb-4839-a63f-c0150811b65f.png` (the user-selected Option 2).
- Browser implementation capture: `D:\myworkspace\claude-workspace\yopet\artifacts\product-design\option2-implementation.png`.
- Side-by-side comparison: `D:\myworkspace\claude-workspace\yopet\artifacts\product-design\option2-comparison.png`.
- Runnable state: `http://127.0.0.1:4191/index.html?option2-deep-v4#/prototype/custom-fish-flow?variant=B`.

## Normalization and state

- Source: 853 × 1844 px mobile concept.
- Implementation: the 430 px-wide centered application surface cropped from the 1166 × 731 in-app browser viewport.
- The comparison preserves both aspect ratios and aligns their full working surfaces side by side. It evaluates hierarchy, component structure, visual language, and the complete visible interaction state rather than using a misleading stretched pixel overlay.

## Full-view comparison

The implementation matches the selected direction's dark underwater workspace, top-left title and back action, top-right progress badge, centered fish, natural-fit indicator, five-category tool strip, horizontal pattern rail, two biological variation controls, and lavender completion action. The fish remains the strongest visual focus and the control sheet remains visually secondary.

### Required fidelity surfaces

- **Typography and hierarchy:** title, helper copy, fish summary, selected category, control labels, and CTA retain the source hierarchy and remain readable at the captured size.
- **Spacing and layout rhythm:** the centered 430 px surface fits the complete interaction without page scrolling at 731 px height. Category, pattern rail, controls, and CTA use consistent vertical rhythm.
- **Color and visual tokens:** the existing dark aquarium, restrained cyan selection states, and lavender completion action closely match the selected concept and the established yopet system.
- **Pattern presentation:** the selected tiger pattern now uses broad, warm-brown, softly feathered vertical bars rather than a fixed grey decal. Its count, width, edge softness, and position are generated from body dimensions and a stable individual seed.
- **Body-only pigment:** every body and tail row uses a separately aligned torso alpha mask. Dorsal, pectoral, anal, and tail fins are excluded even when the marking geometry spans the complete torso.
- **Interaction fidelity:** the pattern rail supports touch, stylus, and mouse dragging; density and softness update the central fish immediately; “换个个体” changes the stable distribution without changing the chosen pattern family.
- **Accessibility:** pattern cards and sliders expose labels, selection state, and values; foreground contrast remains consistent with the existing dark-mode tokens.

## Browser verification

- Switched from torpedo to round and box bodies while retaining the same pattern family; body-relative scale and distribution changed.
- Selected cloud, tiger, neon, saddle, eye, and two-tone belly patterns from the draggable rail.
- Reduced density and confirmed motif count changed instead of scaling down a fixed decal.
- Triggered “换个个体” and confirmed a new stable placement with the same body, tail, color, and pattern family.
- Verified two-tone belly on torpedo and box bodies; the light belly stayed behind the pectoral and anal fins.
- Verified saddle marking stayed inside the torso mask and did not paint the dorsal fin.

## Automated verification

- Dart analysis: no issues.
- Custom-fish layout, sprite, and save-flow tests: 13 passed.
- Regression coverage includes all 8 bodies × 3 tails resolving to a torso mask, adaptive marking anchors, tuning changes, transparent complete-fish assets, and custom-fish persistence.

## Intentional differences

- Pattern cards show the current complete fish rather than isolated abstract swatches. This makes the core promise—“the same pattern grows differently on each body”—visible before selection.
- Slider values are shown numerically instead of using decorative endpoint symbols, improving clarity for manual testing.

## Findings

No actionable P0, P1, or P2 visual, interaction, overflow, or accessibility differences remain in the selected Option 2 state.

historical result: passed for the earlier Option 2 prototype
