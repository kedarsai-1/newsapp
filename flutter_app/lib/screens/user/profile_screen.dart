import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/premium_news_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _translatedCacheKey = 'feed_translated_summary_cache_v1';
  final Set<String> _interests = {
    'Politics',
    'Sports',
    'Technology',
  };
  bool _breakingAlerts = true;
  bool _dailyDigest = true;
  bool _recommendedAlerts = false;

  static const _languages = [
    ('te', 'Telugu'),
    ('hi', 'Hindi'),
    ('en', 'English'),
    ('all', 'All'),
  ];

  static const _allInterests = [
    'Politics',
    'Sports',
    'Technology',
    'Business',
    'Entertainment',
    'Health',
    'Local',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user;
    final news = context.watch<NewsProvider>();
    if (user == null) {
      return PremiumScaffold(
        safeArea: true,
        child: Center(
          child: FrostedPanel(
            radius: 22,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.profile, size: 52, color: p.textHint),
                const SizedBox(height: 10),
                Text(
                  'Sign in to access profile and settings',
                  style: TextStyle(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                GradientPillButton(
                  label: 'Sign in',
                  icon: AppIcons.login,
                  onPressed: () => context.push('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PremiumScaffold(
      safeArea: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          24 + MediaQuery.of(context).padding.bottom + 84,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile & Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                ),
              ),
              PremiumIconButton(
                icon: AppIcons.privacy,
                onTap: () => context.push('/privacy-policy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FrostedPanel(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: p.primary,
                  child: Text(
                    AppUtils.initials(user.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: context.titleText.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: context.subtitleText.copyWith(color: p.textHint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'Language',
            child: DropdownButtonFormField<String>(
              initialValue: news.selectedLanguage,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: p.surface,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _languages
                  .map(
                    (l) => DropdownMenuItem<String>(
                      value: l.$1,
                      child: Text(l.$2),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) news.selectLanguage(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              final isDark = theme.themeMode == ThemeMode.dark;
              return _SettingsCard(
                title: 'Theme',
                child: SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: context.subtitleText.copyWith(color: p.textPrimary),
                  ),
                  value: isDark,
                  onChanged: (value) => theme.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            title: 'Interests',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((interest) {
                final selected = _interests.contains(interest);
                return FilterChip(
                  selected: selected,
                  label: Text(interest),
                  selectedColor: p.primary.withValues(alpha: 0.2),
                  backgroundColor: p.surface.withValues(alpha: 0.54),
                  side: BorderSide(color: selected ? p.primary : p.cardBorder),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected ? p.primary : p.textSecondary,
                    fontWeight: FontWeight.w700,
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
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Breaking News Alerts'),
                  value: _breakingAlerts,
                  onChanged: (v) => setState(() => _breakingAlerts = v),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily Digest'),
                  value: _dailyDigest,
                  onChanged: (v) => setState(() => _dailyDigest = v),
                ),
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recommended Stories'),
                  value: _recommendedAlerts,
                  onChanged: (v) => setState(() => _recommendedAlerts = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            title: 'Storage',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cleaning_services_rounded, color: p.primary),
              title: Text(
                'Clear translated stories cache',
                style: context.subtitleText.copyWith(color: p.textPrimary),
              ),
              subtitle: Text(
                'Removes saved translated text from local device storage.',
                style: context.metaText.copyWith(color: p.textHint),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: p.textHint),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_translatedCacheKey);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Translated cache cleared'),
                    duration: Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GradientPillButton(
            label: 'Sign out',
            icon: AppIcons.logout,
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FrostedPanel(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.metaText.copyWith(
              color: p.textHint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
