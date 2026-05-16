import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Xpresso settings block — section label + content + hairline separator.
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

  static const _sectionLabelStyle = TextStyle(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.45,
    fontSize: 10,
    color: FeedXpressoTheme.meta,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(title.toUpperCase(), style: _sectionLabelStyle),
          ),
        child,
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: FeedXpressoTheme.divider,
            ),
          ),
      ],
    );
  }
}

/// Tappable settings row — compact, no card chrome.
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white10,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: FeedXpressoTheme.iconFg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.15,
                        color: FeedXpressoTheme.title,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: FeedXpressoTheme.summary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: FeedXpressoTheme.iconFgMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact filled action (sign in).
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

  static final ButtonStyle _buttonStyle = FilledButton.styleFrom(
    backgroundColor: FeedXpressoTheme.iconSurface,
    foregroundColor: FeedXpressoTheme.title,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: _buttonStyle,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: _buttonStyle,
      child: Text(label),
    );
  }
}
