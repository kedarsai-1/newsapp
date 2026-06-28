import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../onboarding/onboarding_design.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

/// Rounded, lightweight Material 3 input matching the Dailyhunt-style auth flow.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingDesign.radiusCard),
      borderSide: BorderSide(color: OnboardingDesign.outline(context)),
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: GoogleFonts.notoSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: OnboardingDesign.titleColor(context),
      ),
      cursorColor: OnboardingDesign.accent(context),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.notoSans(
          fontSize: 14.5,
          color: OnboardingDesign.subtitleColor(context),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: OnboardingDesign.surface(context),
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: OnboardingDesign.accent(context),
            width: 1.6,
          ),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: fx.error, width: 1.4),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: fx.error, width: 1.6),
        ),
        errorStyle: GoogleFonts.notoSans(
          fontSize: 12,
          color: fx.onErrorSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
