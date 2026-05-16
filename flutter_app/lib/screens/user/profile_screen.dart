import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/profile/dailyhunt_settings_section.dart';

/// Profile & settings — dense Xpresso dark layout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _translatedCacheKey = 'feed_translated_summary_cache_v1';
  static const _padH = 10.0;

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

  static const _denseChipTheme = ChipThemeData(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    labelPadding: EdgeInsets.symmetric(horizontal: 2),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final news = context.watch<NewsProvider>();
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);

    return Scaffold(
      backgroundColor: FeedXpressoTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                toolbarHeight: 46,
                backgroundColor: FeedXpressoTheme.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  I18n.t(context, 'profile_title'),
                  style: FeedXpressoTheme.screenTitleStyle.copyWith(fontSize: 18),
                ),
                actions: [
                  IconButton(
                    tooltip: I18n.t(context, 'profile_privacy_tooltip'),
                    onPressed: () => context.push('/privacy-policy'),
                    icon: const Icon(
                      Icons.policy_outlined,
                      color: FeedXpressoTheme.iconFg,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(_padH, 4, _padH, bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (user == null)
                      _GuestIdentity(onSignIn: () => context.push('/login'))
                    else
                      _UserIdentity(
                        userName: user.name,
                        userEmail: user.email,
                      ),
                    DailyhuntSettingsSection(
                      title: I18n.t(context, 'section_language'),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>(news.selectedLanguage),
                        initialValue: news.selectedLanguage,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: FeedXpressoTheme.sheet,
                        borderRadius: BorderRadius.circular(6),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FeedXpressoTheme.title,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: FeedXpressoTheme.surface,
                        ),
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
                    Theme(
                      data: Theme.of(context).copyWith(chipTheme: _denseChipTheme),
                      child: DailyhuntSettingsSection(
                        title: I18n.t(context, 'section_interests'),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _interestSlugs.map((slug) {
                            final selected = _interests.contains(slug);
                            return FilterChip(
                              label: Text(
                                I18n.t(context, 'cat_$slug'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: selected
                                      ? FeedXpressoTheme.title
                                      : FeedXpressoTheme.summary,
                                ),
                              ),
                              selected: selected,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                              selectedColor: FeedXpressoTheme.iconSurface,
                              backgroundColor: FeedXpressoTheme.surface,
                              side: const BorderSide(
                                color: FeedXpressoTheme.divider,
                                width: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    DailyhuntSettingsSection(
                      title: I18n.t(context, 'section_notifications'),
                      child: Column(
                        children: [
                          _CompactSwitchRow(
                            label: I18n.t(context, 'notif_breaking'),
                            value: _breakingAlerts,
                            onChanged: (v) => setState(() => _breakingAlerts = v),
                          ),
                          _CompactSwitchRow(
                            label: I18n.t(context, 'notif_daily_digest'),
                            value: _dailyDigest,
                            onChanged: (v) => setState(() => _dailyDigest = v),
                          ),
                          _CompactSwitchRow(
                            label: I18n.t(context, 'notif_recommended'),
                            value: _recommendedAlerts,
                            onChanged: (v) =>
                                setState(() => _recommendedAlerts = v),
                          ),
                        ],
                      ),
                    ),
                    DailyhuntSettingsSection(
                      title: I18n.t(context, 'section_library'),
                      child: XpressoSettingsRow(
                        icon: Icons.bookmark_outline_rounded,
                        title: I18n.t(context, 'library_saved_articles'),
                        subtitle: I18n.t(context, 'library_saved_subtitle'),
                        onTap: () => context.go('/bookmarks'),
                      ),
                    ),
                    DailyhuntSettingsSection(
                      title: I18n.t(context, 'section_storage'),
                      showDivider: false,
                      child: XpressoSettingsRow(
                        icon: Icons.cleaning_services_rounded,
                        title: I18n.t(context, 'storage_clear_translated'),
                        subtitle: I18n.t(context, 'storage_clear_translated_sub'),
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
                    const SizedBox(height: 12),
                    if (user == null)
                      DailyhuntPrimaryButton(
                        label: I18n.t(context, 'action_signin'),
                        icon: Icons.login_rounded,
                        onPressed: () => context.push('/login'),
                      )
                    else
                      Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            final auth = context.read<AuthProvider>();
                            await auth.logout();
                            if (!context.mounted) return;
                            context.go('/login');
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: FeedXpressoTheme.iconFg,
                          ),
                          label: Text(
                            I18n.t(context, 'action_signout'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: FeedXpressoTheme.summary,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  final String userName;
  final String userEmail;

  const _UserIdentity({
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: FeedXpressoTheme.iconSurface,
            child: Text(
              AppUtils.initials(userName),
              style: const TextStyle(
                color: FeedXpressoTheme.title,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.15,
                    color: FeedXpressoTheme.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: FeedXpressoTheme.summary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestIdentity extends StatelessWidget {
  final VoidCallback onSignIn;

  const _GuestIdentity({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: FeedXpressoTheme.iconSurface,
            child: Icon(
              Icons.person_outline_rounded,
              size: 22,
              color: FeedXpressoTheme.iconFg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t(context, 'profile_guest_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: FeedXpressoTheme.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  I18n.t(context, 'profile_guest_subtitle'),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: FeedXpressoTheme.summary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: FeedXpressoTheme.iconFg,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(I18n.t(context, 'action_signin')),
          ),
        ],
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: FeedXpressoTheme.title,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: FeedXpressoTheme.title,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
