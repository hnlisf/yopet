import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';
import '../auth/auth_providers.dart';

/// Signed-in landing surface for the F4 "empty tank" state.
///
/// Watches [tankStreamProvider]; the spec ships an empty-tank
/// placeholder (no fish yet) because the actual fish-picker lives in
/// F6 (issue #6). The "选你的第一条鱼" button pushes /pick-fish, a
/// route the F4 router has registered as a placeholder; F6 will swap
/// the body for a real picker.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tankAsync = ref.watch(tankStreamProvider);
    final email = user?.email ?? '(signed out)';

    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tankAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Tokens.tankGlow,
                        ),
                      ),
                    )
                  else
                    _EmptyTankCard(
                      onPickFish: () => context.go('/pick-fish'),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Tokens.textDim,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _signOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Tokens.tankGlowSoft,
                      side: const BorderSide(
                        color: Tokens.tankGlowSoft,
                        width: 1,
                      ),
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
      // User is already signed out; router redirect handles the
      // user-visible transition.
    }
    if (context.mounted) context.go('/sign-in');
  }
}

/// "还没有鱼" empty-state card per docs/design/ui-design.md §9 copy
/// register + the F4 spec.
class _EmptyTankCard extends StatelessWidget {
  const _EmptyTankCard({required this.onPickFish});

  final VoidCallback onPickFish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '还没有鱼',
            style: TextStyle(
              color: Tokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '从下方选一只开始',
            style: TextStyle(color: Tokens.textDim, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onPickFish,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.tankGlow,
                foregroundColor: Tokens.primaryBg,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('选你的第一条鱼'),
            ),
          ),
        ],
      ),
    );
  }
}
