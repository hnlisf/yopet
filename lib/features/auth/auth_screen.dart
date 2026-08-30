import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';

/// Sign in or sign up — a single screen, mode chosen by the top toggle.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { signIn, signUp }

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _mode == AuthMode.signUp ? _confirm.text : null;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '邮箱和密码不能为空');
      return;
    }
    if (_mode == AuthMode.signUp && password != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = getSupabase().auth;
      if (_mode == AuthMode.signIn) {
        await client.signInWithPassword(email: email, password: password);
      } else {
        // ENABLE_EMAIL_AUTOCONFIRM=true in devmode: signUp returns a
        // session immediately, so the user lands on /home without
        // a verify-link step. The redirect logic picks that up.
        await client.signUp(email: email, password: password);
      }
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = _mapError(e.message));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mapError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered')) return '邮箱已注册';
    if (lower.contains('at least 6 characters')) return '密码至少 6 位';
    if (lower.contains('invalid login credentials')) return '邮箱或密码错误';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == AuthMode.signUp;
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
                  _ToggleBar(
                    mode: _mode,
                    onChanged: _busy
                        ? null
                        : (m) => setState(() {
                            _mode = m;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    controller: _email,
                    enabled: !_busy,
                    label: '邮箱',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    enabled: !_busy,
                    label: '密码',
                    obscureText: true,
                    autofillHints: isSignUp
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                  ),
                  if (isSignUp) ...[
                    const SizedBox(height: 12),
                    _Field(
                      controller: _confirm,
                      enabled: !_busy,
                      label: '确认密码',
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Tokens.tankGlow,
                        foregroundColor: Tokens.primaryBg,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Tokens.primaryBg,
                              ),
                            )
                          : Text(isSignUp ? '注册' : '登录'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 24,
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Text(
                            _error!,
                            style: const TextStyle(color: Tokens.amber),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleBar extends StatelessWidget {
  const _ToggleBar({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in AuthMode.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: m == AuthMode.signIn ? 8 : 0),
              child: _TogglePill(
                label: m == AuthMode.signIn ? '登录' : '注册',
                selected: m == mode,
                onTap: onChanged == null ? null : () => onChanged!(m),
              ),
            ),
          ),
      ],
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Tokens.tankGlow.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Tokens.tankGlow : Tokens.tankGlowSoft,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Tokens.tankGlow : Tokens.textDim,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.enabled,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints = const [],
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String> autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      style: const TextStyle(color: Tokens.text),
      cursorColor: Tokens.tankGlow,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Tokens.textDim),
        filled: true,
        fillColor: Tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Tokens.tankGlowSoft, width: 1),
        ),
      ),
    );
  }
}
