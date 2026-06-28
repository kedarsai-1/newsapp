import 'package:flutter/material.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Settings block — section label + content + hairline separator.
class DailyhuntSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showTitle;
  final bool showDivider;

  const DailyhuntSettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.showTitle = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
                fontSize: 10,
                color: fx.meta,
              ),
            ),
          ),
        child,
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: fx.divider,
            ),
          ),
      ],
    );
  }
}

/// Tappable settings row.
class XpressoSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const XpressoSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fx.iconFg),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.15,
                        color: fx.title,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: fx.summary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: fx.iconFgMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary action button — accent fill in light, elevated in dark.
class DailyhuntPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const DailyhuntPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isDark = FeedXpressoTheme.isDark(context);
    final style = FilledButton.styleFrom(
      backgroundColor: isDark ? fx.iconSurface : fx.accent,
      foregroundColor: isDark ? fx.title : Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: style,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
