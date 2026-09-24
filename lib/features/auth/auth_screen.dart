import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme/tokens.dart';

/// A quiet threshold into the player's own aquarium.
///
/// The form keeps real email/password authentication, while the scene uses the
/// same watercolor fish and tank artwork as the home experience so the first
/// screen no longer feels detached from the product.
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
  var _busy = false;
  var _obscurePassword = true;
  var _obscureConfirmation = true;
  String? _error;
  String? _notice;
  String? _pendingConfirmationEmail;

  bool get _isSignUp => _mode == AuthMode.signUp;

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
    final confirmation = _isSignUp ? _confirm.text : null;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '填好邮箱和密码，就能回到鱼缸。');
      return;
    }
    if (_isSignUp && password != confirmation) {
      setState(() => _error = '两次输入的密码还不一样。');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final auth = getSupabase().auth;
      final response = _isSignUp
          ? await auth.signUp(email: email, password: password)
          : await auth.signInWithPassword(email: email, password: password);

      // A hosted environment may require email confirmation. Do not show a
      // false "success" and immediately try to open an unauthenticated tank.
      if (response.session == null) {
        if (!mounted) return;
        setState(() {
          _mode = AuthMode.signIn;
          _pendingConfirmationEmail = email;
          _notice = '账号已经创建。确认邮箱后，再从这里进入鱼缸。';
        });
        return;
      }

      if (!mounted) return;
      // currentUserProvider has an SDK-session fallback for this exact
      // handoff, so the router can enter /home without waiting for the async
      // auth stream's next event.
      context.go('/home');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _mapError(error.message));
    } catch (_) {
      if (mounted) {
        setState(() => _error = '暂时连不上鱼缸，检查网络后再试一次。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingConfirmationEmail;
    if (email == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await getSupabase().auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      setState(() => _notice = '确认邮件已重新发往 $email，请留意收件箱。');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _mapError(error.message));
    } catch (_) {
      if (mounted) {
        setState(() => _error = '暂时不能重发确认邮件，稍后再试一次。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeMode(AuthMode mode) {
    if (_busy || mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _pendingConfirmationEmail = null;
    });
  }

  String _mapError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered')) return '这个邮箱已经有一座鱼缸了，直接登录吧。';
    if (lower.contains('at least 6 characters')) return '密码至少需要 6 位。';
    if (lower.contains('invalid login credentials')) return '邮箱或密码不对，再慢慢检查一次。';
    if (lower.contains('email not confirmed')) return '请先完成邮箱确认，再回来进入鱼缸。';
    return '暂时没能进入鱼缸，再试一次吧。';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Tokens.primaryBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuthAquariumBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: _WelcomeCopy(isSignUp: _isSignUp),
            ),
          ),
          const _FriendlyGoldfish(),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: size.height * 0.66,
              ),
              child: _AuthWaterSheet(
                mode: _mode,
                email: _email,
                password: _password,
                confirmation: _confirm,
                busy: _busy,
                obscurePassword: _obscurePassword,
                obscureConfirmation: _obscureConfirmation,
                error: _error,
                notice: _notice,
                pendingConfirmationEmail: _pendingConfirmationEmail,
                onModeChanged: _changeMode,
                onPasswordVisibilityChanged: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                onConfirmationVisibilityChanged: () {
                  setState(() => _obscureConfirmation = !_obscureConfirmation);
                },
                onResendConfirmation: _resendConfirmation,
                onSubmit: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthAquariumBackground extends StatelessWidget {
  const _AuthAquariumBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/tank/background.png', fit: BoxFit.cover),
        const ColoredBox(color: Color(0x22030D18)),
      ],
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'yopet',
          style: GoogleFonts.fraunces(
            color: Tokens.text,
            fontSize: 42,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Tokens.tankGlow.withValues(alpha: 0.4),
                blurRadius: 14,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          isSignUp ? '留下一座\n属于你的鱼缸' : '回到你的\n安静水域',
          style: GoogleFonts.manrope(
            color: Tokens.text,
            fontSize: 28,
            height: 1.24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isSignUp ? '从一条小鱼开始，慢慢养成自己的片刻。' : '忙碌之外，留一小段时间给鱼儿，也给自己。',
          style: GoogleFonts.manrope(
            color: Tokens.textDim,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _FriendlyGoldfish extends StatelessWidget {
  const _FriendlyGoldfish();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0.46, -0.1),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Tokens.tankGlow.withValues(alpha: 0.34),
                blurRadius: 22,
                spreadRadius: 3,
              ),
            ],
            borderRadius: BorderRadius.circular(70),
          ),
          child: Image.asset(
            'assets/fish/goldfish/adult.png',
            width: 178,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _AuthWaterSheet extends StatelessWidget {
  const _AuthWaterSheet({
    required this.mode,
    required this.email,
    required this.password,
    required this.confirmation,
    required this.busy,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.error,
    required this.notice,
    required this.pendingConfirmationEmail,
    required this.onModeChanged,
    required this.onPasswordVisibilityChanged,
    required this.onConfirmationVisibilityChanged,
    required this.onResendConfirmation,
    required this.onSubmit,
  });

  final AuthMode mode;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmation;
  final bool busy;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final String? error;
  final String? notice;
  final String? pendingConfirmationEmail;
  final ValueChanged<AuthMode> onModeChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onConfirmationVisibilityChanged;
  final VoidCallback onResendConfirmation;
  final VoidCallback onSubmit;

  bool get isSignUp => mode == AuthMode.signUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      decoration: BoxDecoration(
        color: Tokens.primaryBg.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF030D18).withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 16),
            _AuthModeSwitch(
              mode: mode,
              enabled: !busy,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 18),
            _AuthField(
              controller: email,
              label: '邮箱',
              hint: 'name@example.com',
              icon: Icons.mail_outline_rounded,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            _AuthField(
              controller: password,
              label: '密码',
              hint: isSignUp ? '至少 6 位' : '输入密码',
              icon: Icons.lock_outline_rounded,
              enabled: !busy,
              obscureText: obscurePassword,
              autofillHints: isSignUp
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              onVisibilityChanged: onPasswordVisibilityChanged,
            ),
            if (isSignUp) ...[
              const SizedBox(height: 12),
              _AuthField(
                controller: confirmation,
                label: '确认密码',
                hint: '再输入一次密码',
                icon: Icons.lock_reset_outlined,
                enabled: !busy,
                obscureText: obscureConfirmation,
                autofillHints: const [AutofillHints.newPassword],
                onVisibilityChanged: onConfirmationVisibilityChanged,
              ),
            ],
            if (error != null || notice != null) ...[
              const SizedBox(height: 12),
              _AuthMessage(text: error ?? notice!, isError: error != null),
            ],
            if (pendingConfirmationEmail != null) ...[
              const SizedBox(height: 10),
              PendingEmailConfirmationNotice(
                email: pendingConfirmationEmail!,
                busy: busy,
                onResend: onResendConfirmation,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.tankGlow,
                  foregroundColor: Tokens.primaryBg,
                  disabledBackgroundColor: Tokens.tankGlow.withValues(
                    alpha: 0.45,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Tokens.primaryBg,
                        ),
                      )
                    : const Icon(Icons.waves_rounded, size: 20),
                label: Text(isSignUp ? '创建我的鱼缸' : '进入鱼缸'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync_rounded, size: 15, color: Tokens.textDim),
                const SizedBox(width: 6),
                Text(
                  '同一账号，会带着你的鱼缸一起回来。',
                  style: GoogleFonts.manrope(
                    color: Tokens.textDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: Tokens.tankGlowSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final AuthMode mode;
  final bool enabled;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          for (final target in AuthMode.values)
            Expanded(
              child: _AuthModeOption(
                label: target == AuthMode.signIn ? '登录' : '注册',
                selected: mode == target,
                enabled: enabled,
                onTap: () => onChanged(target),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Tokens.tankGlow.withValues(alpha: 0.22) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? Tokens.text : Tokens.textDim,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints = const <String>[],
    this.onVisibilityChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String> autofillHints;
  final VoidCallback? onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      style: GoogleFonts.manrope(color: Tokens.text, fontSize: 16),
      cursorColor: Tokens.tankGlow,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.manrope(color: Tokens.textDim),
        hintStyle: GoogleFonts.manrope(
          color: Tokens.textDim.withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(icon, color: Tokens.tankGlowSoft, size: 20),
        suffixIcon: onVisibilityChanged == null
            ? null
            : IconButton(
                tooltip: obscureText ? '显示密码' : '隐藏密码',
                onPressed: enabled ? onVisibilityChanged : null,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                color: Tokens.textDim,
              ),
        filled: true,
        fillColor: Tokens.surface.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: _fieldBorder(Tokens.textDim.withValues(alpha: 0.26)),
        enabledBorder: _fieldBorder(Tokens.textDim.withValues(alpha: 0.26)),
        focusedBorder: _fieldBorder(Tokens.tankGlowSoft),
        disabledBorder: _fieldBorder(Tokens.textDim.withValues(alpha: 0.12)),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Tokens.amber : Tokens.tankGlowSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(color: color, fontSize: 13, height: 1.4),
      ),
    );
  }
}

/// Keeps the production confirmation path actionable without implying that the
/// account already has a usable session.
class PendingEmailConfirmationNotice extends StatelessWidget {
  const PendingEmailConfirmationNotice({
    super.key,
    required this.email,
    required this.busy,
    required this.onResend,
  });

  final String email;
  final bool busy;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tokens.tankGlow.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请先确认 $email',
              style: GoogleFonts.manrope(
                color: Tokens.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '确认后直接用这个邮箱登录即可。',
              style: GoogleFonts.manrope(color: Tokens.textDim, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : onResend,
                icon: const Icon(Icons.mark_email_unread_outlined, size: 17),
                label: const Text('重新发送确认邮件'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
