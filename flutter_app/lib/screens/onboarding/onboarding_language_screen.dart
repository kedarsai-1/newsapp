import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_draft_provider.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingLanguageScreen extends StatelessWidget {
  const OnboardingLanguageScreen({super.key});

  static const _languages = <({String code, String native, String english})>[
    (code: 'en', native: 'English', english: 'English'),
    (code: 'te', native: 'తెలుగు', english: 'Telugu'),
    (code: 'hi', native: 'हिन्दी', english: 'Hindi'),
    (code: 'ta', native: 'தமிழ்', english: 'Tamil'),
    (code: 'kn', native: 'ಕನ್ನಡ', english: 'Kannada'),
    (code: 'ml', native: 'മലയാളം', english: 'Malayalam'),
  ];

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingDraftProvider>();
    final w = MediaQuery.sizeOf(context).width;
    final crossAxisCount = w >= 520 ? 3 : 2;
    const spacing = 12.0;

    return OnboardingStepShell(
      title: 'Choose your language',
      subtitle: 'Get news in your preferred language',
      primaryLabel: 'Continue',
      onPrimary: () => context.go('/onboarding/interests'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tileW =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _languages.map((l) {
              final selected = draft.languageCode == l.code;
              return SizedBox(
                width: tileW,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context
                        .read<OnboardingDraftProvider>()
                        .setLanguage(l.code),
                    borderRadius:
                        BorderRadius.circular(OnboardingDesign.radiusCard),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? OnboardingDesign.accent.withValues(alpha: 0.1)
                            : const Color(0xFFF9FAFB),
                        borderRadius:
                            BorderRadius.circular(OnboardingDesign.radiusCard),
                        border: Border.all(
                          color: selected
                              ? OnboardingDesign.accent
                              : OnboardingDesign.outline,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.native,
                              style: OnboardingDesign.languageNative()),
                          const SizedBox(height: 4),
                          Text(l.english, style: OnboardingDesign.languageEn()),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
