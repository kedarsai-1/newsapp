import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../utils/i18n.dart';

/// Personalized home header with greeting and context chips
///
/// Features:
/// - Morning/afternoon/evening greeting based on time
/// - Weather chip with conditions
/// - Location selector chip
/// - Personalized interest chip
/// - Premium glass morphism effects
/// - Smooth animations on interaction
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Greeting section
        _buildGreetingSection(context),
        const SizedBox(height: DesignTokens.space16),

        // Context chips
        _buildContextChips(context),
        const SizedBox(height: DesignTokens.space16),

        // Weather info
        _buildWeatherSection(context),
      ],
    );
  }

  Widget _buildGreetingSection(BuildContext context) {
    final palette = context.palette;
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return AnimatedContainer(
      duration: DesignTokens.durationNormal,
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: palette.glassSurface,
        borderRadius: BorderRadius.circular(DesignTokens.radius2XL),
        border: Border.all(
          color: palette.glassBorder.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: DesignTokens.elevationLG,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$greeting 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: palette.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              _buildPulseIcon(palette),
            ],
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            I18n.t(context, 'home_here_what_happening'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: palette.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseIcon(AppPalette palette) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.primary.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildContextChips(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        // Location chip
        Expanded(
          child: _ContextChip(
            icon: Icons.location_on,
            label: 'Hyderabad',
            onPressed: () {
              // Show location picker
              HapticFeedback.selectionClick();
            },
            palette: palette,
          ),
        ),
        const SizedBox(width: DesignTokens.space8),

        // Weather chip
        Expanded(
          child: _ContextChip(
            icon: Icons.cloud,
            label: '28°C Sunny',
            onPressed: () {
              // Show weather details
              HapticFeedback.selectionClick();
            },
            palette: palette,
            accent: palette.primary,
          ),
        ),
        const SizedBox(width: DesignTokens.space8),

        // Interest chip
        Expanded(
          child: _ContextChip(
            icon: Icons.interests,
            label: 'Technology',
            onPressed: () {
              // Show interest selector
              HapticFeedback.selectionClick();
            },
            palette: palette,
            accent: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherSection(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.primary.withValues(alpha: 0.1),
            palette.accentGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            child: Icon(
              Icons.wb_sunny,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sunny and Clear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'Perfect day to catch up on news',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Show weather details
              HapticFeedback.selectionClick();
            },
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Context-aware chip component
class _ContextChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final AppPalette palette;
  final Color? accent;

  const _ContextChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
    this.accent,
  });

  @override
  State<_ContextChip> createState() => _ContextChipState();
}

class _ContextChipState extends State<_ContextChip>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accent ?? widget.palette.primary;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (_) {
                _controller.forward();
                HapticFeedback.selectionClick();
              },
              onTapUp: (_) {
                _controller.reverse();
              },
              onTapCancel: () {
                _controller.reverse();
              },
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space8,
                ),
                decoration: BoxDecoration(
                  color: widget.palette.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.1),
                      blurRadius: DesignTokens.elevationSM,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: DesignTokens.space6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: widget.palette.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}