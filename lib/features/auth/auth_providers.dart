import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../home/tank.dart';

/// Streams the live [AuthState] from Supabase. Sign-in / sign-up /
/// sign-out / token refresh all emit new values here, so any
/// `ref.watch`-on-this-provider rebuilds.
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

/// Streams the signed-in user's [Tank] row (or `null` if no row yet).
///
/// Reads the current user from [currentUserProvider]; when signed out
/// the stream is empty (autoDispose'd) so the home screen can render
/// a graceful "not signed in" state. Uses Supabase realtime so
/// `public.tanks` row updates push to the home screen instantly
/// (the migration `alter publication supabase_realtime add table
/// public.tanks;` registers the channel).
final tankStreamProvider = StreamProvider<Tank?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream<Tank?>.empty();
  final client = getSupabase();
  return client
      .from('tanks')
      .stream(primaryKey: ['owner_id'])
      .eq('owner_id', user.id)
      .limit(1)
      .map((rows) => rows.isEmpty ? null : Tank.fromMap(rows.first))
      .asBroadcastStream();
});
