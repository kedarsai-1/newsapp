import 'dart:ui';

import 'package:flutter/material.dart';

import '../dailyhunt_tokens.dart';

enum DhActionStyle { glassDark, filledAccent, tonal }

/// Icon-first control for toolbars / reels: glass (on imagery), filled, or tonal.
class DhActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final DhActionStyle style;
  final Color? iconColor;

  const DhActionButton({
    super.key,
    required this.icon,
    this.label,
    this.onTap,
    this.style = DhActionStyle.glassDark,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconOnly = _iconShell(
      context: context,
      child: Icon(
        icon,
        size: 22,
        color: iconColor ?? _defaultIconColor(cs),
      ),
    );

    if (label == null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: iconOnly,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: iconOnly,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: style == DhActionStyle.glassDark
                  ? Colors.white.withValues(alpha: 0.92)
                  : cs.onSurface.withValues(alpha: 0.75),
              shadows: style == DhActionStyle.glassDark
                  ? const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Color _defaultIconColor(ColorScheme cs) {
    switch (style) {
      case DhActionStyle.glassDark:
        return Colors.white;
      case DhActionStyle.filledAccent:
        return Colors.white;
      case DhActionStyle.tonal:
        return DhTokens.accent;
    }
  }

  Widget _iconShell({required BuildContext context, required Widget child}) {
    switch (style) {
      case DhActionStyle.glassDark:
        return ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.52),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: child,
            ),
          ),
        );
      case DhActionStyle.filledAccent:
        return Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DhTokens.accent,
            shape: BoxShape.circle,
          ),
          child: child,
        );
      case DhActionStyle.tonal:
        return Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DhTokens.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: DhTokens.accent.withValues(alpha: 0.35)),
          ),
          child: child,
        );
    }
  }
}
