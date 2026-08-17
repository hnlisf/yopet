import 'package:flutter/material.dart';

/// Design tokens for yopet's dark + cyan-glow brand.
///
/// Hex values mirror `docs/design/ui-design.md` §3 (the palette token
/// table). Two consts are populated in F2; UI 原型 phase adds more
/// (full 8-token palette + font + spacing).
class Tokens {
  Tokens._();

  /// Page background — near-black, slightly blue. The "darkened room"
  /// the yopet tank is meant to live in.
  static const Color primaryBg = Color(0xFF0E1620);

  /// Water light / fish sprite tint / primary accent. Soft cyan-teal,
  /// desaturated.
  static const Color tankGlow = Color(0xFF5BA8B5);
}
