import 'package:flutter/material.dart';

import '../onboarding_design.dart';

/// White scaffold + scroll area + sticky bottom primary action for onboarding steps.
class OnboardingStepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;

  const OnboardingStepShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: OnboardingDesign.background(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text(title, style: OnboardingDesign.titleStyle(context)),
                    const SizedBox(height: 10),
                    Text(subtitle, style: OnboardingDesign.subtitleStyle(context)),
                    const SizedBox(height: 28),
                    body,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: OnboardingPrimaryButton(
                label: primaryLabel,
                onPressed: primaryEnabled ? onPrimary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: OnboardingDesign.accent(context),
        foregroundColor: Colors.white,
        disabledBackgroundColor: OnboardingDesign.outline(context),
        disabledForegroundColor: OnboardingDesign.subtitleColor(context),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnboardingDesign.radiusButton),
        ),
        elevation: 0,
      ),
      child: Text(label, style: OnboardingDesign.buttonLabel(context)),
    );
  }
}

class OnboardingSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const OnboardingSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: OnboardingDesign.subtitleColor(context),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        label,
        style: OnboardingDesign.buttonLabel(context).copyWith(
          fontWeight: FontWeight.w600,
          color: OnboardingDesign.subtitleColor(context),
        ),
      ),
    );
  }
}
