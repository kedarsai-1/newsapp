import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';

/// AI-powered summary expansion panel
///
/// Shows:
/// - Why this matters section
/// - Key facts bullet points
/// - Background context
/// - Related timeline
/// - Related articles
///
/// Animates open/close with spring physics
class AIExpansionPanel extends StatefulWidget {
  final NewsPost post;
  final bool isExpanded;
  final AppPalette? palette;

  const AIExpansionPanel({
    super.key,
    required this.post,
    required this.isExpanded,
    this.palette,
  });

  @override
  State<AIExpansionPanel> createState() => _AIExpansionPanelState();
}

class _AIExpansionPanelState extends State<AIExpansionPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _heightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );

    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AIExpansionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette ?? context.palette;

    return SizeTransition(
      sizeFactor: _heightAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          margin: const EdgeInsets.only(top: DesignTokens.space12),
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primary.withValues(alpha: 0.08),
                palette.accentPurple.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildSectionHeader(
                icon: Icons.auto_awesome,
                title: 'AI Summary',
                palette: palette,
              ),

              const SizedBox(height: DesignTokens.space16),

              // Why this matters
              _buildWhyMatters(palette),

              const SizedBox(height: DesignTokens.space20),

              // Key facts
              _buildKeyFacts(palette),

              const SizedBox(height: DesignTokens.space20),

              // Timeline
              _buildTimeline(palette),

              const SizedBox(height: DesignTokens.space16),

              // Related articles
              _buildRelatedArticles(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required AppPalette palette,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          ),
          child: Icon(
            icon,
            size: 20,
            color: palette.primary,
          ),
        ),
        const SizedBox(width: DesignTokens.space12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.auto_awesome,
          size: 16,
          color: palette.accentPurple,
        ),
      ],
    );
  }

  Widget _buildWhyMatters(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubheader(
          icon: Icons.lightbulb_outline,
          title: 'Why this matters',
          palette: palette,
        ),
        const SizedBox(height: DesignTokens.space10),
        Text(
          _extractWhyMatters(widget.post),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: palette.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyFacts(AppPalette palette) {
    final facts = _extractKeyFacts(widget.post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubheader(
          icon: Icons.check_circle_outline,
          title: 'Key facts',
          palette: palette,
        ),
        const SizedBox(height: DesignTokens.space10),
        ...facts.map((fact) => _buildFactItem(fact, palette)),
      ],
    );
  }

  Widget _buildFactItem(String fact, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DesignTokens.space10),
          Expanded(
            child: Text(
              fact,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(AppPalette palette) {
    final events = _extractTimeline(widget.post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubheader(
          icon: Icons.timeline,
          title: 'Timeline',
          palette: palette,
        ),
        const SizedBox(height: DesignTokens.space12),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;

          return _buildTimelineItem(event, palette, isLast);
        }),
      ],
    );
  }

  Widget _buildTimelineItem(
    Map<String, String> event,
    AppPalette palette,
    bool isLast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: palette.divider.withValues(alpha: 0.5),
              ),
          ],
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event['time'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.primary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                event['event'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedArticles(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubheader(
          icon: Icons.article_outlined,
          title: 'Related articles',
          palette: palette,
        ),
        const SizedBox(height: DesignTokens.space10),
        _buildRelatedArticleItem(
          title: 'Related story headline here',
          source: 'Source',
          palette: palette,
        ),
        const SizedBox(height: DesignTokens.space8),
        _buildRelatedArticleItem(
          title: 'Another related headline here',
          source: 'Source',
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildRelatedArticleItem({
    required String title,
    required String source,
    required AppPalette palette,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space12),
          decoration: BoxDecoration(
            color: palette.scaffoldBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          ),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 20,
                color: palette.textSecondary,
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      source,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubheader({
    required IconData icon,
    required String title,
    required AppPalette palette,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: palette.primary,
        ),
        const SizedBox(width: DesignTokens.space8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  String _extractWhyMatters(NewsPost post) {
    final summary = (post.summary ?? post.body).trim();
    if (summary.length < 50) return summary;
    // In production, this would come from AI-generated content
    return 'This development is significant because it represents a shift in the current landscape and may have far-reaching implications for affected parties.';
  }

  List<String> _extractKeyFacts(NewsPost post) {
    // In production, these would be AI-generated key facts
    return [
      'Fact 1: Key information about this story',
      'Fact 2: Important detail that readers should know',
      'Fact 3: Context or background information',
    ];
  }

  List<Map<String, String>> _extractTimeline(NewsPost post) {
    // In production, this would be AI-generated timeline
    return [
      {'time': 'Today', 'event': 'Latest development or announcement'},
      {'time': 'Yesterday', 'event': 'Previous related event'},
      {'time': 'Last week', 'event': 'Earlier context or background'},
    ];
  }
}