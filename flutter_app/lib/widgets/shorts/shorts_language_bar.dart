import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../providers/shorts_provider.dart';
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
    final st = ShortsFeedTheme.fx(context);

    return ColoredBox(
      color: st.background.withValues(alpha: 0.85),
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
                      color: active ? st.chipFgActive : st.chipFg,
                    ),
                  ),
                  selected: active,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  selectedColor: st.accent,
                  backgroundColor: st.chipBg,
                  side: BorderSide(
                    color: active ? st.accent : st.chipBorder,
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
