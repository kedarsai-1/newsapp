import 'package:flutter/material.dart';

import '../../../../widgets/feed/feed_xpresso_palette.dart';
import '../../../../widgets/feed/feed_xpresso_theme.dart';
import '../../../../theme/dailyhunt_theme.dart';
import 'super_home_section.dart';

class ZodiacSign {
  final String name;
  final String sanskrit;
  final String emoji;
  final String range;
  final List<Color> gradient;

  const ZodiacSign({
    required this.name,
    required this.sanskrit,
    required this.emoji,
    required this.range,
    required this.gradient,
  });
}

/// Astrology section: featured horoscope card with lucky chips + a horizontal
/// rail of all 12 zodiac signs. All predictions are deterministic per-day so
/// the screen feels stable across rebuilds without needing a backend.
class SuperHomeAstrologySection extends StatefulWidget {
  final VoidCallback? onSeeAll;

  const SuperHomeAstrologySection({super.key, this.onSeeAll});

  @override
  State<SuperHomeAstrologySection> createState() =>
      _SuperHomeAstrologySectionState();
}

class _SuperHomeAstrologySectionState extends State<SuperHomeAstrologySection> {
  static final List<ZodiacSign> _signs = [
    ZodiacSign(
      name: 'Aries',
      sanskrit: 'Mesha',
      emoji: '♈',
      range: 'Mar 21 – Apr 19',
      gradient: FeedXpressoPalette.zodiacSignGradients[0],
    ),
    ZodiacSign(
      name: 'Taurus',
      sanskrit: 'Vrishabha',
      emoji: '♉',
      range: 'Apr 20 – May 20',
      gradient: FeedXpressoPalette.zodiacSignGradients[1],
    ),
    ZodiacSign(
      name: 'Gemini',
      sanskrit: 'Mithuna',
      emoji: '♊',
      range: 'May 21 – Jun 20',
      gradient: FeedXpressoPalette.zodiacSignGradients[2],
    ),
    ZodiacSign(
      name: 'Cancer',
      sanskrit: 'Karka',
      emoji: '♋',
      range: 'Jun 21 – Jul 22',
      gradient: FeedXpressoPalette.zodiacSignGradients[3],
    ),
    ZodiacSign(
      name: 'Leo',
      sanskrit: 'Simha',
      emoji: '♌',
      range: 'Jul 23 – Aug 22',
      gradient: FeedXpressoPalette.zodiacSignGradients[4],
    ),
    ZodiacSign(
      name: 'Virgo',
      sanskrit: 'Kanya',
      emoji: '♍',
      range: 'Aug 23 – Sep 22',
      gradient: FeedXpressoPalette.zodiacSignGradients[5],
    ),
    ZodiacSign(
      name: 'Libra',
      sanskrit: 'Tula',
      emoji: '♎',
      range: 'Sep 23 – Oct 22',
      gradient: FeedXpressoPalette.zodiacSignGradients[6],
    ),
    ZodiacSign(
      name: 'Scorpio',
      sanskrit: 'Vrishchika',
      emoji: '♏',
      range: 'Oct 23 – Nov 21',
      gradient: FeedXpressoPalette.zodiacSignGradients[7],
    ),
    ZodiacSign(
      name: 'Sagittarius',
      sanskrit: 'Dhanu',
      emoji: '♐',
      range: 'Nov 22 – Dec 21',
      gradient: FeedXpressoPalette.zodiacSignGradients[8],
    ),
    ZodiacSign(
      name: 'Capricorn',
      sanskrit: 'Makara',
      emoji: '♑',
      range: 'Dec 22 – Jan 19',
      gradient: FeedXpressoPalette.zodiacSignGradients[9],
    ),
    ZodiacSign(
      name: 'Aquarius',
      sanskrit: 'Kumbha',
      emoji: '♒',
      range: 'Jan 20 – Feb 18',
      gradient: FeedXpressoPalette.zodiacSignGradients[10],
    ),
    ZodiacSign(
      name: 'Pisces',
      sanskrit: 'Meena',
      emoji: '♓',
      range: 'Feb 19 – Mar 20',
      gradient: FeedXpressoPalette.zodiacSignGradients[11],
    ),
  ];

  static const List<String> _predictions = [
    'A productive day for new starts. Trust your gut on a financial call you have been postponing.',
    'Your routine gets a boost — small wins compound into something meaningful by evening.',
    'Communication is your strength today. A short message could open a long conversation.',
    'Family time is restorative. Avoid signing long-term commitments before evening.',
    'Confidence runs high — channel it into one focused goal instead of three half-baked ones.',
    'Detail-oriented work pays off. Re-read what you write before sharing it widely.',
    'Balance over busy. A creative collaboration nudges you forward in the second half of the day.',
    'Intensity is your edge. Useful for a tough conversation — keep it kind, not sharp.',
    'Travel or learning sparks an unexpected idea. Note it down before the day ends.',
    'Discipline turns into momentum. Friends value your steady advice today.',
    'A flash of insight reframes a problem you have been stuck on. Share it before you forget it.',
    'Lean into intuition. A creative outlet — music, journaling, cooking — recharges you.',
  ];

  static const List<String> _luckyColors = [
    'Coral',
    'Forest green',
    'Sun yellow',
    'Sea blue',
    'Saffron',
    'Lavender',
    'Rose',
    'Teal',
    'Amber',
    'Slate',
    'Sky',
    'Indigo',
  ];

  int _selected = -1;

  @override
  void initState() {
    super.initState();
    _selected = _todaysSignIndex();
  }

  /// Picks the sign whose date range contains today, falling back to Aries.
  static int _todaysSignIndex() {
    final now = DateTime.now();
    final m = now.month;
    final d = now.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 0;
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 1;
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 2;
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 3;
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 4;
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 5;
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 6;
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 7;
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 8;
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 9;
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 10;
    if ((m == 2 && d >= 19) || (m == 3 && d <= 20)) return 11;
    return 0;
  }

  String _todayPrediction(int signIndex) {
    final now = DateTime.now();
    final dayOfYear = int.parse(
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}');
    final seed = (signIndex * 31 + dayOfYear) % _predictions.length;
    return _predictions[seed];
  }

  int _luckyNumber(int signIndex) {
    final now = DateTime.now();
    final stamp = now.year + now.month * 41 + now.day * 7;
    return ((signIndex + 1) * 13 + stamp) % 9 + 1;
  }

  String _luckyColor(int signIndex) {
    final now = DateTime.now();
    final seed = (signIndex * 17 + now.day) % _luckyColors.length;
    return _luckyColors[seed];
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final selected = _selected.clamp(0, _signs.length - 1);
    final sign = _signs[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Astrology',
          subtitle: 'Daily horoscope, lucky number and color',
          icon: Icons.auto_awesome_rounded,
          accentColor: fx.onWarningSurface,
          onSeeAll: widget.onSeeAll,
          seeAllLabel: 'All signs',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FeaturedHoroscopeCard(
            sign: sign,
            prediction: _todayPrediction(selected),
            luckyNumber: _luckyNumber(selected),
            luckyColor: _luckyColor(selected),
          ),
        ),
        SizedBox(height: 12),
        SuperHomeHorizontalRail(
          height: 110,
          itemCount: _signs.length,
          itemSpacing: 8,
          itemBuilder: (context, i) => _ZodiacChip(
            sign: _signs[i],
            selected: i == selected,
            onTap: () => setState(() => _selected = i),
          ),
        ),
      ],
    );
  }
}

class _FeaturedHoroscopeCard extends StatelessWidget {
  final ZodiacSign sign;
  final String prediction;
  final int luckyNumber;
  final String luckyColor;

  const _FeaturedHoroscopeCard({
    required this.sign,
    required this.prediction,
    required this.luckyNumber,
    required this.luckyColor,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: sign.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: fx.heroOverlayBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fx.onImage.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(sign.emoji,
                    style: TextStyle(fontSize: 26, height: 1)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sign.name} · ${sign.sanskrit}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fx.title,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      sign.range,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: fx.summary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fx.onImage.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: fx.title,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            prediction,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LuckyChip(
                icon: Icons.casino_rounded,
                label: 'Lucky number',
                value: luckyNumber.toString(),
              ),
              _LuckyChip(
                icon: Icons.palette_rounded,
                label: 'Lucky color',
                value: luckyColor,
              ),
              const _LuckyChip(
                icon: Icons.favorite_rounded,
                label: 'Mood',
                value: 'Optimistic',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LuckyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LuckyChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fx.onImage.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fx.title),
          SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fx.summary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fx.title,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZodiacChip extends StatelessWidget {
  final ZodiacSign sign;
  final bool selected;
  final VoidCallback onTap;

  const _ZodiacChip({
    required this.sign,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return SizedBox(
      width: 92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: sign.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? DailyhuntTheme.accentGreen(context)
                : fx.onImageMuted,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(sign.emoji,
                      style: TextStyle(fontSize: 28, height: 1)),
                  SizedBox(height: 6),
                  Text(
                    sign.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: fx.title,
                    ),
                  ),
                  Text(
                    sign.sanskrit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color:
                          fx.summary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
