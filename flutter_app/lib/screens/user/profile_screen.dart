import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/news_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/dailyhunt_theme.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';
import '../../widgets/profile/dailyhunt_settings_section.dart';

/// Dailyhunt-style profile & settings: light cards, green accent, Material 3.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _translatedCacheKey = 'feed_translated_summary_cache_v1';

  final Set<String> _interests = {
    'politics',
    'sports',
    'technology',
  };
  bool _breakingAlerts = true;
  bool _dailyDigest = true;
  bool _recommendedAlerts = false;

  static const _languageCodes = ['te', 'hi', 'en', 'all'];

  String _languageLabel(BuildContext context, String code) {
    switch (code) {
      case 'te':
        return I18n.t(context, 'lang_telugu');
      case 'hi':
        return I18n.t(context, 'lang_hindi');
      case 'en':
        return I18n.t(context, 'lang_english');
      case 'all':
      default:
        return I18n.t(context, 'lang_all');
    }
  }

  static const _interestSlugs = [
    'politics',
    'sports',
    'technology',
    'business',
    'entertainment',
    'health',
    'local',
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final news = context.watch<NewsProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 720 ? 20.0 : 14.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;

    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 52,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  title: Text(
                    I18n.t(context, 'profile_title'),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: I18n.t(context, 'profile_privacy_tooltip'),
                      onPressed: () => context.push('/privacy-policy'),
                      icon: Icon(
                        Icons.policy_outlined,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, bottomInset),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (user == null) ...[
                        _GuestHeader(colorScheme: cs),
                        const SizedBox(height: 12),
                      ] else ...[
                        _UserHeaderCard(userName: user.name, userEmail: user.email),
                        const SizedBox(height: 12),
                      ],
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_language'),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String>(news.selectedLanguage),
                          initialValue: news.selectedLanguage,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF6F7F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          items: _languageCodes
                              .map(
                                (code) => DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(_languageLabel(context, code)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) news.selectLanguage(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_appearance'),
                        child: SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text(I18n.t(context, 'appearance_light')),
                              icon: const Icon(Icons.light_mode_outlined, size: 18),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text(I18n.t(context, 'appearance_dark')),
                              icon: const Icon(Icons.dark_mode_outlined, size: 18),
                            ),
                          ],
                          selected: {
                            themeProv.themeMode == ThemeMode.dark
                                ? ThemeMode.dark
                                : ThemeMode.light,
                          },
                          onSelectionChanged: (s) {
                            themeProv.setThemeMode(s.first);
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: DailyhuntTheme.accentGreen
                                .withValues(alpha: 0.18),
                            selectedForegroundColor: DailyhuntTheme.accentGreen,
                            foregroundColor: cs.onSurface,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_interests'),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _interestSlugs.map((slug) {
                            final selected = _interests.contains(slug);
                            return FilterChip(
                              label: Text(
                                I18n.t(context, 'cat_$slug'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: selected ? Colors.white : const Color(0xFF374151),
                                ),
                              ),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  if (selected) {
                                    _interests.remove(slug);
                                  } else {
                                    _interests.add(slug);
                                  }
                                });
                              },
                              showCheckmark: false,
                              selectedColor: DailyhuntTheme.accentGreen,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected
                                    ? DailyhuntTheme.accentGreen
                                    : const Color(0xFFE5E7EB),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_notifications'),
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(I18n.t(context, 'notif_breaking')),
                              value: _breakingAlerts,
                              activeThumbColor: DailyhuntTheme.accentGreen,
                              onChanged: (v) => setState(() => _breakingAlerts = v),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(I18n.t(context, 'notif_daily_digest')),
                              value: _dailyDigest,
                              activeThumbColor: DailyhuntTheme.accentGreen,
                              onChanged: (v) => setState(() => _dailyDigest = v),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(I18n.t(context, 'notif_recommended')),
                              value: _recommendedAlerts,
                              activeThumbColor: DailyhuntTheme.accentGreen,
                              onChanged: (v) =>
                                  setState(() => _recommendedAlerts = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_library'),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.bookmark_outline_rounded,
                            color: DailyhuntTheme.accentGreen,
                            size: 26,
                          ),
                          title: Text(
                            I18n.t(context, 'library_saved_articles'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            I18n.t(context, 'library_saved_subtitle'),
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                          onTap: () => context.go('/bookmarks'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_storage'),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.cleaning_services_rounded,
                            color: DailyhuntTheme.accentGreen,
                            size: 24,
                          ),
                          title: Text(
                            I18n.t(context, 'storage_clear_translated'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            I18n.t(context, 'storage_clear_translated_sub'),
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove(_translatedCacheKey);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  I18n.t(context, 'snack_translated_cleared'),
                                ),
                                behavior: SnackBarBehavior.floating,
                                width: 320,
                                duration: const Duration(milliseconds: 1200),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (user == null)
                        DailyhuntPrimaryButton(
                          label: I18n.t(context, 'action_signin'),
                          icon: Icons.login_rounded,
                          onPressed: () => context.push('/login'),
                        )
                      else
                        TextButton.icon(
                          onPressed: () async {
                            final auth = context.read<AuthProvider>();
                            await auth.logout();
                            if (!context.mounted) return;
                            context.go('/login');
                          },
                          icon: Icon(Icons.logout_rounded, color: cs.error),
                          label: Text(
                            I18n.t(context, 'action_signout'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.error,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserHeaderCard extends StatelessWidget {
  final String userName;
  final String userEmail;

  const _UserHeaderCard({
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: DailyhuntTheme.accentGreen,
              child: Text(
                AppUtils.initials(userName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: cs.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _GuestHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  DailyhuntTheme.accentGreen.withValues(alpha: 0.15),
              child: Icon(
                Icons.person_outline_rounded,
                size: 36,
                color: DailyhuntTheme.accentGreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t(context, 'profile_guest_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    I18n.t(context, 'profile_guest_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
