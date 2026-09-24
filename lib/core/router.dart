import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'supabase.dart';
import '../features/auth/auth_screen.dart';
import '../features/fish/custom_fish_flow_prototype.dart';
import '../features/fish/custom_fish_pattern_prototype.dart';
import '../features/fish/custom_fish_screen.dart';
import '../features/fish/fish_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/ui_direction_prototype.dart';
import '../features/weather/weather_preview_screen.dart';
import '../splash_screen.dart';

/// App-level router.
///
/// Routes:
///   * `/`           — splash (transient; redirect below fires on first
///                     build to bounce the user to the right place)
///   * `/sign-in`    — AuthScreen (sign-in / sign-up toggle)
///   * `/home`       — HomeScreen (email + Sign out + empty-tank CTA)
///   * `/pick-fish`  — F6 species, variant and naming flow.
///   * `/custom-fish` — player-designed body, tail, pattern and watercolor.
///   * `/prototype/ui-direction` — development-only UI research route.
///   * `/prototype/custom-fish-flow` — development-only custom-fish UX study.
///   * `/prototype/fish-patterns` — development-only fish skin art study.
///   * `/preview/weather` — development-only, data-free F11 review route.
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
  const customFishPrototypePath = '/prototype/custom-fish-flow';
  const fishPatternsPrototypePath = '/prototype/fish-patterns';
  const weatherPreviewPath = '/preview/weather';
  final launchRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final launchUri = Uri.tryParse(launchRoute);
  final initialLocation =
      kDebugMode &&
          (launchUri?.path == prototypePath ||
              launchUri?.path == customFishPrototypePath ||
              launchUri?.path == fishPatternsPrototypePath ||
              launchUri?.path == weatherPreviewPath)
      ? launchRoute
      : '/';

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      // A throwaway design prototype is intentionally reachable before auth
      // while running locally.  Its own switcher is hidden in release builds;
      // production users continue to follow the normal auth redirect below.
      if (kDebugMode &&
          (state.matchedLocation == prototypePath ||
              state.matchedLocation == customFishPrototypePath ||
              state.matchedLocation == fishPatternsPrototypePath ||
              state.matchedLocation == weatherPreviewPath)) {
        return null;
      }

      // `ref.read(currentUserProvider)` can still be its previous cached null
      // value in the tiny interval after signInWithPassword succeeds. The
      // Supabase SDK owns the just-issued session synchronously, so the
      // redirect must consult it directly for this navigation decision.
      return redirectForCurrentAuthState(
        matchedLocation: state.matchedLocation,
        isAuthenticated: getSupabase().auth.currentUser != null,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/pick-fish', builder: (_, _) => const FishPickerScreen()),
      GoRoute(
        path: '/custom-fish',
        builder: (_, _) => const CustomFishScreen(),
      ),
      GoRoute(
        path: prototypePath,
        builder: (_, state) => UiDirectionPrototypeScreen(
          initialVariant: state.uri.queryParameters['variant'] ?? 'A',
        ),
      ),
      GoRoute(
        path: customFishPrototypePath,
        builder: (_, state) => CustomFishFlowPrototypeScreen(
          initialVariant: state.uri.queryParameters['variant'] ?? 'A',
        ),
      ),
      GoRoute(
        path: fishPatternsPrototypePath,
        builder: (_, state) => CustomFishPatternPrototypeScreen(
          initialVariant: state.uri.queryParameters['variant'] ?? 'A',
        ),
      ),
      GoRoute(
        path: weatherPreviewPath,
        builder: (_, _) => const WeatherPreviewScreen(),
      ),
    ],
  );
});

/// The standard authentication gate, separated from [GoRouter] so the
/// immediate-session handoff can be regression-tested without a live SDK.
String? redirectForCurrentAuthState({
  required String matchedLocation,
  required bool isAuthenticated,
}) {
  if (!isAuthenticated) {
    return matchedLocation == '/sign-in' ? null : '/sign-in';
  }
  if (matchedLocation == '/' || matchedLocation == '/sign-in') return '/home';
  return null;
}
