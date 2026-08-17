import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../splash_screen.dart';

/// App-level router. F2 ships a single route (`/` → [SplashScreen]).
/// F3+ will add auth, tank, fish, and other nested routes here.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SplashScreen(),
      ),
    ],
  );
});
