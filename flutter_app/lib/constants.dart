import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'widgets/feed/feed_xpresso_theme.dart';

export 'theme/app_palette.dart';
export 'theme/app_theme.dart';
export 'theme/app_spacing.dart';
export 'theme/app_typography.dart';
export 'theme/app_gradients.dart';
export 'theme/app_components.dart';
export 'design_system/dailyhunt/dailyhunt.dart';

class AppConstants {
  /// Default local API port — macOS Monterey+ reserves 5000 for AirPlay Receiver.
  static const int defaultApiPort = 5001;

  /// Base API URL including `/api` suffix, e.g. `https://host.com/api` or `http://127.0.0.1:5001/api`.
  static String get baseUrl {
    final v = dotenv.env['API_BASE_URL']?.trim();
    if (v != null && v.isNotEmpty) return v;
    final port = int.tryParse(dotenv.env['API_PORT'] ?? '') ?? defaultApiPort;
    final host = dotenv.env['API_HOST']?.trim().isNotEmpty == true
        ? dotenv.env['API_HOST']!.trim()
        : '127.0.0.1';
    final base = 'http://$host:$port/api';
    if (kIsWeb) return base;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:$port/api';
      default:
        return base;
    }
  }

  static String get socketUrl {
    final v = dotenv.env['SOCKET_URL']?.trim();
    if (v != null && v.isNotEmpty) return v;
    final port = int.tryParse(dotenv.env['API_PORT'] ?? '') ?? defaultApiPort;
    final host = dotenv.env['API_HOST']?.trim().isNotEmpty == true
        ? dotenv.env['API_HOST']!.trim()
        : '127.0.0.1';
    if (kIsWeb) return 'http://$host:$port';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:$port';
      default:
        return 'http://$host:$port';
    }
  }

  /// Human-readable API target for error messages (uses [baseUrl], not hardcoded port).
  static String get apiConnectionHint {
    final explicit = dotenv.env['API_BASE_URL']?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final port = int.tryParse(dotenv.env['API_PORT'] ?? '') ?? defaultApiPort;
    final host = dotenv.env['API_HOST']?.trim().isNotEmpty == true
        ? dotenv.env['API_HOST']!.trim()
        : '127.0.0.1';
    return 'http://$host:$port/api';
  }

  static String get appName => dotenv.env['APP_NAME'] ?? 'NewsNow';

  /// Public web origin for short share links (e.g. http://147.93.169.3).
  static String get shareWebBaseUrl {
    final v = dotenv.env['SHARE_WEB_BASE_URL']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.replaceAll(RegExp(r'/+$'), '');
    }
    if (kDebugMode && !kIsWeb) {
      debugPrint(
        '[config] SHARE_WEB_BASE_URL is unset — shared links may use the dev API origin.',
      );
    }
    try {
      return Uri.parse(baseUrl).origin;
    } catch (_) {
      return '';
    }
  }

  static int get pageSize =>
      int.tryParse(dotenv.env['PAGE_SIZE'] ?? '20') ?? 20;
  static int get maxMediaFiles =>
      int.tryParse(dotenv.env['MAX_MEDIA_FILES'] ?? '10') ?? 10;
  /// Must exceed server chat budget (context + Ollama + buffer); default 120s.
  static Duration get chatRequestTimeout {
    final sec = int.tryParse(dotenv.env['CHAT_CLIENT_TIMEOUT_SEC'] ?? '') ?? 120;
    return Duration(seconds: sec.clamp(60, 300));
  }
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String guestLikesKey = 'guest_likes';
  static const String guestBookmarksKey = 'guest_bookmarks';
  static const String guestCommentsKey = 'guest_comments';

  /// Ensures image URLs work across environments (HTTPS for Cloudinary, relative paths vs API host).
  static String resolveMediaUrl(String? url) {
    if (url == null) return '';
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('https://')) return u;
    if (u.startsWith('http://')) {
      // News/CDN URLs: prefer https so Android cleartext and TLS work reliably.
      final upgraded = u.replaceFirst('http://', 'https://');
      final host = Uri.tryParse(upgraded)?.host ?? '';
      if (host.isNotEmpty) return upgraded;
      return u;
    }
    try {
      final baseUri = Uri.parse(baseUrl);
      final origin = baseUri.origin;
      return u.startsWith('/') ? '$origin$u' : '$origin/$u';
    } catch (_) {
      return u;
    }
  }

  /// Headers for loading remote article images (many publishers check Referer).
  static Map<String, String> imageLoadHeaders(String? articleSourceUrl) {
    final h = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
    final ref = articleSourceUrl?.trim();
    if (ref != null && ref.isNotEmpty) {
      final uri = Uri.tryParse(ref);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        h['Referer'] = uri.toString();
      }
    }
    return h;
  }

  /// Hosts that load reliably in the app without a proxy (CDN / our media).
  static bool shouldBypassImageProxy(String resolved) {
    if (resolved.isEmpty) return false;
    if (resolved.contains('/media/ingest/')) return true;
    final host = Uri.tryParse(resolved)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host == 'res.cloudinary.com' || host.endsWith('.cloudinary.com')) {
      return true;
    }
    if (host == 'i.ytimg.com' || host == 'img.youtube.com') return true;
    try {
      final apiHost = Uri.parse(baseUrl).host.toLowerCase();
      if (host == apiHost && resolved.contains('/media/')) return true;
    } catch (_) {}
    return false;
  }

  /// Hotlinked news images often 403 from the app; load via API proxy instead (see GET /api/news/proxy-image).
  static String imageUrlForDisplay(String? rawUrl, {String? articleReferer}) {
    final resolved = resolveMediaUrl(rawUrl);
    if (resolved.isEmpty) return '';
    if (shouldBypassImageProxy(resolved)) return resolved;

    final api = Uri.parse(baseUrl);
    var path = api.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    path = '$path/news/proxy-image';

    final qp = <String, String>{'url': resolved};
    final ref = articleReferer?.trim();
    if (ref != null && ref.isNotEmpty) qp['referer'] = ref;

    return api.replace(path: path, queryParameters: qp).toString();
  }
}

// ─── Gradient Background Widget ───────────────────────────────────────────────

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.background,
      child: child,
    );
  }
}

// _Blob intentionally removed — keep backgrounds clean for production.

// ─── Glass Card ───────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
    this.boxShadow,
    double borderRadius = 16,
    double? radius,
    Color? backgroundColor,
    Color? color,
  })  : borderRadius = radius ?? borderRadius,
        backgroundColor = color ?? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? fx.glassSurface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? fx.glassBorder,
            width: 0.8,
          ),
          boxShadow: boxShadow,
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
    final fx = FeedXpressoTheme.fx(context);
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? fx.glassSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
            color: borderColor ?? fx.glassBorder, width: 0.8),
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
    final fx = FeedXpressoTheme.fx(context);
    final color = accentColor ?? fx.accent;
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
            ? Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: fx.onAccent, strokeWidth: 2)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, color: fx.onAccent, size: 18),
                  SizedBox(width: 8)
                ],
                Text(label,
                    style: TextStyle(
                        color: fx.onAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
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
    final fx = FeedXpressoTheme.fx(context);
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
      style: TextStyle(color: fx.title, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: fx.meta, fontSize: 13),
        hintStyle: TextStyle(color: fx.textHint, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? IconTheme(
                data: IconThemeData(color: fx.meta, size: 18),
                child: prefixIcon!)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fx.glassSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fx.glassBorder, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fx.glassBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fx.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fx.error, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fx.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterStyle: TextStyle(color: fx.textHint, fontSize: 11),
      ),
    );
  }
}

// ─── Glass Badge ──────────────────────────────────────────────────────────────

class GlassBadge extends StatelessWidget {
  final String label;
  final Color accentColor;
  final IconData? icon;

  const GlassBadge(
      {super.key, required this.label, required this.accentColor, this.icon});

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
        if (icon != null) ...[
          Icon(icon, size: 12, color: accentColor),
          SizedBox(width: 4)
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
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

  const GlassCategoryChip(
      {super.key,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? fx.accentSurface : fx.glassSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? fx.accentBorder : fx.glassBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          '$icon $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? fx.accentLight : fx.textSecondary,
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

  const GlassBottomNav(
      {super.key,
      required this.currentIndex,
      required this.items,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Container(
      decoration: BoxDecoration(
        color: fx.glassSurface,
        border: Border(top: BorderSide(color: fx.glassBorder, width: 0.8)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? fx.accentSurface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          selected
                              ? (item.activeIcon is Icon
                                  ? (item.activeIcon as Icon).icon
                                  : (item.icon as Icon).icon)
                              : (item.icon as Icon).icon,
                          color: selected ? fx.accentLight : fx.textHint,
                          size: 20,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        item.label ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? fx.accentLight : fx.textHint,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
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
  Size get preferredSize => Size.fromHeight(bottom != null
      ? kToolbarHeight + bottom!.preferredSize.height
      : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return AppBar(
      backgroundColor: fx.glassSurface,
      foregroundColor: fx.title,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: fx.textSecondary),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: title,
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: fx.glassSurface,
          border: Border(
              bottom: BorderSide(color: fx.glassBorder, width: 0.8)),
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

  const GlassStatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderColor: accentColor.withOpacity(0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: accentColor),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: accentColor)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: fx.textTertiary)),
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
    final fx = FeedXpressoTheme.fx(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              fx.accentSecondarySurface,
              fx.accentSecondary.withOpacity(0.08)
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fx.accentSecondaryBorder, width: 0.8),
        ),
        child: Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: fx.accentSecondary, shape: BoxShape.circle)),
          SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fx.accentSecondaryLight),
                  overflow: TextOverflow.ellipsis)),
          if (onTap != null)
            Icon(Icons.refresh,
                size: 14, color: fx.accentSecondaryLight),
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

  const GlassLocationBar(
      {super.key,
      required this.loading,
      this.locationText,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final hasLocation = locationText != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasLocation
            ? fx.accent.withOpacity(0.1)
            : fx.accentSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation ? fx.accentBorder : fx.accentSecondaryBorder,
          width: 0.8,
        ),
      ),
      child: Row(children: [
        Icon(
          loading
              ? Icons.gps_not_fixed
              : (hasLocation ? Icons.gps_fixed : Icons.location_off),
          size: 16,
          color: hasLocation ? fx.accentLight : fx.accentSecondaryLight,
        ),
        SizedBox(width: 8),
        Expanded(
          child: loading
              ? Text('Capturing GPS location...',
                  style: TextStyle(fontSize: 13, color: fx.textSecondary))
              : hasLocation
                  ? Text('📍 $locationText',
                      style: TextStyle(
                          fontSize: 13, color: fx.accentLight))
                  : Text(
                      'Location unavailable — story posted without GPS',
                      style: TextStyle(
                          fontSize: 12, color: fx.accentSecondaryLight)),
        ),
        if (!loading)
          GestureDetector(
            onTap: onRefresh,
            child: Icon(Icons.refresh, size: 16, color: fx.textTertiary),
          ),
      ]),
    );
  }
}
