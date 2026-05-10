import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../onboarding/onboarding_design.dart';
import 'widgets/auth_otp_input.dart';

/// Step 2 of the mobile login flow: collect a 6-digit OTP and verify it.
class OtpVerifyScreen extends StatefulWidget {
  /// Either a phone number (`+91…`) or an email address.
  final String target;

  const OtpVerifyScreen({super.key, required this.target});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpKey = GlobalKey<AuthOtpInputState>();
  String _code = '';
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  static const _resendCooldown = 30;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  bool get _isPhone => widget.target.startsWith('+');

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _maskedTarget() {
    final t = widget.target;
    if (_isPhone) {
      if (t.length <= 4) return t;
      final last = t.substring(t.length - 4);
      final cc = t.startsWith('+91') ? '+91 ' : '';
      return '$cc•••••• $last';
    }
    final at = t.indexOf('@');
    if (at <= 1) return t;
    final visible = t.substring(0, 1);
    return '$visible•••${t.substring(at)}';
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await ApiService.verifyLoginOtp(
        target: widget.target,
        code: _code,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final auth = context.read<AuthProvider>();
        await auth.loginWithToken(res['token'], res['user']);
        if (!mounted) return;
        context.go(auth.homeRoute);
      } else {
        setState(() {
          _error = (res['message'] as String?) ?? 'Invalid or expired OTP.';
          _otpKey.currentState?.clear();
          _code = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final res =
          await ApiService.sendOtp(target: widget.target, purpose: 'login');
      if (!mounted) return;
      if (res['success'] == true) {
        _otpKey.currentState?.clear();
        _code = '';
        setState(() => _info = 'A new OTP has been sent.');
        _startCooldown();
      } else {
        setState(() => _error =
            (res['message'] as String?) ?? 'Could not resend OTP. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _code.length == 6 && !_verifying;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: OnboardingDesign.background,
      appBar: AppBar(
        backgroundColor: OnboardingDesign.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: OnboardingDesign.titleColor, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Verify your number',
                          style: OnboardingDesign.titleStyle(),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: OnboardingDesign.subtitleStyle(),
                            children: [
                              const TextSpan(
                                  text: 'Enter the 6-digit OTP sent to '),
                              TextSpan(
                                text: _maskedTarget(),
                                style: GoogleFonts.notoSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: OnboardingDesign.titleColor,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        AuthOtpInput(
                          key: _otpKey,
                          length: 6,
                          onChanged: (v) {
                            setState(() {
                              _code = v;
                              if (_error != null) _error = null;
                            });
                          },
                          onCompleted: (_) => _verify(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _StatusBanner(
                            message: _error!,
                            isError: true,
                          ),
                        ],
                        if (_info != null) ...[
                          const SizedBox(height: 14),
                          _StatusBanner(
                            message: _info!,
                            isError: false,
                          ),
                        ],
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't get the code? ",
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                color: OnboardingDesign.subtitleColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: _secondsLeft == 0 ? _resend : null,
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                _resending
                                    ? 'Resending…'
                                    : _secondsLeft > 0
                                        ? 'Resend in ${_secondsLeft}s'
                                        : 'Resend OTP',
                                style: GoogleFonts.notoSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _secondsLeft == 0
                                      ? OnboardingDesign.accent
                                      : OnboardingDesign.subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: canVerify ? _verify : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: OnboardingDesign.accent,
                        disabledBackgroundColor:
                            OnboardingDesign.accent.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              OnboardingDesign.radiusButton),
                        ),
                        elevation: 0,
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text('Verify OTP',
                              style: OnboardingDesign.buttonLabel()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final border =
        isError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
    final iconColor =
        isError ? Colors.red.shade600 : OnboardingDesign.accentDark;
    final textColor =
        isError ? Colors.red.shade700 : OnboardingDesign.accentDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: textColor,
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
