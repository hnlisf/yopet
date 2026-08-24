import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';
import '../auth/auth_providers.dart';

/// Signed-in landing screen.
///
/// F3 is a minimum-viable home: shows the user's email and a Sign out
/// button. F4+ will replace this with the empty-tank placeholder
/// (PRD §6.1) and then a real tank (F6+).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '(signed out)';

    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Logged in as:',
                    style: const TextStyle(
                      color: Tokens.textDim,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Tokens.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => _signOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Tokens.tankGlowSoft,
                      side: const BorderSide(
                        color: Tokens.tankGlowSoft,
                        width: 1,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await getSupabase().auth.signOut();
    } on AuthException catch (_) {
      // The user's already signed out in Supabase's view; the router
      // redirect on next build will still send them back to /sign-in.
    }
    if (context.mounted) context.go('/sign-in');
  }
}
