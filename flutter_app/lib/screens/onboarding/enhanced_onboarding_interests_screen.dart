import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/feed/feed_xpresso_palette_enhanced.dart';

class EnhancedOnboardingInterestsScreen extends StatefulWidget {
  const EnhancedOnboardingInterestsScreen({super.key});

  @override
  State<EnhancedOnboardingInterestsScreen> createState() =>
      _EnhancedOnboardingInterestsScreenState();
}

class _EnhancedOnboardingInterestsScreenState
    extends State<EnhancedOnboardingInterestsScreen> {
  final Set<int> _selectedInterests = {};
  bool _isLoading = false;

  final List<(String, String, IconData)> _interests = [
    ('Politics', 'Stay updated with political news', Icons.account_balance_rounded),
    ('Sports', 'Sports updates and analysis', Icons.sports_soccer_rounded),
    ('Entertainment', 'Movies, music and celebrity news', Icons.movie_rounded),
    ('Technology', 'Tech trends and innovations', Icons.computer_rounded),
    ('Business', 'Markets, economy and finance', Icons.trending_up_rounded),
    ('Health', 'Health tips and medical news', Icons.favorite_rounded),
    ('Education', 'Learning and academic news', Icons.school_rounded),
    ('Local News', 'Your city and neighborhood', Icons.location_city_rounded),
  ];

  void _toggleInterest(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedInterests.contains(index)) {
        _selectedInterests.remove(index);
      } else {
        _selectedInterests.add(index);
      }
    });
  }

  void _continue() {
    if (_selectedInterests.isEmpty) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/onboarding/location');
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedXpressoPaletteEnhanced.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with enhanced design
                      Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.paddingOf(context).top + 24,
                          bottom: 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button with modern design
                            Row(
                              children: [
                                _GlassIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  onPressed: () => Navigator.of(context).pop(),
                                  palette: palette,
                                ),
                                const Spacer(),
                                // Progress indicator
                                _ProgressIndicator(
                                  current: 2,
                                  total: 5,
                                  palette: palette,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Title with gradient effect
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: [
                                    palette.brandGradientStart,
                                    palette.brandGradientEnd,
                                  ],
                                ).createShader(bounds);
                              },
                              child: Text(
                                'What interests you?',
                                style: GoogleFonts.notoSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Select topics to personalize your news feed',
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: palette.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Interest cards with enhanced design
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(_interests.length, (index) {
                          final (name, description, icon) = _interests[index];
                          final isSelected = _selectedInterests.contains(index);
                          final gradient = FeedXpressoPaletteEnhanced.categoryGradientEnhanced(name);

                          return _InterestCard(
                            name: name,
                            description: description,
                            icon: icon,
                            isSelected: isSelected,
                            gradient: gradient,
                            onTap: () => _toggleInterest(index),
                            palette: palette,
                          );
                        }),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Enhanced bottom action bar
            Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.paddingOf(context).bottom + 20,
              ),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(
                  top: BorderSide(
                    color: palette.divider.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedInterests.length} selected',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (_selectedInterests.isEmpty)
                          Text(
                            'Select at least one topic',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: palette.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _EnhancedButton(
                    isLoading: _isLoading,
                    onPressed: _continue,
                    isDisabled: _selectedInterests.isEmpty,
                    palette: palette,
                    label: 'Continue',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestCard extends StatefulWidget {
  final String name;
  final String description;
  final IconData icon;
  final bool isSelected;
  final (String, List<Color>) gradient;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _InterestCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_InterestCard> createState() => _InterestCardState();
}

class _InterestCardState extends State<_InterestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, colors) = widget.gradient;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: (MediaQuery.sizeOf(context).width - 60) / 2,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: widget.isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors[0].withValues(alpha: 0.15),
                          colors[1].withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                color: widget.isSelected ? null : widget.palette.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isSelected ? colors[0] : widget.palette.glassBorder,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon with gradient background
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      // Selection indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? colors[0]
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isSelected
                                ? colors[0]
                                : widget.palette.glassBorder,
                            width: 2,
                          ),
                        ),
                        child: widget.isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.isSelected ? colors[0] : widget.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.palette.textTertiary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final FeedXpressoPaletteEnhanced palette;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.glassSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: palette.glassBorder,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: palette.iconFg,
          size: 22,
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;
  final FeedXpressoPaletteEnhanced palette;

  const _ProgressIndicator({
    required this.current,
    required this.total,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final isActive = index < current;
        final isCurrent = index == current - 1;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: [
                          palette.brandGradientStart,
                          palette.brandGradientEnd,
                        ],
                      )
                    : null,
                color: isActive ? null : palette.glassBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (index < total - 1) const SizedBox(width: 4),
          ],
        );
      }),
    );
  }
}

class _EnhancedButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final bool isDisabled;
  final FeedXpressoPaletteEnhanced palette;
  final String label;

  const _EnhancedButton({
    required this.isLoading,
    required this.onPressed,
    required this.isDisabled,
    required this.palette,
    required this.label,
  });

  @override
  State<_EnhancedButton> createState() => _EnhancedButtonState();
}

class _EnhancedButtonState extends State<_EnhancedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isDisabled || widget.isLoading
          ? null
          : (_) => _controller.forward(),
      onTapUp: widget.isDisabled || widget.isLoading
          ? null
          : (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: widget.isDisabled
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.palette.brandGradientStart,
                          widget.palette.brandGradientEnd,
                        ],
                      ),
                color: widget.isDisabled
                    ? widget.palette.disabled
                    : null,
                borderRadius: BorderRadius.circular(26),
                boxShadow: widget.isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: widget.palette.brandGradientStart
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.palette.onAccent,
                          ),
                        ),
                      )
                    : Text(
                        widget.label,
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.isDisabled
                              ? widget.palette.textTertiary
                              : widget.palette.onAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}