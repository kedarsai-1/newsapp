import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_draft_provider.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingInterestsScreen extends StatelessWidget {
  const OnboardingInterestsScreen({super.key});

  static const _items = <({String slug, String label})>[
    (slug: 'politics', label: 'Politics'),
    (slug: 'sports', label: 'Sports'),
    (slug: 'entertainment', label: 'Entertainment'),
    (slug: 'technology', label: 'Technology'),
    (slug: 'business', label: 'Business'),
    (slug: 'health', label: 'Health'),
    (slug: 'education', label: 'Education'),
    (slug: 'local', label: 'Local News'),
  ];

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingDraftProvider>();

    return OnboardingStepShell(
      title: 'Choose your interests',
      subtitle: 'Personalize your news feed',
      primaryLabel: 'Continue',
      primaryEnabled: draft.interestSlugs.isNotEmpty,
      onPrimary: () => context.go('/onboarding/location'),
      body: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _items.map((item) {
          final selected = draft.interestSlugs.contains(item.slug);
          return FilterChip(
            label: Text(item.label),
            selected: selected,
            showCheckmark: false,
            selectedColor: OnboardingDesign.accent(context).withValues(alpha: 0.14),
            backgroundColor: OnboardingDesign.tileBackground(context),
            side: BorderSide(
              color:
                  selected ? OnboardingDesign.accent(context) : OnboardingDesign.outline(context),
              width: selected ? 1.6 : 1,
            ),
            labelStyle: OnboardingDesign.languageNative(context).copyWith(
              fontSize: 14,
              color: selected
                  ? OnboardingDesign.accentDark(context)
                  : OnboardingDesign.titleColor(context),
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => context
                .read<OnboardingDraftProvider>()
                .toggleInterest(item.slug),
          );
        }).toList(),
      ),
    );
  }
}
