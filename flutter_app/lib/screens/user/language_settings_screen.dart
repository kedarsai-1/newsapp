import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/news_provider.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Language settings screen — choose content language.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const _languages = [
    ('en', 'English', '🇬🇧'),
    ('hi', 'हिंदी', '🇮🇳'),
    ('te', 'తెలుగు', '🇮🇳'),
    ('ta', 'தமிழ்', '🇮🇳'),
    ('kn', 'ಕನ್ನಡ', '🇮🇳'),
    ('bn', 'বাংলা', '🇮🇳'),
    ('ml', 'മലയാളം', '🇮🇳'),
    ('all', 'All Languages', '🌐'),
  ];

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final news = context.watch<NewsProvider>();
    final selected = news.selectedLanguage;

    return Scaffold(
      backgroundColor: fx.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 52,
            backgroundColor: fx.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: fx.title,
            title: Text(
              'Language',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: fx.title,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg, size: 22),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: fx.divider),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select your preferred language for news content.',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: fx.textSecondary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final (code, name, flag) = _languages[index];
                final isSelected = selected == code;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? fx.accent.withValues(alpha: 0.12)
                        : fx.glassSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? fx.accent
                          : fx.glassBorder.withValues(alpha: 0.6),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? fx.accent : fx.title,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: fx.accent)
                        : null,
                    onTap: () {
                      news.selectLanguage(code);
                      context.pop();
                    },
                  ),
                );
              },
              childCount: _languages.length,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20)),
        ],
      ),
    );
  }
}
