import 'package:flutter/material.dart';

import 'core/theme/tokens.dart';

/// The first (and only) screen in yopet's F2 scaffold.
///
/// A dark canvas with the "yopet" wordmark in cyan, sourced from
/// [Tokens]. No business logic, no Supabase calls. UI 原型 phase
/// (PRD §6.1) will replace this with the full tank canvas.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: Center(
        child: Text(
          'yopet',
          style: TextStyle(
            color: Tokens.tankGlow,
            fontSize: 48,
            fontWeight: FontWeight.w600,
            // F2 ships with system default font; Fraunces is loaded by
            // the UI 原型 phase.
          ),
        ),
      ),
    );
  }
}
