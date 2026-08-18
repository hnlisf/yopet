import 'package:flutter/material.dart';

/// Design tokens for yopet's dark + cyan-glow brand.
///
/// Hex values mirror `docs/design/ui-design.md` §3 (the palette token
/// table) byte-for-byte. Update this file in lockstep with that
/// section if the palette ever changes.
class Tokens {
  Tokens._();

  // -- Surfaces -----------------------------------------------------------

  /// Page background — near-black, slightly blue. The "darkened room"
  /// the yopet tank is meant to live in. Never pure `#000` (too
  /// clinical).
  static const Color primaryBg = Color(0xFF0E1620);

  /// Card / sheet / drawer surface — one elevation above [primaryBg].
  static const Color surface = Color(0xFF1A2733);

  // -- Accent: tank glow -------------------------------------------------

  /// Water light / fish sprite tint / primary accent. Soft cyan-teal,
  /// desaturated. The signature element — used for the splash wordmark
  /// halo, button fills, focused input borders, satiety-bar high range.
  static const Color tankGlow = Color(0xFF5BA8B5);

  /// Hover / focus state for tank-glow elements. Lighter than
  /// [tankGlow] so focus rings stay legible on the dark surface.
  static const Color tankGlowSoft = Color(0xFF7FBFC9);

  // -- Semantic -----------------------------------------------------------

  /// Decoration plants, success / alive states. Muted sage.
  static const Color plant = Color(0xFF7E9B7E);

  /// Water-temperature warmth, food, "needs attention" (never alarm).
  /// Saturated red is forbidden — amber is the warm colour here.
  static const Color amber = Color(0xFFD4A574);

  // -- Text --------------------------------------------------------------

  /// Primary text — soft white, never pure `#FFF`.
  static const Color text = Color(0xFFE8EEF2);

  /// Secondary text, captions, metadata.
  static const Color textDim = Color(0xFF8A9BA8);

  // -- Splash-specific (UI 原型 phase) ----------------------------------

  /// The 4–6 px halo around the splash wordmark, applied via
  /// `BoxShadow` (alpha dialed down for a soft glow). Pulled from
  /// [tankGlow] at runtime; kept as a named token for future
  /// animation hooks (e.g. pulse on interaction).
  static const Color splashGlow = tankGlow;

  /// The thin water-surface line that runs along the top of every
  /// yopet screen. Subtle, with a slight cyan tint.
  static const Color waterSurfaceLine = tankGlowSoft;
}
