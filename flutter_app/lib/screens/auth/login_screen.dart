import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import '../../utils/i18n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  // Password login
  final _pwFormKey   = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _emailFocus  = FocusNode();
  final _passFocus   = FocusNode();
  bool _obscure      = true;
  bool _pwSubmitted  = false;
  bool _emailTouched = false;
  bool _passTouched  = false;

  // Shared loading / error
  bool    _loading  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true);
    });
    _passFocus.addListener(() {
      if (!_passFocus.hasFocus) setState(() => _passTouched = true);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  // ── Password login ─────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (!_emailTouched && !_pwSubmitted) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return I18n.t(context, 'err_email_required');
    if (val.length > 254 || val.contains(' ') ||
        !RegExp(r'^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$', caseSensitive: false).hasMatch(val)) {
      return I18n.t(context, 'err_email_invalid');
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (!_passTouched && !_pwSubmitted) return null;
    final val = v ?? '';
    if (val.isEmpty) return I18n.t(context, 'err_password_required');
    if (val.length < 6) return I18n.t(context, 'err_password_min');
    return null;
  }

  Future<void> _loginWithPassword() async {
    setState(() { _pwSubmitted = true; _emailTouched = true; _passTouched = true; });
    if (!_pwFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.login(
        _emailCtrl.text.trim(), _passCtrl.text);
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (mounted) context.go(auth.homeRoute);
      } else {
        setState(() => _error = res['message'] ?? 'Invalid email or password.');
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 52),

                // ── Logo + title ─────────────────────────────────────────
                Center(child: Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [GlassColors.accentGreen, Color(0xFF0F6E56)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GlassColors.accentGreenBorder, width: 0.8),
                  ),
                  child: const Icon(Icons.newspaper, color: Colors.white, size: 34),
                )),
                const SizedBox(height: 18),
                Center(child: Text(AppConstants.appName,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: GlassColors.textPrimary, letterSpacing: -0.5))),
                const SizedBox(height: 5),
                Center(child: Text(I18n.t(context, 'login_subtitle'),
                    style: const TextStyle(fontSize: 14, color: GlassColors.textTertiary))),
                const SizedBox(height: 32),

                // ── Error banner ─────────────────────────────────────────
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                _buildPasswordForm(key: const ValueKey('pw')),

                const SizedBox(height: 20),

                // ── Register link ────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: GlassColors.textTertiary, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text('Register',
                        style: TextStyle(color: GlassColors.accentGreenLight,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Password form ───────────────────────────────────────────────────────────

  Widget _buildPasswordForm({Key? key}) {
    return Form(
      key: _pwFormKey,
      autovalidateMode: _pwSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Admin note
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: GlassColors.accentOrange.withOpacity(0.08),
          borderColor: GlassColors.accentOrangeBorder,
          child: Row(children: [
            const Icon(Icons.admin_panel_settings, size: 15, color: GlassColors.accentOrangeLight),
            const SizedBox(width: 8),
            Expanded(child: Text(
              I18n.t(context, 'login_admin_note'),
              style: const TextStyle(fontSize: 12, color: GlassColors.accentOrangeLight, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        _FieldLabel(label: I18n.t(context, 'field_email'), required: true),
        const SizedBox(height: 6),
        GlassTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          hintText: I18n.t(context, 'hint_email'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: _validateEmail,
          onChanged: (_) { if (_pwSubmitted) setState(() {}); },
        ),
        const SizedBox(height: 14),

        _FieldLabel(label: I18n.t(context, 'field_password'), required: true),
        const SizedBox(height: 6),
        GlassTextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          hintText: I18n.t(context, 'login_hint_password'),
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
                color: GlassColors.textTertiary, size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          validator: _validatePassword,
          onChanged: (_) { if (_pwSubmitted) setState(() {}); },
          onFieldSubmitted: (_) => _loginWithPassword(),
        ),
        const SizedBox(height: 26),

        GlassButton(
          label: I18n.t(context, 'action_signin'),
          icon: Icons.login_rounded,
          onPressed: _loginWithPassword,
          loading: _loading,
        ),
      ]),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: GlassColors.textSecondary)),
      if (required) ...[
        const SizedBox(width: 3),
        const Text('*', style: TextStyle(color: GlassColors.accentOrangeLight, fontSize: 13)),
      ],
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: GlassColors.accentOrangeBorder,
      color: GlassColors.accentOrangeSurface,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: GlassColors.accentOrangeLight, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: GlassColors.accentOrangeLight,
                fontSize: 13, height: 1.4))),
      ]),
    );
  }
}