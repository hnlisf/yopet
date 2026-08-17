import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';

/// Entry point. Initializes the Supabase client then hands off to
/// [YopetApp].
///
/// F2 keeps this minimal: there is no auth flow, no persisted state,
/// no notifications — just a single network call to make the
/// `Supabase.instance.client` ready before the first widget builds.
///
/// If [Supabase.initialize] fails (e.g. host unreachable), the failure
/// is logged but **not rethrown** so the splash screen can still
/// render for visual debugging.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  } catch (e, st) {
    debugPrint('Supabase.initialize failed: $e\n$st');
  }
  runApp(const YopetApp());
}
