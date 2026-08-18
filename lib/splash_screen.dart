import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/tokens.dart';

/// The first (and only) screen in yopet's F2 scaffold, and the visual
/// anchor of the UI 原型 phase.
///
/// Composition (per `docs/design/ui-design.md` §6.2):
///   * dark canvas ([Tokens.primaryBg])
///   * thin cyan water-surface line at the top ([waterSurfaceLine])
///   * centred Fraunces 600 wordmark with a soft cyan halo
///     ([splashGlow] via [BoxShadow]) — the brand "nocturnal aquarium"
///     aesthetic starts here
///   * no fish, no buttons, no copy — the wordmark IS the product
///
/// F2 keeps this as the only screen; the rest of the layout work
/// (glowing fish sprites, water ripple animation, bubble particles,
/// bottom action bar) lives in F6+ per PRD §6.1's "UI 原型 phase"
/// scope.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _glowBlur = 12.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: Stack(
        children: [
          // Subtle water-surface line at the top.
          // A 2 px-wide gradient stripe using the soft-glow tint.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00000000), // transparent at edges
                    Tokens.waterSurfaceLine,
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // The wordmark, centred. BoxShadow synthesises the brand
          // "soft cyan halo" that the design spec calls the signature
          // element (ui-design.md §5). The text itself reads 'yopet'
          // — which is the assertion the smoke test in
          // `test/widget_test.dart` relies on.
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(),
              child: Text(
                'yopet',
                style: GoogleFonts.fraunces(
                  color: Tokens.splashGlow,
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  height: 1.1,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: Tokens.splashGlow.withValues(alpha: 0.45),
                      blurRadius: _glowBlur,
                    ),
                    Shadow(
                      color: Tokens.splashGlow.withValues(alpha: 0.25),
                      blurRadius: _glowBlur * 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
