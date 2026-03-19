import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/otp_input_widget.dart';
import '../../constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Steps: 0 = fill form, 1 = verify OTP
  int _step = 0;

  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  final _nameFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _phoneFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  String _role          = 'user';
  bool _obscurePass     = true;
  bool _obscureConfirm  = true;
  bool _submitted       = false;
  bool _sending         = false;
  bool _verifying       = false;

  final Set<String> _touched = {};
  int _passStrength = 0;

  String? _apiError;
  String? _otpError;
  String  _maskedTarget = '';
  String  _channel      = '';
  String  _enteredOtp   = '';

  // Which channel the user chose for OTP
  // 'email' if email is filled, 'phone' if only phone is filled
  String get _otpChannel => _emailCtrl.text.trim().isNotEmpty ? 'email' : 'phone';
  String get _otpTarget  => _otpChannel == 'email'
      ? _emailCtrl.text.trim()
      : _phoneCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(()    { if (!_nameFocus.hasFocus)    _touch('name');    });
    _emailFocus.addListener(()   { if (!_emailFocus.hasFocus)   _touch('email');   });
    _phoneFocus.addListener(()   { if (!_phoneFocus.hasFocus)   _touch('phone');   });
    _passFocus.addListener(()    { if (!_passFocus.hasFocus)    _touch('pass');    });
    _confirmFocus.addListener(() { if (!_confirmFocus.hasFocus) _touch('confirm'); });
    _passCtrl.addListener(_updateStrength);
  }

  void _touch(String f) => setState(() => _touched.add(f));
  bool _isTouched(String f) => _touched.contains(f) || _submitted;

  void _updateStrength() {
    final p = _passCtrl.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) s++;
    setState(() => _passStrength = s);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();  _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    _nameFocus.dispose(); _emailFocus.dispose();
    _phoneFocus.dispose(); _passFocus.dispose(); _confirmFocus.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  String? _valName(String? v) {
    if (!_isTouched('name')) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Full name is required';
    if (val.length < 2) return 'At least 2 characters required';
    if (val.length > 60) return 'Must not exceed 60 characters';
    if (!RegExp(r"^[a-zA-Z\s'\-\.]+$").hasMatch(val))
      return 'Letters, spaces, hyphens, apostrophes only';
    return null;
  }

  String? _valEmail(String? v) {
    if (!_isTouched('email')) return null;
    final val = v?.trim() ?? '';
    // Email is optional only if phone is provided
    if (val.isEmpty && _phoneCtrl.text.trim().isNotEmpty) return null;
    if (val.isEmpty) return 'Email or phone is required';
    if (!RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$').hasMatch(val))
      return 'Enter a valid email address';
    return null;
  }

  String? _valPhone(String? v) {
    if (!_isTouched('phone')) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null; // optional if email given
    final digits = val.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Digits only';
    if (digits.length < 7) return 'Too short';
    if (digits.length > 15) return 'Too long';
    return null;
  }

  String? _valPass(String? v) {
    if (!_isTouched('pass')) return null;
    final val = v ?? '';
    if (val.isEmpty) return 'Password is required';
    if (val.length < 6) return 'Minimum 6 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(val)) return 'Must contain at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(val)) return 'Must contain at least one number';
    return null;
  }

  String? _valConfirm(String? v) {
    if (!_isTouched('confirm')) return null;
    if ((v ?? '').isEmpty) return 'Please confirm your password';
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  // ── Step 1: Validate form and send OTP ─────────────────────────────────────

  Future<void> _sendOtpAndProceed() async {
    setState(() {
      _submitted = true;
      _touched.addAll(['name', 'email', 'phone', 'pass', 'confirm']);
    });
    if (!_formKey.currentState!.validate()) return;

    // Must have at least email or phone
    if (_emailCtrl.text.trim().isEmpty && _phoneCtrl.text.trim().isEmpty) {
      setState(() => _apiError = 'Please enter an email or phone number.');
      return;
    }

    setState(() { _sending = true; _apiError = null; });
    try {
      final res = await ApiService.sendOtp(
        target: _otpTarget,
        purpose: 'register',
      );
      if (res['success'] == true) {
        setState(() {
          _channel      = res['channel'] ?? _otpChannel;
          _maskedTarget = res['maskedTarget'] ?? _otpTarget;
          _step         = 1;
        });
      } else {
        setState(() => _apiError = res['message'] ?? 'Failed to send OTP.');
      }
    } catch (_) {
      setState(() => _apiError = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Step 2: Verify OTP and create account ──────────────────────────────────

  Future<void> _verifyOtp(String code) async {
    if (code.length < 6) return;
    setState(() { _verifying = true; _otpError = null; });
    try {
      final res = await ApiService.verifyRegisterOtp(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role,
        code: code,
      );
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (mounted) context.go(auth.homeRoute);
      } else {
        setState(() => _otpError = res['message'] ?? 'Invalid OTP.');
      }
    } catch (_) {
      setState(() => _otpError = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _otpError = null);
    final res = await ApiService.sendOtp(target: _otpTarget, purpose: 'register');
    if (res['success'] != true && mounted) {
      setState(() => _otpError = res['message'] ?? 'Failed to resend OTP.');
    }
  }

  // ── Strength helpers ────────────────────────────────────────────────────────

  Color get _strengthColor {
    switch (_passStrength) {
      case 0: case 1: return GlassColors.error;
      case 2: return GlassColors.warning;
      case 3: return const Color(0xFF9FE1CB);
      default: return GlassColors.success;
    }
  }

  String get _strengthLabel {
    switch (_passStrength) {
      case 0: case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      default: return 'Strong';
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _step == 0
            ? GlassAppBar(title: const SizedBox.shrink(), showBack: true)
            : null,
        body: SafeArea(
          top: _step == 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                      begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: _step == 0
                  ? _buildForm(key: const ValueKey('form'))
                  : _buildOtp(key: const ValueKey('otp')),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form (Step 1) ────────────────────────────────────────────────────────────

  Widget _buildForm({Key? key}) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create account',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                  color: GlassColors.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Join NewsNow — fill in your details',
              style: TextStyle(fontSize: 14, color: GlassColors.textTertiary)),
          const SizedBox(height: 24),

          if (_apiError != null) ...[
            _ErrorBanner(message: _apiError!),
            const SizedBox(height: 16),
          ],

          // ── Full Name ────────────────────────────────────────────────────
          _FieldLabel(label: 'Full Name', required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _nameCtrl, focusNode: _nameFocus,
            hintText: 'e.g. Ravi Kumar',
            prefixIcon: const Icon(Icons.person_outline),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: _valName,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 14),

          // ── Email ────────────────────────────────────────────────────────
          _FieldLabel(label: 'Email Address', required: false),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _emailCtrl, focusNode: _emailFocus,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: _valEmail,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 8),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: GlassColors.accentGreen.withOpacity(0.06),
            borderColor: GlassColors.accentGreenBorder.withOpacity(0.4),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 13, color: GlassColors.accentGreenLight),
              SizedBox(width: 6),
              Expanded(child: Text(
                'Provide email or phone (or both). OTP will be sent to your contact.',
                style: TextStyle(fontSize: 11, color: GlassColors.textTertiary, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Phone ────────────────────────────────────────────────────────
          _FieldLabel(label: 'Phone Number', required: false),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _phoneCtrl, focusNode: _phoneFocus,
            hintText: '+91 98765 43210 (optional)',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.phone_outlined),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]'))],
            validator: _valPhone,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 14),

          // ── Password ─────────────────────────────────────────────────────
          _FieldLabel(label: 'Password', required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _passCtrl, focusNode: _passFocus,
            hintText: 'Min 6 chars, letters + numbers',
            obscureText: _obscurePass,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: GlassColors.textTertiary, size: 18),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            validator: _valPass,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          if (_passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _StrengthMeter(strength: _passStrength, color: _strengthColor, label: _strengthLabel),
          ],
          const SizedBox(height: 14),

          // ── Confirm Password ─────────────────────────────────────────────
          _FieldLabel(label: 'Confirm Password', required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _confirmCtrl, focusNode: _confirmFocus,
            hintText: 'Re-enter your password',
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: GlassColors.textTertiary, size: 18),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: _valConfirm,
            onChanged: (_) { if (_submitted) setState(() {}); },
            onFieldSubmitted: (_) => _sendOtpAndProceed(),
          ),
          const SizedBox(height: 20),

          // ── Role ─────────────────────────────────────────────────────────
          const _FieldLabel(label: 'Register as', required: true),
          const SizedBox(height: 10),
          Row(children: [
            _RoleChip(label: 'Reader',   value: 'user',     icon: Icons.person_outline,
                selected: _role, onTap: (v) => setState(() => _role = v)),
            const SizedBox(width: 10),
            _RoleChip(label: 'Reporter', value: 'reporter', icon: Icons.mic_none,
                selected: _role, onTap: (v) => setState(() => _role = v)),
          ]),
          const SizedBox(height: 10),
          GlassContainer(
            padding: const EdgeInsets.all(12),
            borderColor: GlassColors.accentGreenBorder,
            color: GlassColors.accentGreenSurface,
            child: Text(
              _role == 'reporter'
                  ? '📸  Reporters can submit news stories with photos, videos, and GPS location tagging. Subject to admin review before publishing.'
                  : '📰  Readers can browse the news feed, like and bookmark stories, and comment.',
              style: const TextStyle(fontSize: 12, color: GlassColors.accentGreenLight, height: 1.5),
            ),
          ),

          // Requirements checklist
          if (_passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RequirementsChecklist(password: _passCtrl.text),
          ],

          const SizedBox(height: 28),

          GlassButton(
            label: 'Send Verification Code',
            icon: Icons.send_rounded,
            onPressed: _sendOtpAndProceed,
            loading: _sending,
          ),
          const SizedBox(height: 20),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account? ',
                style: TextStyle(color: GlassColors.textTertiary, fontSize: 14)),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: const Text('Sign In',
                  style: TextStyle(color: GlassColors.accentGreenLight,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
        ],
      ),
    );
  }

  // ── OTP Verify (Step 2) ──────────────────────────────────────────────────────

  Widget _buildOtp({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 36),

        GestureDetector(
          onTap: () => setState(() { _step = 0; _otpError = null; _enteredOtp = ''; }),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: GlassColors.textTertiary),
            SizedBox(width: 6),
            Text('Edit details', style: TextStyle(color: GlassColors.textTertiary, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 32),

        Center(child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _channel == 'phone' ? GlassColors.accentPurple : GlassColors.accentGreen,
              _channel == 'phone' ? const Color(0xFF534AB7) : const Color(0xFF0F6E56),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            _channel == 'phone' ? Icons.phone_android : Icons.mark_email_read_outlined,
            color: Colors.white, size: 30,
          ),
        )),
        const SizedBox(height: 20),

        const Center(child: Text('Verify your account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: GlassColors.textPrimary))),
        const SizedBox(height: 10),

        Center(child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: GlassColors.textTertiary, height: 1.5),
            children: [
              TextSpan(text: 'We sent a 6-digit code to your $_channel\n'),
              TextSpan(text: _maskedTarget,
                  style: const TextStyle(color: GlassColors.accentGreenLight, fontWeight: FontWeight.w700)),
            ],
          ),
        )),
        const SizedBox(height: 36),

        GlassOtpInput(
          onCompleted: _verifyOtp,
          onChanged: (v) => setState(() => _enteredOtp = v),
        ),
        const SizedBox(height: 16),

        if (_otpError != null)
          Center(child: Text(_otpError!,
              style: TextStyle(color: GlassColors.error, fontSize: 13),
              textAlign: TextAlign.center)),

        if (_verifying)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: SizedBox(height: 24, width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: GlassColors.accentGreenLight))),
          ),

        const SizedBox(height: 24),

        if (_enteredOtp.length == 6 && !_verifying)
          GlassButton(
            label: 'Create Account',
            icon: Icons.person_add_rounded,
            onPressed: () => _verifyOtp(_enteredOtp),
            loading: _verifying,
          ),

        const SizedBox(height: 28),

        Center(child: ResendOtpButton(onResend: _resendOtp)),
        const SizedBox(height: 8),
        const Center(child: Text('Code expires in 10 minutes',
            style: TextStyle(fontSize: 12, color: GlassColors.textHint))),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StrengthMeter extends StatelessWidget {
  final int strength;
  final Color color;
  final String label;
  const _StrengthMeter({required this.strength, required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Row(
        children: List.generate(4, (i) => Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 4,
          margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
          decoration: BoxDecoration(
            color: i < strength ? color : GlassColors.surfaceBright,
            borderRadius: BorderRadius.circular(4),
          ),
        ))),
      )),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}

class _RequirementsChecklist extends StatelessWidget {
  final String password;
  const _RequirementsChecklist({required this.password});
  static const _reqs = [
    ('At least 6 characters',              r'.{6,}'),
    ('Contains a letter',                  r'[A-Za-z]'),
    ('Contains a number',                  r'[0-9]'),
    ('Uppercase letter (bonus)',            r'[A-Z]'),
    ('Special character (bonus)',           r'[!@#\$%^&*]'),
  ];
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Password requirements',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: GlassColors.textTertiary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ..._reqs.map((r) {
          final met = RegExp(r.$2).hasMatch(password);
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: met ? GlassColors.accentGreen.withOpacity(0.2) : GlassColors.surfaceBright,
                  border: Border.all(color: met ? GlassColors.accentGreenBorder : GlassColors.borderWhite, width: 0.8),
                ),
                child: met ? const Icon(Icons.check, size: 10, color: GlassColors.accentGreenLight) : null,
              ),
              const SizedBox(width: 8),
              Text(r.$1, style: TextStyle(fontSize: 12,
                  color: met ? GlassColors.accentGreenLight : GlassColors.textHint)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label, value, selected;
  final IconData icon;
  final void Function(String) onTap;
  const _RoleChip({required this.label, required this.value, required this.selected, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isSel = value == selected;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isSel ? GlassColors.accentGreenSurface : GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? GlassColors.accentGreenBorder : GlassColors.borderWhite, width: isSel ? 1.0 : 0.8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: isSel ? GlassColors.accentGreenLight : GlassColors.textSecondary),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
              color: isSel ? GlassColors.accentGreenLight : GlassColors.textSecondary)),
        ]),
      ),
    ));
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassColors.textSecondary)),
      if (required) ...[const SizedBox(width: 3), const Text('*', style: TextStyle(color: GlassColors.accentOrangeLight, fontSize: 13))],
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
        Expanded(child: Text(message, style: const TextStyle(color: GlassColors.accentOrangeLight, fontSize: 13, height: 1.4))),
      ]),
    );
  }
}