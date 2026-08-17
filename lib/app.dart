import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

/// Root widget for yopet. Composes:
///   * [ProviderScope] for Riverpod
///   * [MaterialApp.router] for go_router
///
/// `main.dart` is responsible for any one-time setup that must happen
/// *before* this widget builds (currently: `Supabase.initialize`).
/// [YopetApp] itself is hermetic and does not call Supabase — tests
/// can pump it without any network access.
class YopetApp extends ConsumerWidget {
  const YopetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'yopet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
