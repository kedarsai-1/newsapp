import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/models.dart';
import '../../../../theme/dailyhunt_theme.dart';
import 'super_home_section.dart';

/// Top hero rail: full-width, image-led page-view of breaking stories.
class SuperHomeHeroRail extends StatefulWidget {
  final List<NewsPost> posts;
  final void Function(NewsPost post)? onTap;

  const SuperHomeHeroRail({
    super.key,
    required this.posts,
    this.onTap,
  });

  @override
  State<SuperHomeHeroRail> createState() => _SuperHomeHeroRailState();
}

class _SuperHomeHeroRailState extends State<SuperHomeHeroRail> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _ctrl,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.posts.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = widget.posts[i];
              return _HeroCard(
                post: p,
                onTap: widget.onTap == null ? null : () => widget.onTap!(p),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.posts.length, (i) {
              final selected = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected
                      ? DailyhuntTheme.accentGreen
                      : Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback? onTap;

  const _HeroCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        post.media.isNotEmpty ? post.media.first.url : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEFEFEF),
                  ),
                )
              else
                Container(color: const Color(0xFFEFEFEF)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BREAKING',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${post.sourceName ?? 'Newsroom'} · ${SuperHomeSectionTime.relative(post.displayTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helpers used across sections.
class SuperHomeSectionTime {
  static String relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

// ─── Entertainment ───────────────────────────────────────────────────────

class SuperHomeEntertainmentSection extends StatelessWidget {
  final List<NewsPost> posts;
  final VoidCallback? onSeeAll;

  const SuperHomeEntertainmentSection({
    super.key,
    required this.posts,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Entertainment',
          subtitle: 'Movies, OTT releases and celebrity updates',
          icon: Icons.movie_creation_rounded,
          accentColor: const Color(0xFFB91C1C),
          onSeeAll: onSeeAll,
        ),
        SuperHomeHorizontalRail(
          height: 220,
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final p = posts[i];
            final url = p.media.isNotEmpty ? p.media.first.url : null;
            return SuperHomeNewsCard(
              imageUrl: url,
              headline: p.title,
              source: p.sourceName ?? 'Newsroom',
              publishedAt: p.displayTime,
              badge: _entertainmentBadge(p),
              badgeColor: const Color(0xFFB91C1C),
              onTap: () => context.push('/article/${p.id}'),
            );
          },
        ),
      ],
    );
  }

  static String _entertainmentBadge(NewsPost p) {
    final t = '${p.title} ${p.summary ?? ''}'.toLowerCase();
    if (t.contains('ott') ||
        t.contains('netflix') ||
        t.contains('prime') ||
        t.contains('hotstar') ||
        t.contains('zee5')) {
      return 'OTT';
    }
    if (t.contains('box office') ||
        t.contains('crore') ||
        t.contains('opening')) {
      return 'BOX OFFICE';
    }
    if (t.contains('trailer') || t.contains('teaser')) return 'TRAILER';
    return 'CINEMA';
  }
}

// ─── Shorts ──────────────────────────────────────────────────────────────

class SuperHomeShortsSection extends StatelessWidget {
  final List<NewsPost> posts;
  final VoidCallback? onSeeAll;

  const SuperHomeShortsSection({
    super.key,
    required this.posts,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Shorts',
          subtitle: 'Quick swipeable stories',
          icon: Icons.bolt_rounded,
          accentColor: const Color(0xFF7C3AED),
          onSeeAll: onSeeAll,
          seeAllLabel: 'Open shorts',
        ),
        SuperHomeHorizontalRail(
          height: 240,
          itemCount: posts.length,
          itemSpacing: 8,
          itemBuilder: (context, i) {
            final p = posts[i];
            final url = p.media.isNotEmpty ? p.media.first.url : null;
            return _ShortsTile(
              imageUrl: url,
              headline: p.title,
              source: p.sourceName ?? 'Newsroom',
              onTap: () => context.push('/shorts'),
            );
          },
        ),
      ],
    );
  }
}

class _ShortsTile extends StatelessWidget {
  final String? imageUrl;
  final String headline;
  final String source;
  final VoidCallback? onTap;

  const _ShortsTile({
    required this.imageUrl,
    required this.headline,
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1F2937),
                  ),
                )
              else
                Container(color: const Color(0xFF1F2937)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.4, 1.0],
                  ),
                ),
              ),
              const Positioned(
                top: 8,
                left: 8,
                child: _ShortsBadge(),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortsBadge extends StatelessWidget {
  const _ShortsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
          SizedBox(width: 4),
          Text(
            'SHORTS',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Local ───────────────────────────────────────────────────────────────

class SuperHomeLocalSection extends StatelessWidget {
  final List<NewsPost> posts;
  final String? cityLabel;
  final VoidCallback? onChangeCity;
  final VoidCallback? onSeeAll;

  const SuperHomeLocalSection({
    super.key,
    required this.posts,
    this.cityLabel,
    this.onChangeCity,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final city = (cityLabel ?? '').trim();
    final subtitle = city.isEmpty
        ? 'City and district news from your region'
        : 'Headlines around $city today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Local News',
          subtitle: subtitle,
          icon: Icons.location_city_rounded,
          accentColor: const Color(0xFF0F766E),
          onSeeAll: onSeeAll,
        ),
        if (city.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Wrap(
              spacing: 8,
              children: [
                _CityChip(
                  label: city,
                  selected: true,
                  onTap: onChangeCity,
                  icon: Icons.place_rounded,
                ),
                _CityChip(
                  label: 'Change city',
                  selected: false,
                  onTap: onChangeCity,
                  icon: Icons.tune_rounded,
                ),
              ],
            ),
          ),
        SuperHomeHorizontalRail(
          height: 220,
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final p = posts[i];
            final url = p.media.isNotEmpty ? p.media.first.url : null;
            final district = p.location?.city ?? p.constituency ?? '';
            return SuperHomeNewsCard(
              imageUrl: url,
              headline: p.title,
              source: p.sourceName ?? 'Newsroom',
              publishedAt: p.displayTime,
              badge: district.isEmpty ? 'LOCAL' : district.toUpperCase(),
              badgeColor: const Color(0xFF0F766E),
              onTap: () => context.push('/article/${p.id}'),
            );
          },
        ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  const _CityChip({
    required this.label,
    required this.selected,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F766E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? accent : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? accent : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trending / Viral ────────────────────────────────────────────────────

class SuperHomeTrendingSection extends StatelessWidget {
  final List<NewsPost> posts;
  final VoidCallback? onSeeAll;

  const SuperHomeTrendingSection({
    super.key,
    required this.posts,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Trending',
          subtitle: 'Memes, viral stories and social trends',
          icon: Icons.trending_up_rounded,
          accentColor: const Color(0xFFEA580C),
          onSeeAll: onSeeAll,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _TopicChips(),
        ),
        const SizedBox(height: 4),
        ...List.generate(
          posts.length,
          (i) {
            final p = posts[i];
            final url = p.media.isNotEmpty ? p.media.first.url : null;
            return Column(
              children: [
                SuperHomeNewsStrip(
                  imageUrl: url,
                  headline: p.title,
                  source: p.sourceName ?? 'Newsroom',
                  publishedAt: p.displayTime,
                  rank: i + 1,
                  onTap: () => context.push('/article/${p.id}'),
                ),
                if (i != posts.length - 1)
                  const Divider(height: 1, color: Color(0xFFEFEFEF)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TopicChips extends StatelessWidget {
  const _TopicChips();

  static const _topics = [
    ('Viral', Icons.local_fire_department_rounded),
    ('Memes', Icons.emoji_emotions_rounded),
    ('Reels', Icons.movie_filter_rounded),
    ('Tweets', Icons.format_quote_rounded),
    ('Whatsapp', Icons.chat_bubble_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, icon) = _topics[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEFEFEF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: const Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
