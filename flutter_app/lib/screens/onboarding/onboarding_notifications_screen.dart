import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_draft_provider.dart';
import 'onboarding_design.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingNotificationsScreen extends StatelessWidget {
  const OnboardingNotificationsScreen({super.key});

  Future<void> _enable(BuildContext context) async {
    final draft = context.read<OnboardingDraftProvider>();
    var granted = false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      granted = false;
    }
    draft.setNotificationsRequested(granted);
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
      backgroundColor: OnboardingDesign.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Stay updated', style: OnboardingDesign.titleStyle()),
              const SizedBox(height: 10),
              Text(
                'Enable notifications for breaking news',
                style: OnboardingDesign.subtitleStyle(),
              ),
              const Spacer(),
              Center(
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 96,
                  color: OnboardingDesign.accent.withValues(alpha: 0.85),
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
