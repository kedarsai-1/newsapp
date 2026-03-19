import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
  static String get socketUrl =>
      dotenv.env['SOCKET_URL'] ?? 'http://10.0.2.2:5000';
  static String get appName =>
      dotenv.env['APP_NAME'] ?? 'NewsNow';
  static int get pageSize =>
      int.tryParse(dotenv.env['PAGE_SIZE'] ?? '20') ?? 20;
  static int get maxMediaFiles =>
      int.tryParse(dotenv.env['MAX_MEDIA_FILES'] ?? '10') ?? 10;
  static bool get isDevelopment =>
      (dotenv.env['APP_ENV'] ?? 'development') == 'development';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}

// ─── Glass Design System ──────────────────────────────────────────────────────

class GlassColors {
  // Background gradients
  static const Color gradientStart  = Color(0xFF0F0C29);
  static const Color gradientMid    = Color(0xFF302B63);
  static const Color gradientEnd    = Color(0xFF24243E);

  // Blob accent colors
  static const Color blobGreen  = Color(0xFF1D9E75);
  static const Color blobPurple = Color(0xFF7F77DD);
  static const Color blobOrange = Color(0xFFD85A30);

  // Glass surface tints
  static const Color surfaceWhite   = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const Color surfaceBright  = Color(0x18FFFFFF); // rgba(255,255,255,0.10)
  static const Color borderWhite    = Color(0x21FFFFFF); // rgba(255,255,255,0.13)
  static const Color borderBright   = Color(0x2FFFFFFF); // rgba(255,255,255,0.18)

  // Text
  static const Color textPrimary    = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color(0x99FFFFFF); // 60% white
  static const Color textTertiary   = Color(0x66FFFFFF); // 40% white
  static const Color textHint       = Color(0x40FFFFFF); // 25% white

  // Accent — teal (primary action)
  static const Color accentGreen        = Color(0xFF1D9E75);
  static const Color accentGreenLight   = Color(0xFF5DCAA5);
  static const Color accentGreenSurface = Color(0x1E1D9E75); // 12%
  static const Color accentGreenBorder  = Color(0x4D1D9E75); // 30%

  // Accent — orange (breaking / admin)
  static const Color accentOrange        = Color(0xFFD85A30);
  static const Color accentOrangeLight   = Color(0xFFF0997B);
  static const Color accentOrangeSurface = Color(0x26D85A30); // 15%
  static const Color accentOrangeBorder  = Color(0x59D85A30); // 35%

  // Accent — purple (reporter badge, categories)
  static const Color accentPurple        = Color(0xFF7F77DD);
  static const Color accentPurpleLight   = Color(0xFFAFA9EC);
  static const Color accentPurpleSurface = Color(0x337F77DD);
  static const Color accentPurpleBorder  = Color(0x4D7F77DD);

  // Semantic
  static const Color success = Color(0xFF5DCAA5);
  static const Color warning = Color(0xFFF0997B);
  static const Color error   = Color(0xFFF09595);
  static const Color info    = Color(0xFF85B7EB);
}

// ─── App Theme ────────────────────────────────────────────────────────────────

class AppColors {
  static const Color primary       = GlassColors.accentGreen;
  static const Color primaryDark   = Color(0xFF0F6E56);
  static const Color accent        = GlassColors.accentOrange;
  static const Color breaking      = GlassColors.accentOrange;
  static const Color background    = GlassColors.gradientStart;
  static const Color surface       = GlassColors.surfaceWhite;
  static const Color cardBg        = GlassColors.surfaceWhite;
  static const Color textPrimary   = GlassColors.textPrimary;
  static const Color textSecondary = GlassColors.textSecondary;
  static const Color textHint      = GlassColors.textHint;
  static const Color adminBadge    = GlassColors.accentOrangeLight;
  static const Color reporterBadge = GlassColors.accentGreenLight;
  static const Color userBadge     = GlassColors.info;
  static const Color success       = GlassColors.success;
  static const Color warning       = GlassColors.warning;
  static const Color error         = GlassColors.error;
  static const Color info          = GlassColors.info;
}

// ─── Gradient Background Widget ───────────────────────────────────────────────

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlassColors.gradientStart,
            GlassColors.gradientMid,
            GlassColors.gradientEnd,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Ambient blobs
          Positioned(top: -80, left: -60, child: _Blob(size: 300, color: GlassColors.blobGreen)),
          Positioned(bottom: 80, right: -40, child: _Blob(size: 240, color: GlassColors.blobPurple)),
          Positioned(top: 280, left: 120, child: _Blob(size: 160, color: GlassColors.blobOrange)),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.35),
      ),
    );
  }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? GlassColors.borderWhite,
            width: 0.8,
          ),
        ),
        child: child,
      ),
    );
  }


}



// ─── Glass Container (simpler, no clip) ──────────────────────────────────────

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 14,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? GlassColors.surfaceWhite,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? GlassColors.borderWhite, width: 0.8),
      ),
      child: child,
    );
  }
}

// ─── Glass Button ─────────────────────────────────────────────────────────────

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final bool loading;
  final IconData? icon;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.accentColor,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? GlassColors.accentGreen;
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.55), color.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5), width: 0.8),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ]),
      ),
    );
  }
}

// ─── Glass TextField ──────────────────────────────────────────────────────────

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool readOnly;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;

  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      readOnly: readOnly,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: GlassColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(color: GlassColors.textTertiary, fontSize: 13),
        hintStyle: const TextStyle(color: GlassColors.textHint, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? IconTheme(data: const IconThemeData(color: GlassColors.textTertiary, size: 18), child: prefixIcon!)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: GlassColors.surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlassColors.borderWhite, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlassColors.borderWhite, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlassColors.accentGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GlassColors.error, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GlassColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterStyle: const TextStyle(color: GlassColors.textHint, fontSize: 11),
      ),
    );
  }
}

// ─── Glass Badge ──────────────────────────────────────────────────────────────

class GlassBadge extends StatelessWidget {
  final String label;
  final Color accentColor;
  final IconData? icon;

  const GlassBadge({super.key, required this.label, required this.accentColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: accentColor), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Glass Category Chip ──────────────────────────────────────────────────────

class GlassCategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const GlassCategoryChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GlassColors.accentGreenSurface : GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? GlassColors.accentGreenBorder : GlassColors.borderWhite,
            width: 0.8,
          ),
        ),
        child: Text(
          '$icon $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? GlassColors.accentGreenLight : GlassColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Glass Bottom Nav ─────────────────────────────────────────────────────────

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final void Function(int) onTap;

  const GlassBottomNav({super.key, required this.currentIndex, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GlassColors.surfaceWhite,
        border: Border(top: BorderSide(color: GlassColors.borderWhite, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? GlassColors.accentGreenSurface : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          selected
                              ? (item.activeIcon is Icon ? (item.activeIcon as Icon).icon : (item.icon as Icon).icon)
                              : (item.icon as Icon).icon,
                          color: selected ? GlassColors.accentGreenLight : GlassColors.textHint,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? GlassColors.accentGreenLight : GlassColors.textHint,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Glass AppBar ─────────────────────────────────────────────────────────────

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? kToolbarHeight + bottom!.preferredSize.height : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: GlassColors.surfaceWhite,
      foregroundColor: GlassColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: GlassColors.textSecondary),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: title,
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: GlassColors.surfaceWhite,
          border: Border(bottom: BorderSide(color: GlassColors.borderWhite, width: 0.8)),
        ),
      ),
    );
  }
}

// ─── Glass Stat Card ──────────────────────────────────────────────────────────

class GlassStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const GlassStatCard({super.key, required this.label, required this.value, required this.icon, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderColor: accentColor.withOpacity(0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: accentColor),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: GlassColors.textTertiary)),
      ]),
    );
  }
}

// ─── Glass Breaking Banner ────────────────────────────────────────────────────

class GlassBreakingBanner extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const GlassBreakingBanner({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [GlassColors.accentOrangeSurface, GlassColors.accentOrange.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GlassColors.accentOrangeBorder, width: 0.8),
        ),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: GlassColors.accentOrange, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassColors.accentOrangeLight), overflow: TextOverflow.ellipsis)),
          if (onTap != null) const Icon(Icons.refresh, size: 14, color: GlassColors.accentOrangeLight),
        ]),
      ),
    );
  }
}

// ─── Glass Location Bar ───────────────────────────────────────────────────────

class GlassLocationBar extends StatelessWidget {
  final bool loading;
  final String? locationText;
  final VoidCallback onRefresh;

  const GlassLocationBar({super.key, required this.loading, this.locationText, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final hasLocation = locationText != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasLocation ? GlassColors.accentGreen.withOpacity(0.1) : GlassColors.accentOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation ? GlassColors.accentGreenBorder : GlassColors.accentOrangeBorder,
          width: 0.8,
        ),
      ),
      child: Row(children: [
        Icon(
          loading ? Icons.gps_not_fixed : (hasLocation ? Icons.gps_fixed : Icons.location_off),
          size: 16,
          color: hasLocation ? GlassColors.accentGreenLight : GlassColors.accentOrangeLight,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: loading
              ? const Text('Capturing GPS location...', style: TextStyle(fontSize: 13, color: GlassColors.textSecondary))
              : hasLocation
                  ? Text('📍 $locationText', style: const TextStyle(fontSize: 13, color: GlassColors.accentGreenLight))
                  : const Text('Location unavailable — story posted without GPS', style: TextStyle(fontSize: 12, color: GlassColors.accentOrangeLight)),
        ),
        if (!loading)
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh, size: 16, color: GlassColors.textTertiary),
          ),
      ]),
    );
  }
}

// ─── Full App Theme ───────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GlassColors.gradientStart,
    colorScheme: ColorScheme.dark(
      primary: GlassColors.accentGreen,
      secondary: GlassColors.accentPurple,
      surface: GlassColors.surfaceWhite,
      onPrimary: Colors.white,
      onSurface: GlassColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GlassColors.surfaceWhite,
      foregroundColor: GlassColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: GlassColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GlassColors.accentGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: GlassColors.accentGreenLight,
      unselectedItemColor: GlassColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: GlassColors.surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GlassColors.borderWhite, width: 0.8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GlassColors.surfaceWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GlassColors.borderWhite)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GlassColors.borderWhite, width: 0.8)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GlassColors.accentGreen, width: 1.5)),
      labelStyle: const TextStyle(color: GlassColors.textTertiary),
      hintStyle: const TextStyle(color: GlassColors.textHint),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: GlassColors.textPrimary),
      bodyMedium: TextStyle(color: GlassColors.textPrimary),
      bodySmall: TextStyle(color: GlassColors.textSecondary),
    ),
    iconTheme: const IconThemeData(color: GlassColors.textSecondary),
    dividerTheme: const DividerThemeData(color: GlassColors.borderWhite, thickness: 0.8),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF2A2750),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: GlassColors.borderWhite, width: 0.8)),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF2A2750),
      shape: RoundedRectangleBorder(),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: GlassColors.accentGreenLight,
      unselectedLabelColor: GlassColors.textTertiary,
      indicatorColor: GlassColors.accentGreen,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GlassColors.accentGreen : Colors.transparent),
      side: const BorderSide(color: GlassColors.borderBright, width: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2A2750),
      contentTextStyle: const TextStyle(color: GlassColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}