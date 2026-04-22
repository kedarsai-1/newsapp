import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';

/// Shown once on first launch (or until the user picks a language).
class SelectLanguageScreen extends StatelessWidget {
  const SelectLanguageScreen({super.key});

  static const _options = <({String code, String label, String subtitle})>[
    (code: 'en', label: 'English', subtitle: 'News in English'),
    (code: 'te', label: 'తెలుగు', subtitle: 'Telugu'),
    (code: 'hi', label: 'हिन्दी', subtitle: 'Hindi'),
    (code: 'all', label: 'All languages', subtitle: 'No language filter'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: t.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your language',
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(
                  color: p.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We’ll show stories that match your choice. You can change this later in the feed.',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: p.textHint, height: 1.4),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final o = _options[i];
                    return Material(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final news = context.read<NewsProvider>();
                          final auth = context.read<AuthProvider>();
                          await news.completeLanguageOnboarding(o.code);
                          if (context.mounted) {
                            context.go(auth.homeRoute);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.label,
                                      style: t.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      o.subtitle,
                                      style: t.bodySmall?.copyWith(
                                        color: p.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: p.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
