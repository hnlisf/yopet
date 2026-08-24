import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin accessor for the global Supabase client.
///
/// `main.dart` already calls `Supabase.initialize(url, anonKey)` at
/// startup, so by the time any widget builds this returns the same
/// instance that `Supabase.instance.client` would. F3 just funnels
/// every auth call through this accessor so future refactors (e.g.
/// a per-test client) only touch one symbol.
SupabaseClient getSupabase() => Supabase.instance.client;
