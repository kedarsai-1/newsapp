import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/premium_news_ui.dart';

/// Shown once on first launch (or until the user picks a language).
class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() => _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends State<SelectLanguageScreen> {
  String _language = 'te';
  final Set<String> _interests = {'Local', 'Politics', 'Technology'};

  static const _options = <({String code, String label, String subtitle})>[
    (code: 'en', label: 'English', subtitle: 'News in English'),
    (code: 'te', label: 'తెలుగు', subtitle: 'Telugu'),
    (code: 'hi', label: 'हिन्दी', subtitle: 'Hindi'),
    (code: 'all', label: 'All languages', subtitle: 'No language filter'),
  ];

  static const _interestOptions = [
    'Local',
    'Politics',
    'Business',
    'Sports',
    'Technology',
    'Entertainment',
    'Health',
    'AI Briefs',
  ];

  Future<void> _continue() async {
    final news = context.read<NewsProvider>();
    final auth = context.read<AuthProvider>();
    await news.completeLanguageOnboarding(_language);
    if (!mounted) return;
    context.go(auth.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return PremiumScaffold(
      safeArea: true,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              FrostedPanel(
                radius: 28,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.primary, p.accentPurple],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.black, size: 28),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Personalize ${AppConstants.appName}',
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose your language and interests so the AI feed feels regional, fast, and useful from the first swipe.',
                      style: t.bodyMedium?.copyWith(
                        color: p.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Language',
                style: t.titleMedium?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ..._options.map((o) {
                final selected = _language == o.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FrostedPanel(
                    radius: 18,
                    padding: EdgeInsets.zero,
                    color: selected
                        ? p.primary.withValues(alpha: 0.16)
                        : p.surface.withValues(alpha: 0.48),
                    boxShadow: const [],
                    child: RadioListTile<String>(
                      value: o.code,
                      groupValue: _language,
                      activeColor: p.primary,
                      onChanged: (v) => setState(() => _language = v ?? 'all'),
                      title: Text(
                        o.label,
                        style: t.titleSmall?.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        o.subtitle,
                        style: t.bodySmall?.copyWith(color: p.textHint),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              Text(
                'Interests',
                style: t.titleMedium?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _interestOptions.map((interest) {
                  final selected = _interests.contains(interest);
                  return FilterChip(
                    selected: selected,
                    label: Text(interest),
                    avatar: selected
                        ? Icon(Icons.check_rounded, size: 16, color: p.primary)
                        : null,
                    showCheckmark: false,
                    selectedColor: p.primary.withValues(alpha: 0.18),
                    backgroundColor: p.surface.withValues(alpha: 0.62),
                    side: BorderSide(
                      color: selected
                          ? p.primary.withValues(alpha: 0.7)
                          : p.cardBorder,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? p.primary : p.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _interests.remove(interest);
                        } else {
                          _interests.add(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              GradientPillButton(
                label: 'Start reading',
                icon: Icons.swipe_vertical_rounded,
                onPressed: _continue,
              ),
              const SizedBox(height: 14),
              Text(
                'You can update language and filters anytime from the feed.',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: p.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
