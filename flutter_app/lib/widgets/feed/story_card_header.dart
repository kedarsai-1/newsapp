import 'package:flutter/material.dart';
import 'feed_xpresso_theme.dart';

/// Minimal header with category chip and source indicator
/// Visual hierarchy: Category (subtle) > Source > Time
class StoryCardHeader extends StatelessWidget {
  const StoryCardHeader({
    super.key,
    required this.category,
    required this.source,
    required this.time,
  });

  final String? category;
  final String source;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (category?.isNotEmpty == true) ...[
          _buildCategoryChip(context),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _buildSourceAndTimeRow(context),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fx.chipInactive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fx.chipInactiveBorder,
          width: 0.6,
        ),
      ),
      child: Text(
        category ?? '',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: fx.textTertiary,
        ),
      ),
    );
  }

  Widget _buildSourceAndTimeRow(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            source,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fx.textTertiary,
              letterSpacing: 0.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          time,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: fx.textTertiary,
          ),
        ),
      ],
    );
  }
}