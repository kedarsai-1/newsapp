import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/i18n.dart';
import 'feed/feed_xpresso_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final bool dark;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final useXpresso = dark || FeedXpressoTheme.isDark(context);
    if (useXpresso) {
      final fx = FeedXpressoTheme.fx(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: fx.iconFgMuted),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: fx.title,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: fx.meta,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (buttonLabel != null && onButtonTap != null) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onButtonTap,
                  style: TextButton.styleFrom(
                    foregroundColor: fx.iconFg,
                  ),
                  child: Text(buttonLabel!),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.inputFill,
              shape: BoxShape.circle,
              border: Border.all(color: p.cardBorder, width: 0.8),
            ),
            child: Icon(icon, size: 48, color: p.textHint),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onButtonTap, child: Text(buttonLabel!)),
          ],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool dark;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off,
      title: I18n.t(context, 'err_generic_title'),
      subtitle: message,
      buttonLabel: onRetry != null ? I18n.t(context, 'action_try_again') : null,
      onButtonTap: onRetry,
      dark: dark,
    );
  }
}
