import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

/// Root widget for yopet. Composes:
///   * [MaterialApp.router] for go_router
///
/// [YopetApp] is a [ConsumerWidget] that reads the [GoRouter] from
/// `routerProvider` via `ref.watch(routerProvider)`. This requires a
/// [ProviderScope] somewhere above it in the widget tree — that
/// lives in `main.dart` (production) or in the test pumpWidget call
/// (tests). [YopetApp] itself does not create a [ProviderScope].
///
/// `main.dart` is responsible for any one-time setup that must happen
/// *before* this widget builds (currently: `Supabase.initialize`).
/// [YopetApp] itself is hermetic and does not call Supabase — tests
/// can pump it without any network access.
class YopetApp extends ConsumerWidget {
  const YopetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'yopet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
