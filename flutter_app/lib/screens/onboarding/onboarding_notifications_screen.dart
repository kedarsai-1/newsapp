import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_draft_provider.dart';
import '../../services/push_notifications.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingNotificationsScreen extends StatelessWidget {
  const OnboardingNotificationsScreen({super.key});

  Future<void> _enable(BuildContext context) async {
    final draft = context.read<OnboardingDraftProvider>();
    await PushNotifications.enableForGuest();
    draft.setNotificationsRequested(true);
    if (!context.mounted) return;
    context.go('/onboarding/welcome');
  }

  void _later(BuildContext context) {
    context.read<OnboardingDraftProvider>().setNotificationsRequested(false);
    context.go('/onboarding/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: OnboardingDesign.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Stay updated', style: OnboardingDesign.titleStyle(context)),
              const SizedBox(height: 10),
              Text(
                'Enable notifications for breaking news',
                style: OnboardingDesign.subtitleStyle(context),
              ),
              const Spacer(),
              Center(
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 96,
                  color: OnboardingDesign.accent(context).withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              OnboardingPrimaryButton(
                label: 'Enable notifications',
                onPressed: () => _enable(context),
              ),
              const SizedBox(height: 6),
              OnboardingSecondaryButton(
                label: 'Maybe later',
                onPressed: () => _later(context),
              ),
              SizedBox(height: bottom),
            ],
          ),
        ),
      ),
    );
  }
}
