# 方案 2：沉浸式画布 — Design QA

Final result: blocked (native visual comparison pending)

## Source and implementation

- Selected reference: `C:/Users/tangx/.codex/generated_images/01a0533d-797a-7f91-9b9e-a7be61f4a603/exec-3607ad7f-6809-449b-95f7-a7f4a405fc5a.png`.
- Implementation: production `/custom-fish` and `/pick-fish`, Flutter responsive layout. Existing fish rendering, persistence and capacity rules retained.
- Mobile evidence: `.scratch/responsive-mobile-custom-final.png`, browser viewport 396 × 704, production editor, lance body / fan tail / tiger pattern, capacity 5/5. Reference mobile state and viewport differ; disabled capacity action is intentional, not a color defect.
- Automated layout coverage: 1440×900, 1280×800, 390×844, 768×1024, 1024×620, 1024×480 and 844×390.
- Desktop native debug preview running, but screenshot capture was blocked by minimized-window/user-input protection. No user data removed to bypass capacity.

## Required surfaces

| Surface | Check | Status |
| --- | --- | --- |
| Fonts | Existing Chinese typography retained; hierarchy and compact category labels checked on mobile | Desktop visual check pending |
| Layout | Desktop category rail / large preview / floating property panel / footer; mobile stacked preview / horizontal choices / fixed action | Widget tests passed; desktop comparison pending |
| Colors | Navy, cyan selections, lavender action; authentic watercolor background | Mobile inspected; desktop comparison pending |
| Images | Existing real fish renderer and new `assets/tank/studio_canvas.png`; no placeholder fish | Mobile inspected |
| Copy | Existing pattern names and saving/capacity messages retained; property descriptions added | Inspected |

## Findings and history

1. Short desktop viewport caused a 16 px rail overflow. Increased minimum scrollable workspace height to 660; affected layout tests now pass.
2. Original desktop picker oversized empty cards. Replaced with bounded compact cards and an independent preview/details workspace; resizing preserves the name and species.
3. Mobile property contents scroll independently while the primary action stays available; at 396×704 lower sliders require scrolling.
4. Final regression: 82 tests passed. `flutter analyze --no-pub`: no issues.

## Remaining acceptance gate

Capture the current native desktop editor and picker, construct one normalized reference/implementation comparison board, inspect full-page and focused fonts/layout/colors/images/copy, and resolve any remaining P0/P1/P2 findings before changing the final result to passed. No combined comparison board or desktop visual pass is claimed at this point.
