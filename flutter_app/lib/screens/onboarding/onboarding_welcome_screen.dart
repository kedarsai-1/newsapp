import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../providers/onboarding_draft_provider.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final draft = context.read<OnboardingDraftProvider>();
    final news = context.read<NewsProvider>();
    await news.completeFullOnboarding(
      uiLanguageCode: draft.languageCode,
      interestSlugs: draft.interestSlugs.toList(),
      cityLabel: draft.cityLabel,
      latitude: draft.latitude,
      longitude: draft.longitude,
      notificationsEnabled: draft.notificationsRequested,
    );
    if (!context.mounted) return;
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: OnboardingDesign.background(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your news feed is ready',
                style: OnboardingDesign.titleStyle(context),
              ),
              const SizedBox(height: 10),
              Text(
                'Swipe through the latest updates',
                style: OnboardingDesign.subtitleStyle(context),
              ),
              const Spacer(),
              Center(
                child: Icon(
                  Icons.dynamic_feed_rounded,
                  size: 88,
                  color: OnboardingDesign.accent(context).withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              OnboardingPrimaryButton(
                label: 'Start reading',
                onPressed: () => _start(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
