import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import '../../utils/i18n.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
  bool _loading         = false;

  final Set<String> _touched = {};
  int _passStrength = 0;

  String? _apiError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Allow deep-linking like /register?role=reporter
      final role = GoRouterState.of(context).uri.queryParameters['role']?.trim().toLowerCase();
      if (role == 'reporter' || role == 'user') {
        setState(() => _role = role!);
      }
    });
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
    if (val.isEmpty) return I18n.t(context, 'err_name_required');
    if (val.length < 2) return I18n.t(context, 'err_name_min');
    if (val.length > 60) return I18n.t(context, 'err_name_max');
    // Allow unicode letters for names (Hindi/Telugu), plus spaces and a few punctuation chars.
    if (!RegExp(r"^[\p{L}\p{M}\s'\-\.]+$", unicode: true).hasMatch(val)) {
      return I18n.t(context, 'err_name_invalid');
    }
    return null;
  }

  bool _isValidEmail(String v) {
    final val = v.trim();
    if (val.isEmpty) return false;
    if (val.length > 254) return false;
    // No spaces; basic RFC-like structure.
    if (val.contains(' ')) return false;
    return RegExp(r'^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$', caseSensitive: false)
        .hasMatch(val);
  }

  bool _isValidPhone(String v) {
    final raw = v.trim();
    if (raw.isEmpty) return false;
    // Allow +, digits, spaces, hyphens, parentheses
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(raw)) return false;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) return false;

    // Harden India mobile numbers: if looks like Indian number, require 10 digits starting 6-9.
    // Accept formats like 9876543210 or +91 9876543210.
    if (digits.length == 10) {
      return RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return RegExp(r'^91[6-9]\d{9}$').hasMatch(digits);
    }
    // Otherwise treat as international E.164-ish length check already done.
    return true;
  }

  String? _valEmail(String? v) {
    if (!_isTouched('email')) return null;
    final val = v?.trim() ?? '';
    // Email is optional only if phone is provided
    if (val.isEmpty && _phoneCtrl.text.trim().isNotEmpty) return null;
    if (val.isEmpty) return I18n.t(context, 'err_target_required');
    if (!_isValidEmail(val)) return I18n.t(context, 'err_email_invalid');
    return null;
  }

  String? _valPhone(String? v) {
    if (!_isTouched('phone')) return null;
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null; // optional if email given
    if (!_isValidPhone(val)) return I18n.t(context, 'err_phone_invalid');
    return null;
  }

  String? _valPass(String? v) {
    if (!_isTouched('pass')) return null;
    final val = v ?? '';
    if (val.isEmpty) return I18n.t(context, 'err_password_required');
    if (val.length < 6) return I18n.t(context, 'err_password_min');
    if (!RegExp(r'[A-Za-z]').hasMatch(val)) return I18n.t(context, 'err_password_letter');
    if (!RegExp(r'[0-9]').hasMatch(val)) return I18n.t(context, 'err_password_number');
    return null;
  }

  String? _valConfirm(String? v) {
    if (!_isTouched('confirm')) return null;
    if ((v ?? '').isEmpty) return I18n.t(context, 'err_confirm_required');
    if (v != _passCtrl.text) return I18n.t(context, 'err_confirm_mismatch');
    return null;
  }

  Future<void> _register() async {
    setState(() {
      _submitted = true;
      _touched.addAll(['name', 'email', 'phone', 'pass', 'confirm']);
    });
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    // Keep current backend contract: email is required for registration.
    if (email.isEmpty) {
      setState(() => _apiError = I18n.t(context, 'err_reg_email_required'));
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _apiError = I18n.t(context, 'err_email_invalid'));
      return;
    }
    if (phone.isNotEmpty && !_isValidPhone(phone)) {
      setState(() => _apiError = I18n.t(context, 'err_phone_invalid'));
      return;
    }

    setState(() { _loading = true; _apiError = null; });
    try {
      final res = await ApiService.register(
        name: _nameCtrl.text.trim(),
        email: email,
        password: _passCtrl.text,
        role: _role,
        phone: phone.isEmpty ? null : phone,
      );
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (mounted) context.go(auth.homeRoute);
      } else {
        setState(() => _apiError = res['message'] ?? 'Registration failed.');
      }
    } catch (_) {
      setState(() => _apiError = I18n.t(context, 'err_connection'));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        appBar: GlassAppBar(title: const SizedBox.shrink(), showBack: true),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: _buildForm(key: const ValueKey('form')),
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
          Text(I18n.t(context, 'reg_title'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                  color: GlassColors.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(I18n.t(context, 'reg_subtitle'),
              style: const TextStyle(fontSize: 14, color: GlassColors.textTertiary)),
          const SizedBox(height: 24),

          if (_apiError != null) ...[
            _ErrorBanner(message: _apiError!),
            const SizedBox(height: 16),
          ],

          // ── Full Name ────────────────────────────────────────────────────
          _FieldLabel(label: I18n.t(context, 'field_full_name'), required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _nameCtrl, focusNode: _nameFocus,
            hintText: I18n.t(context, 'hint_full_name'),
            prefixIcon: const Icon(Icons.person_outline),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: _valName,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 14),

          // ── Email ────────────────────────────────────────────────────────
          _FieldLabel(label: I18n.t(context, 'field_email'), required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _emailCtrl, focusNode: _emailFocus,
            hintText: I18n.t(context, 'hint_email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: _valEmail,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 14),

          // ── Phone ────────────────────────────────────────────────────────
          _FieldLabel(label: I18n.t(context, 'field_phone'), required: false),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _phoneCtrl, focusNode: _phoneFocus,
            hintText: I18n.t(context, 'hint_phone_optional'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.phone_outlined),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]'))],
            validator: _valPhone,
            onChanged: (_) { if (_submitted) setState(() {}); },
          ),
          const SizedBox(height: 14),

          // ── Password ─────────────────────────────────────────────────────
          _FieldLabel(label: I18n.t(context, 'field_password'), required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _passCtrl, focusNode: _passFocus,
            hintText: I18n.t(context, 'hint_password'),
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
          _FieldLabel(label: I18n.t(context, 'field_confirm_password'), required: true),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _confirmCtrl, focusNode: _confirmFocus,
            hintText: I18n.t(context, 'hint_confirm_password'),
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
            onFieldSubmitted: (_) => _register(),
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
            label: I18n.t(context, 'action_create_account'),
            icon: Icons.person_add_rounded,
            onPressed: _register,
            loading: _loading,
          ),
          const SizedBox(height: 20),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(I18n.t(context, 'reg_have_account'),
                style: const TextStyle(color: GlassColors.textTertiary, fontSize: 14)),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(I18n.t(context, 'action_signin'),
                  style: const TextStyle(color: GlassColors.accentGreenLight,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
        ],
      ),
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