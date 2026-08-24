import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../splash_screen.dart';

/// App-level router.
///
/// F2: single route (`/` → [SplashScreen]).
/// F3: three routes — `/sign-in`, `/home`, plus `/` that redirects
/// to `/sign-in` when there's no session or to `/home` when there is.
/// The redirect re-evaluates on every build (cheap, computed from
/// `currentUserProvider`) so a sign-in / sign-out anywhere in the
/// app flips the root destination immediately.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final loggingIn = state.matchedLocation == '/sign-in';
      // Unauthenticated → must be on /sign-in. Anywhere else bounces.
      if (user == null) {
        return loggingIn ? null : '/sign-in';
      }
      // Authenticated → must be on /home (or a future protected route).
      // If the user is still on /sign-in, push them home.
      if (loggingIn) return '/home';
      return null;
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
