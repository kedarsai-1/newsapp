import 'package:flutter/material.dart';

/// Accessibility utility widgets and extensions.
extension AccessibilityExt on Widget {
  /// Wrap with a Semantics widget for tappable elements.
  Widget accessible({
    String? label,
    String? hint,
    bool isButton = true,
    bool isEnabled = true,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      enabled: isEnabled,
      child: this,
    );
  }

  /// Wrap with a Semantics widget for news article.
  Widget accessibleArticle({
    required String title,
    String? source,
    String? timestamp,
  }) {
    return Semantics(
      label: 'Article: $title',
      hint: source != null ? 'Published by $source' : null,
      child: this,
    );
  }
}

/// Accessibility-friendly icon button with semantic labels.
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? semanticHint;
  final Color? color;
  final double? size;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.semanticHint,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      child: IconButton(
        icon: Icon(icon, color: color, size: size),
        onPressed: onPressed,
      ),
    );
  }
}

/// Accessibility-friendly action row for feed items.
class AccessibleActionRow extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final String? semanticHint;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const AccessibleActionRow({
    super.key,
    required this.label,
    required this.semanticLabel,
    this.semanticHint,
    required this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}