import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_palette_enhanced.dart';
import '../../theme/xpresso_app_theme.dart';

class EnhancedOnboardingLanguageScreen extends StatefulWidget {
  const EnhancedOnboardingLanguageScreen({super.key});

  @override
  State<EnhancedOnboardingLanguageScreen> createState() => _EnhancedOnboardingLanguageScreenState();
}

class _EnhancedOnboardingLanguageScreenState extends State<EnhancedOnboardingLanguageScreen> {
  int? _selectedLanguage;
  bool _isLoading = false;

  final List<(String, String, String, String)> _languages = [
    ('English', 'English', 'en', '🇬🇧'),
    ('हिंदी', 'Hindi', 'hi', '🇮🇳'),
    ('తెలుగు', 'Telugu', 'te', '🇮🇳'),
    ('தமிழ்', 'Tamil', 'ta', '🇮🇳'),
    ('ಕನ್ನಡ', 'Kannada', 'kn', '🇮🇳'),
    ('বাংলা', 'Bengali', 'bn', '🇧🇩'),
    ('മലയാളം', 'Malayalam', 'ml', '🇮🇳'),
  ];

  void _selectLanguage(int index) {
    setState(() {
      _selectedLanguage = _selectedLanguage == index ? null : index;
    });
  }

  void _continue() {
    if (_selectedLanguage == null) return;

    setState(() => _isLoading = true);

    // Simulate loading
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      context.push('/onboarding/interests');
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedXpressoPaletteEnhanced.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Enhanced header with gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 40,
                  bottom: 32,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.background,
                      palette.background.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Animated app logo
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [palette.brandGradientStart, palette.brandGradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: palette.brandGradientStart.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: palette.onAccent,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title with enhanced typography
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 800),
                      opacity: 1.0,
                      child: Text(
                        'Choose Your Language',
                        style: GoogleFonts.notoSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: palette.title,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 1000),
                      opacity: 0.9,
                      child: Text(
                        'Select your preferred language to get personalized news',
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Language selection grid with enhanced design
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instructions
                      Text(
                        'Select one language',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.textTertiary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Language grid with enhanced cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 600;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWide ? 3 : 2,
                              childAspectRatio: isWide ? 1.1 : 1.0,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _languages.length,
                            itemBuilder: (context, index) {
                              final (nativeName, englishName, code, flag) = _languages[index];
                              final isSelected = _selectedLanguage == index;

                              return AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                scale: isSelected ? 1.05 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: _LanguageCard(
                                    nativeName: nativeName,
                                    englishName: englishName,
                                    flag: flag,
                                    isSelected: isSelected,
                                    onTap: () => _selectLanguage(index),
                                    palette: palette,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced continue button
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 32,
                  top: 16,
                ),
                child: AnimatedButton(
                  isLoading: _isLoading,
                  onPressed: _continue,
                  isDisabled: _selectedLanguage == null,
                  palette: palette,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  final String nativeName;
  final String englishName;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _LanguageCard({
    required this.nativeName,
    required this.englishName,
    required this.flag,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? widget.palette.brandGradientStart.withValues(alpha: 0.15)
              : _isHovered
                  ? widget.palette.hoverSurface
                  : widget.palette.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isSelected
                ? widget.palette.brandGradientStart
                : _isHovered
                    ? widget.palette.borderFocus
                    : widget.palette.glassBorder,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: widget.palette.brandGradientStart.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : _isHovered
                  ? [
                      BoxShadow(
                        color: widget.palette.heroShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flag emoji with enhanced background
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.palette.brandGradientStart.withValues(alpha: 0.2)
                      : widget.palette.glassSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isSelected
                        ? widget.palette.brandGradientStart
                        : widget.palette.glassBorder,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.flag,
                    style: TextStyle(
                      fontSize: 32,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Native language name
              Text(
                widget.nativeName,
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isSelected
                      ? widget.palette.brandGradientStart
                      : widget.palette.textPrimary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // English name
              Text(
                widget.englishName,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.palette.textSecondary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.isSelected) ...[
                const SizedBox(height: 8),
                // Checkmark indicator
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.palette.brandGradientStart,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: widget.palette.onAccent,
                    size: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final bool isDisabled;
  final FeedXpressoPaletteEnhanced palette;

  const AnimatedButton({
    required this.isLoading,
    required this.onPressed,
    required this.isDisabled,
    required this.palette,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 56,
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
                borderRadius: BorderRadius.circular(28),
                boxShadow: widget.isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: widget.palette.brandGradientStart
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Center(
                child: widget.isLoading
                    ? _LoadingIndicator(palette: widget.palette)
                    : Text(
                        'Continue',
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.palette.onAccent,
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

class _LoadingIndicator extends StatelessWidget {
  final FeedXpressoPaletteEnhanced palette;

  const _LoadingIndicator({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(palette.onAccent),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Loading...',
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.onAccent,
          ),
        ),
      ],
    );
  }
}