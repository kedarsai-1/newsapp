import 'package:flutter/material.dart';
import '../constants.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.buttonLabel, this.onButtonTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlassColors.surfaceWhite,
              shape: BoxShape.circle,
              border: Border.all(color: GlassColors.borderWhite, width: 0.8),
            ),
            child: Icon(icon, size: 48, color: GlassColors.textHint),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: GlassColors.textPrimary), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(fontSize: 14, color: GlassColors.textTertiary, height: 1.5), textAlign: TextAlign.center),
          ],
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: 24),
            GlassButton(label: buttonLabel!, onPressed: onButtonTap),
          ],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off,
      title: 'Something went wrong',
      subtitle: message,
      buttonLabel: onRetry != null ? 'Try Again' : null,
      onButtonTap: onRetry,
    );
  }
}