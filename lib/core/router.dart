import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/fish/fish_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/ui_direction_prototype.dart';
import '../splash_screen.dart';

/// App-level router.
///
/// Routes:
///   * `/`           — splash (transient; redirect below fires on first
///                     build to bounce the user to the right place)
///   * `/sign-in`    — AuthScreen (sign-in / sign-up toggle)
///   * `/home`       — HomeScreen (email + Sign out + empty-tank CTA)
///   * `/pick-fish`  — F6 species, variant and naming flow.
///   * `/prototype/ui-direction` — development-only UI research route.
///
/// Redirect rules:
///   * Unauthenticated → must land on /sign-in
///   * Authenticated   → may use /home and /pick-fish; auth entry routes
///                       redirect to /home.
/// Re-evaluated on every build (`ref.read` is cheap, computed on
/// demand), so sign-in / sign-out in any feature flips the root
/// destination immediately.
final routerProvider = Provider<GoRouter>((ref) {
  const prototypePath = '/prototype/ui-direction';
  final launchRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final launchUri = Uri.tryParse(launchRoute);
  final initialLocation = kDebugMode && launchUri?.path == prototypePath
      ? launchRoute
      : '/';

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      // A throwaway design prototype is intentionally reachable before auth
      // while running locally.  Its own switcher is hidden in release builds;
      // production users continue to follow the normal auth redirect below.
      if (kDebugMode && state.matchedLocation == prototypePath) return null;

      final user = ref.read(currentUserProvider);
      if (user == null) {
        return state.matchedLocation == '/sign-in' ? null : '/sign-in';
      }
      if (state.matchedLocation == '/' || state.matchedLocation == '/sign-in') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/pick-fish', builder: (_, _) => const FishPickerScreen()),
      GoRoute(
        path: prototypePath,
        builder: (_, state) => UiDirectionPrototypeScreen(
          initialVariant: state.uri.queryParameters['variant'] ?? 'A',
        ),
      ),
    ],
  );
});
