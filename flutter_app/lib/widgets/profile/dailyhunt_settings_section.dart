import 'package:flutter/material.dart';

import '../../theme/dailyhunt_theme.dart';

/// Minimal rounded white card for a settings group (Dailyhunt-style).
class DailyhuntSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DailyhuntSettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Primary filled button using Dailyhunt green (for Sign in / key actions).
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
    backgroundColor: DailyhuntTheme.accentGreen,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
  );

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
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
