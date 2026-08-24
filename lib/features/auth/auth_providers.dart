import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

/// Streams the live [AuthState] from Supabase. Sign-in / sign-up /
/// sign-out / token refresh all emit new values here, so any
/// `ref.watch`-on-this-provider rebuilds.
///
/// The Supabase SDK owns the broadcast stream; we just re-expose it
/// to Riverpod so widgets can declare a dependency on auth state
/// alongside the rest of their providers.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return getSupabase().auth.onAuthStateChange;
});

/// Convenience: just the current user (or `null` if signed out).
/// Widgets that only care about identity (e.g. the home screen) read
/// this instead of digging into the full [AuthState].
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider).value;
  return authState?.session?.user;
});
