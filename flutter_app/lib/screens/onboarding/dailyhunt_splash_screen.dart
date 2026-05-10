import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_draft_provider.dart';
import '../../services/auth_provider.dart';
import 'onboarding_design.dart';

/// Brief branded splash: white background, fade-in logo, tagline, subtle loader.
class DailyhuntSplashScreen extends StatefulWidget {
  const DailyhuntSplashScreen({super.key});

  @override
  State<DailyhuntSplashScreen> createState() => _DailyhuntSplashScreenState();
}

class _DailyhuntSplashScreenState extends State<DailyhuntSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _ac.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNext());
  }

  Future<void> _routeNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final news = context.read<NewsProvider>();

    if (auth.isLoggedIn && (auth.isAdmin || auth.isReporter)) {
      context.go(auth.homeRoute);
      return;
    }

    if (!news.languageOnboardingCompleted) {
      context.read<OnboardingDraftProvider>().reset();
      context.go('/onboarding/language');
      return;
    }

    context.go('/feed');
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: OnboardingDesign.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color:
                                OnboardingDesign.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.article_rounded,
                            size: 42,
                            color: OnboardingDesign.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: OnboardingDesign.titleStyle()
                              .copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'News in your language',
                          textAlign: TextAlign.center,
                          style: OnboardingDesign.subtitleStyle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: OnboardingDesign.accent.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
