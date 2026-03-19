import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/otp_input_widget.dart';
import '../../constants.dart';

// Login method options
enum _LoginMethod { password, otp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  _LoginMethod _method   = _LoginMethod.password; // default tab
  int          _otpStep  = 0; // 0 = enter target, 1 = enter OTP

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

  // OTP login
  final _otpFormKey    = GlobalKey<FormState>();
  final _targetCtrl    = TextEditingController();
  final _targetFocus   = FocusNode();
  bool _targetTouched  = false;
  bool _otpSubmitted   = false;
  String _enteredOtp   = '';
  String _maskedTarget = '';
  String _channel      = '';

  // Shared loading / error
  bool    _loading  = false;
  String? _error;

  // Tab animation
  late AnimationController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true);
    });
    _passFocus.addListener(() {
      if (!_passFocus.hasFocus) setState(() => _passTouched = true);
    });
    _targetFocus.addListener(() {
      if (!_targetFocus.hasFocus) setState(() => _targetTouched = true);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _targetCtrl.dispose();
    _emailFocus.dispose(); _passFocus.dispose(); _targetFocus.dispose();
    super.dispose();
  }

  void _switchMethod(_LoginMethod m) {
    if (_method == m) return;
    setState(() {
      _method      = m;
      _error       = null;
      _otpStep     = 0;
      _enteredOtp  = '';
      _pwSubmitted = false;
      _otpSubmitted = false;
    });
  }

  // ── Password login ─────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (!_emailTouched && !_pwSubmitted) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$')
        .hasMatch(val)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (!_passTouched && !_pwSubmitted) return null;
    final val = v ?? '';
    if (val.isEmpty) return 'Password is required';
    if (val.length < 6) return 'Minimum 6 characters';
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

  // ── OTP login — step 1: send OTP ───────────────────────────────────────────

  String? _validateTarget(String? v) {
    if (!_targetTouched && !_otpSubmitted) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Email or phone number is required';
    final isEmail = RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$')
        .hasMatch(val);
    final isPhone = RegExp(r'^\+?[\d\s\-\(\)]{7,15}$').hasMatch(val);
    if (!isEmail && !isPhone) return 'Enter a valid email or phone number';
    return null;
  }

  Future<void> _sendOtp() async {
    setState(() { _otpSubmitted = true; _targetTouched = true; });
    if (!_otpFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.sendOtp(
          target: _targetCtrl.text.trim(), purpose: 'login');
      if (res['success'] == true) {
        setState(() {
          _channel      = res['channel'] ?? 'email';
          _maskedTarget = res['maskedTarget'] ?? _targetCtrl.text.trim();
          _otpStep      = 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Failed to send OTP.');
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── OTP login — step 2: verify OTP ─────────────────────────────────────────

  Future<void> _verifyOtp(String code) async {
    if (code.length < 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.verifyLoginOtp(
          target: _targetCtrl.text.trim(), code: code);
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (mounted) context.go(auth.homeRoute);
      } else {
        setState(() => _error = res['message'] ?? 'Invalid OTP.');
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _error = null);
    final res = await ApiService.sendOtp(
        target: _targetCtrl.text.trim(), purpose: 'login');
    if (res['success'] != true && mounted) {
      setState(() => _error = res['message'] ?? 'Failed to resend OTP.');
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
                const Center(child: Text('Sign in to your account',
                    style: TextStyle(fontSize: 14, color: GlassColors.textTertiary))),
                const SizedBox(height: 32),

                // ── Login method toggle (only shown on step 0) ───────────
                if (_otpStep == 0) ...[
                  _MethodToggle(
                    selected: _method,
                    onChanged: _switchMethod,
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Error banner ─────────────────────────────────────────
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                // ── Content: switches based on method + step ─────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _method == _LoginMethod.password
                      ? _buildPasswordForm(key: const ValueKey('pw'))
                      : (_otpStep == 0
                          ? _buildOtpStep1(key: const ValueKey('otp1'))
                          : _buildOtpStep2(key: const ValueKey('otp2'))),
                ),

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

                // ── Dev quick fill ───────────────────────────────────────
                if (AppConstants.isDevelopment) ...[
                  const SizedBox(height: 28),
                  _DevPanel(
                    method: _method,
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    targetCtrl: _targetCtrl,
                  ),
                ],

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
          child: const Row(children: [
            Icon(Icons.admin_panel_settings, size: 15, color: GlassColors.accentOrangeLight),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Admins must use password login. Reporters and users can use either method.',
              style: TextStyle(fontSize: 12, color: GlassColors.accentOrangeLight, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        _FieldLabel(label: 'Email', required: true),
        const SizedBox(height: 6),
        GlassTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: _validateEmail,
          onChanged: (_) { if (_pwSubmitted) setState(() {}); },
        ),
        const SizedBox(height: 14),

        _FieldLabel(label: 'Password', required: true),
        const SizedBox(height: 6),
        GlassTextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          hintText: 'Enter your password',
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
          label: 'Sign In',
          icon: Icons.login_rounded,
          onPressed: _loginWithPassword,
          loading: _loading,
        ),
      ]),
    );
  }

  // ── OTP step 1: enter target ────────────────────────────────────────────────

  Widget _buildOtpStep1({Key? key}) {
    return Form(
      key: _otpFormKey,
      autovalidateMode: _otpSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Info note
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: GlassColors.accentGreen.withOpacity(0.08),
          borderColor: GlassColors.accentGreenBorder,
          child: const Row(children: [
            Icon(Icons.info_outline, size: 15, color: GlassColors.accentGreenLight),
            SizedBox(width: 8),
            Expanded(child: Text(
              'A 6-digit OTP will be sent to your registered email or phone number.',
              style: TextStyle(fontSize: 12, color: GlassColors.accentGreenLight, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        _FieldLabel(label: 'Email or Phone Number', required: true),
        const SizedBox(height: 6),
        GlassTextField(
          controller: _targetCtrl,
          focusNode: _targetFocus,
          hintText: 'you@example.com  or  +91 98765 43210',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.alternate_email),
          validator: _validateTarget,
          onChanged: (_) { if (_otpSubmitted) setState(() {}); },
          onFieldSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 26),

        GlassButton(
          label: 'Send OTP',
          icon: Icons.send_rounded,
          onPressed: _sendOtp,
          loading: _loading,
        ),
      ]),
    );
  }

  // ── OTP step 2: verify code ─────────────────────────────────────────────────

  Widget _buildOtpStep2({Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // Back link
      GestureDetector(
        onTap: () => setState(() { _otpStep = 0; _error = null; _enteredOtp = ''; }),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: GlassColors.textTertiary),
          SizedBox(width: 5),
          Text('Change number / email',
              style: TextStyle(fontSize: 13, color: GlassColors.textTertiary)),
        ]),
      ),
      const SizedBox(height: 24),

      // Sent-to info
      GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: GlassColors.accentGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _channel == 'phone' ? Icons.phone_android : Icons.mark_email_read_outlined,
              color: GlassColors.accentGreenLight, size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Code sent to',
                style: TextStyle(fontSize: 11, color: GlassColors.textTertiary)),
            const SizedBox(height: 2),
            Text(_maskedTarget,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: GlassColors.accentGreenLight)),
          ])),
        ]),
      ),
      const SizedBox(height: 28),

      // OTP boxes
      GlassOtpInput(
        onCompleted: _verifyOtp,
        onChanged: (v) => setState(() => _enteredOtp = v),
      ),
      const SizedBox(height: 14),

      if (_loading)
        const Center(child: SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: GlassColors.accentGreenLight))),

      const SizedBox(height: 20),

      if (_enteredOtp.length == 6 && !_loading)
        GlassButton(
          label: 'Verify & Sign In',
          icon: Icons.verified_rounded,
          onPressed: () => _verifyOtp(_enteredOtp),
          loading: _loading,
        ),

      const SizedBox(height: 24),
      Center(child: ResendOtpButton(onResend: _resendOtp)),
      const SizedBox(height: 6),
      const Center(child: Text('Code expires in 10 minutes',
          style: TextStyle(fontSize: 12, color: GlassColors.textHint))),
    ]);
  }
}

// ─── Login Method Toggle ──────────────────────────────────────────────────────

class _MethodToggle extends StatelessWidget {
  final _LoginMethod selected;
  final void Function(_LoginMethod) onChanged;

  const _MethodToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(4),
      borderRadius: 14,
      child: Row(children: [
        _Tab(
          label: 'Password',
          icon: Icons.lock_outline,
          active: selected == _LoginMethod.password,
          onTap: () => onChanged(_LoginMethod.password),
        ),
        _Tab(
          label: 'OTP',
          icon: Icons.sms_outlined,
          active: selected == _LoginMethod.otp,
          onTap: () => onChanged(_LoginMethod.otp),
          badge: 'Reporter / User',
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? GlassColors.accentGreenSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? GlassColors.accentGreenBorder : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 15,
                  color: active ? GlassColors.accentGreenLight : GlassColors.textHint),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? GlassColors.accentGreenLight : GlassColors.textHint,
                  )),
            ]),
            if (badge != null) ...[
              const SizedBox(height: 3),
              Text(badge!,
                  style: TextStyle(
                    fontSize: 9,
                    color: active ? GlassColors.accentGreenLight.withOpacity(0.7) : GlassColors.textHint.withOpacity(0.6),
                  )),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Dev Panel ────────────────────────────────────────────────────────────────

class _DevPanel extends StatelessWidget {
  final _LoginMethod method;
  final TextEditingController emailCtrl, passCtrl, targetCtrl;

  const _DevPanel({
    required this.method,
    required this.emailCtrl,
    required this.passCtrl,
    required this.targetCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dev Quick Fill',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: GlassColors.textHint, letterSpacing: 0.8)),
        const SizedBox(height: 8),

        if (method == _LoginMethod.password) ...[
          _QuickFillRow(
            label: 'Admin',
            onTap: () { emailCtrl.text = 'admin@newsapp.com'; passCtrl.text = 'Admin@123'; },
            color: GlassColors.accentOrangeLight,
            icon: Icons.admin_panel_settings,
          ),
          const SizedBox(height: 6),
          _QuickFillRow(
            label: 'Reporter (password)',
            onTap: () { emailCtrl.text = 'reporter@newsapp.com'; passCtrl.text = 'Reporter@123'; },
            color: GlassColors.accentGreenLight,
            icon: Icons.mic,
          ),
          const SizedBox(height: 6),
          _QuickFillRow(
            label: 'User (password)',
            onTap: () { emailCtrl.text = 'user@newsapp.com'; passCtrl.text = 'User@1234'; },
            color: GlassColors.info,
            icon: Icons.person,
          ),
        ] else ...[
          _QuickFillRow(
            label: 'Reporter email (OTP)',
            onTap: () { targetCtrl.text = 'reporter@newsapp.com'; },
            color: GlassColors.accentGreenLight,
            icon: Icons.mic,
          ),
          const SizedBox(height: 6),
          _QuickFillRow(
            label: 'User email (OTP)',
            onTap: () { targetCtrl.text = 'user@newsapp.com'; },
            color: GlassColors.info,
            icon: Icons.person,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: GlassColors.accentOrangeSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassColors.accentOrangeBorder, width: 0.8)),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: GlassColors.accentOrangeLight),
              SizedBox(width: 6),
              Expanded(child: Text(
                'Admin OTP is blocked — use Password tab for admin login.',
                style: TextStyle(fontSize: 11, color: GlassColors.accentOrangeLight),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _QuickFillRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _QuickFillRow({
    required this.label,
    required this.onTap,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: GlassColors.surfaceBright,
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: GlassColors.textSecondary)),
          const Spacer(),
          const Icon(Icons.bolt, size: 12, color: GlassColors.warning),
        ]),
      ),
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