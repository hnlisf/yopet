import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../splash_screen.dart';

/// App-level router.
///
/// Three routes:
///   * `/`          — splash (transient; redirect below fires on first
///                    build to bounce the user to the right place)
///   * `/sign-in`   — AuthScreen (sign-in / sign-up toggle)
///   * `/home`      — HomeScreen (email + Sign out)
///
/// Redirect rules:
///   * Unauthenticated → must land on /sign-in
///   * Authenticated   → must land on /home
/// Re-evaluated on every build (`ref.read` is cheap, computed on
/// demand), so sign-in / sign-out in any feature flips the root
/// destination immediately.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        return state.matchedLocation == '/sign-in' ? null : '/sign-in';
      }
      return '/home';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (_, _) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const HomeScreen(),
      ),
    ],
  );
});
