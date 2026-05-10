import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../onboarding/onboarding_design.dart';
import 'widgets/auth_text_field.dart';

enum _LoginMode { mobile, email }

/// Dailyhunt-style sign-in screen: white background, green accent,
/// mobile (OTP) + email (password) flows, social buttons and a legal footer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginMode _mode = _LoginMode.mobile;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool get _showAppleButton {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  bool _isValidPhone(String v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v);
  bool _isValidEmail(String v) => RegExp(
        r'^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$',
        caseSensitive: false,
      ).hasMatch(v);

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (_mode == _LoginMode.mobile) {
      final phone = _phoneCtrl.text.trim();
      if (!_isValidPhone(phone)) {
        setState(() => _error = 'Enter a valid 10-digit mobile number');
        return;
      }
      await _sendOtp('+91$phone');
    } else {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (!_isValidEmail(email)) {
        setState(() => _error = 'Enter a valid email address');
        return;
      }
      if (pass.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        return;
      }
      await _loginWithPassword(email, pass);
    }
  }

  Future<void> _sendOtp(String target) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.sendOtp(target: target, purpose: 'login');
      if (!mounted) return;
      if (res['success'] == true) {
        context.push('/login/otp', extra: {'target': target});
      } else {
        setState(() =>
            _error = (res['message'] as String?) ?? 'Could not send OTP. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithPassword(String email, String pass) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.login(email, pass);
      if (!mounted) return;
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (!mounted) return;
        context.go(auth.homeRoute);
      } else {
        setState(() =>
            _error = (res['message'] as String?) ?? 'Invalid email or password.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label sign-in is coming soon'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final continueLabel =
        _mode == _LoginMode.mobile ? 'Continue' : 'Sign in';

    return Scaffold(
      backgroundColor: OnboardingDesign.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const _BrandHeader(),
                  const SizedBox(height: 28),
                  _ModeSwitcher(
                    mode: _mode,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _mode == _LoginMode.mobile
                        ? _buildMobileForm()
                        : _buildEmailForm(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 22),
                  _PrimaryActionButton(
                    label: continueLabel,
                    loading: _loading,
                    onPressed: _continue,
                  ),
                  const SizedBox(height: 22),
                  const _OrDivider(),
                  const SizedBox(height: 18),
                  _SocialButton(
                    label: 'Continue with Google',
                    icon: const _GoogleGlyph(),
                    onPressed: () => _showComingSoon('Google'),
                  ),
                  if (_showAppleButton) ...[
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Apple',
                      icon: const Icon(Icons.apple,
                          color: Colors.black, size: 22),
                      onPressed: () => _showComingSoon('Apple'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _RegisterPrompt(
                    onTap: () => context.push('/register'),
                  ),
                  const SizedBox(height: 18),
                  const _LegalFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileForm() {
    return Column(
      key: const ValueKey('mobile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Mobile number'),
        const SizedBox(height: 8),
        AuthTextField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          hintText: '98765 43210',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          prefix: const _CountryCodePrefix(code: '+91'),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _continue(),
        ),
        const SizedBox(height: 6),
        Text(
          "We'll send you a 6-digit OTP to verify",
          style: GoogleFonts.notoSans(
            fontSize: 12.5,
            color: OnboardingDesign.subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Email'),
        const SizedBox(height: 8),
        AuthTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.alternate_email,
                size: 18, color: OnboardingDesign.subtitleColor),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _passFocus.requestFocus(),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Password'),
        const SizedBox(height: 8),
        AuthTextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          hintText: 'Enter your password',
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.lock_outline,
                size: 18, color: OnboardingDesign.subtitleColor),
          ),
          suffix: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: OnboardingDesign.subtitleColor,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _continue(),
        ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: OnboardingDesign.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.newspaper_rounded,
            color: OnboardingDesign.accent,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppConstants.appName,
          style: GoogleFonts.notoSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: OnboardingDesign.titleColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'News in your language',
          style: GoogleFonts.notoSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: OnboardingDesign.subtitleColor,
          ),
        ),
      ],
    );
  }
}

// ─── Mobile / Email switch ────────────────────────────────────────────────

class _ModeSwitcher extends StatelessWidget {
  final _LoginMode mode;
  final ValueChanged<_LoginMode> onChanged;

  const _ModeSwitcher({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
              child: _modeTab(
                  context, _LoginMode.mobile, Icons.phone_android, 'Mobile')),
          Expanded(
              child: _modeTab(
                  context, _LoginMode.email, Icons.alternate_email, 'Email')),
        ],
      ),
    );
  }

  Widget _modeTab(BuildContext context, _LoginMode m, IconData icon, String label) {
    final selected = mode == m;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? OnboardingDesign.titleColor
                  : OnboardingDesign.subtitleColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected
                    ? OnboardingDesign.titleColor
                    : OnboardingDesign.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Country code chip ────────────────────────────────────────────────────

class _CountryCodePrefix extends StatelessWidget {
  final String code;
  const _CountryCodePrefix({required this.code});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: OnboardingDesign.titleColor,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 22, color: OnboardingDesign.outline),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.notoSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: OnboardingDesign.titleColor,
      ),
    );
  }
}

// ─── Primary button (with loader) ─────────────────────────────────────────

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: OnboardingDesign.accent,
          disabledBackgroundColor:
              OnboardingDesign.accent.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OnboardingDesign.radiusButton),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label, style: OnboardingDesign.buttonLabel()),
      ),
    );
  }
}

// ─── Or divider ───────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: OnboardingDesign.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OnboardingDesign.subtitleColor,
            ),
          ),
        ),
        const Expanded(child: Divider(color: OnboardingDesign.outline)),
      ],
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: OnboardingDesign.outline),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OnboardingDesign.radiusButton),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: OnboardingDesign.titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: GoogleFonts.notoSans(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF4285F4),
        height: 1,
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Register prompt ──────────────────────────────────────────────────────

class _RegisterPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.notoSans(
            fontSize: 13.5,
            color: OnboardingDesign.subtitleColor,
            fontWeight: FontWeight.w500,
          ),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Create one',
              style: GoogleFonts.notoSans(
                fontSize: 13.5,
                color: OnboardingDesign.accent,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legal footer ─────────────────────────────────────────────────────────

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    void openPrivacy() => context.push('/privacy-policy');
    void openTerms() => context.push('/privacy-policy');

    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.notoSans(
            fontSize: 12,
            color: OnboardingDesign.subtitleColor,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: OnboardingDesign.accent,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()..onTap = openTerms,
            ),
            const TextSpan(text: ' & '),
            TextSpan(
              text: 'Privacy Policy',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: OnboardingDesign.accent,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()..onTap = openPrivacy,
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
