import 'package:flutter/material.dart';
import 'premium_animations.dart';

/// A simple icon button with a consistent premium style.
class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const PremiumIconButton({Key? key, required this.icon, required this.onTap}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return PremiumAnimatedWrapper(
      child: IconButton(
        icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        onPressed: onTap,
      ),
    );
  }
}

/// A pill‑shaped button with a gradient background.
class GradientPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const GradientPillButton({Key? key, required this.label, this.icon, required this.onPressed}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return PremiumAnimatedWrapper(
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF374ABE), Color(0xFF64B6FF)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 18, color: Colors.white),
                if (icon != null) const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple progress dots for story/carousel indicators.
class StoryProgressDots extends StatelessWidget {
  final int total;
  final int index;
  const StoryProgressDots({Key? key, required this.total, required this.index}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == index ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
          ),
        );
      }),
    );
  }
}
