import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../providers/shorts_provider.dart';
import '../../theme/app_palette.dart';
import 'shorts_feed_theme.dart';

/// Language filter for Shorts — synced with feed preference (en / te / hi / all).
class ShortsLanguageBar extends StatelessWidget {
  const ShortsLanguageBar({super.key});

  static const _options = <(String code, String label)>[
    ('en', 'English'),
    ('te', 'తెలుగు'),
    ('hi', 'हिन्दी'),
    ('all', 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final shorts = context.watch<ShortsProvider>();
    final selected = news.shortsLanguageBarCode;
    final p = context.palette;

    return ColoredBox(
      color: ShortsFeedTheme.background.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _options.map((opt) {
              final active = selected == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.black : Colors.white70,
                    ),
                  ),
                  selected: active,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  selectedColor: p.primary,
                  backgroundColor: const Color(0xFF1A1A1A),
                  side: BorderSide(
                    color: active ? p.primary : const Color(0xFF333333),
                  ),
                  onSelected: shorts.refreshing
                      ? null
                      : (_) => _onPick(context, opt.$1),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _onPick(BuildContext context, String code) async {
    final news = context.read<NewsProvider>();
    if (news.shortsLanguageBarCode == code) return;
    await news.selectLanguage(code);
    if (!context.mounted) return;
    await context.read<ShortsProvider>().ensureForLanguage(
      news.shortsFeedLanguage,
      force: true,
    );
  }
}
