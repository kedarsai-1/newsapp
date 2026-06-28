import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import 'xpresso_menu_scope.dart';

/// Dailyhunt Xpresso slide-out menu — matte surfaces, active-route indicators,
/// branded header, and role-aware destinations.
class XpressoSideMenu extends StatelessWidget {
  const XpressoSideMenu({super.key});

  static const double _minWidth = 280;
  static const double _maxWidth = 340;
  static const double _widthFactor = 0.78;
  static const String _appVersion = '1.0.0';

  static void open(BuildContext context) => XpressoMenuScope.open(context);

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final loc = GoRouterState.of(context).matchedLocation;
    final auth = context.watch<AuthProvider>();
    final screenW = MediaQuery.sizeOf(context).width;
    final width = (screenW * _widthFactor).clamp(_minWidth, _maxWidth);

    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: fx.background,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuHeader(
              fx: fx,
              user: auth.user,
              isLoggedIn: auth.isLoggedIn,
              onClose: () => _close(context),
              onSignIn: () => _go(context, '/login'),
              onProfileTap: () => _go(context, '/settings'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                children: [
                  _MenuSection(
                    label: I18n.t(context, 'menu_discover'),
                    children: [
                      _XpressoMenuTile(
                        label: I18n.t(context, 'menu_quick_news'),
                        icon: Icons.flash_on_outlined,
                        selectedIcon: Icons.flash_on_rounded,
                        route: '/quick-news',
                        currentLocation: loc,
                        onTap: () => _go(context, '/quick-news'),
                      ),
                      _XpressoMenuTile(
                        label: I18n.t(context, 'feed_trending'),
                        icon: Icons.trending_up_outlined,
                        selectedIcon: Icons.trending_up_rounded,
                        route: '/trending',
                        currentLocation: loc,
                        onTap: () => _go(context, '/trending'),
                      ),
                      _XpressoMenuTile(
                        label: I18n.t(context, 'menu_political_reels'),
                        icon: Icons.account_balance_outlined,
                        selectedIcon: Icons.account_balance_rounded,
                        route: '/political-reels',
                        currentLocation: loc,
                        onTap: () => _go(context, '/political-reels'),
                      ),
                      _XpressoMenuTile(
                        label: I18n.t(context, 'menu_sports'),
                        icon: Icons.sports_cricket_outlined,
                        selectedIcon: Icons.sports_cricket_rounded,
                        route: '/sports',
                        currentLocation: loc,
                        onTap: () => _go(context, '/sports'),
                      ),
                      _XpressoMenuTile(
                        label: I18n.t(context, 'menu_leaderboard'),
                        icon: Icons.emoji_events_outlined,
                        selectedIcon: Icons.emoji_events_rounded,
                        route: '/sports/leaderboard',
                        currentLocation: loc,
                        onTap: () => _go(context, '/sports/leaderboard'),
                      ),
                      _XpressoMenuTile(
                        label: I18n.t(context, 'menu_ai_chat'),
                        icon: Icons.auto_awesome_rounded,
                        selectedIcon: Icons.auto_awesome,
                        route: '/ai-chat',
                        currentLocation: loc,
                        onTap: () => _go(context, '/ai-chat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _MenuSection(
                    label: I18n.t(context, 'section_account'),
                    children: [
                      _XpressoMenuTile(
                        label: I18n.t(context, 'tile_privacy_policy'),
                        icon: Icons.privacy_tip_outlined,
                        selectedIcon: Icons.privacy_tip_rounded,
                        route: '/privacy-policy',
                        currentLocation: loc,
                        onTap: () => _go(context, '/privacy-policy'),
                      ),
                      if (auth.isReporter)
                        _XpressoMenuTile(
                          label: I18n.t(context, 'reporter_hub_title'),
                          icon: Icons.edit_note_outlined,
                          selectedIcon: Icons.edit_note_rounded,
                          route: '/reporter',
                          currentLocation: loc,
                          accent: fx.accentTertiary,
                          onTap: () => _go(context, '/reporter'),
                        ),
                      if (auth.isAdmin)
                        _XpressoMenuTile(
                          label: I18n.t(context, 'tab_dashboard'),
                          icon: Icons.dashboard_outlined,
                          selectedIcon: Icons.dashboard_rounded,
                          route: '/admin',
                          currentLocation: loc,
                          accent: fx.accentSecondary,
                          onTap: () => _go(context, '/admin'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _MenuFooter(
              fx: fx,
              version: _appVersion,
              onPrivacyTap: () => _go(context, '/privacy-policy'),
            ),
          ],
        ),
      ),
    );
  }

  static void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static void _go(BuildContext context, String route) {
    _close(context);
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc != route) {
      context.go(route);
    }
  }

  static bool isRouteActive(String current, String route) => current == route;
}

class _MenuHeader extends StatelessWidget {
  final FeedXpressoPalette fx;
  final User? user;
  final bool isLoggedIn;
  final VoidCallback onClose;
  final VoidCallback onSignIn;
  final VoidCallback onProfileTap;

  const _MenuHeader({
    required this.fx,
    required this.user,
    required this.isLoggedIn,
    required this.onClose,
    required this.onSignIn,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: fx.glassBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: fx.heroShadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _BrandMark(fx: fx),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fx.screenTitleStyle.copyWith(
                      fontSize: 17,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: fx.iconFgMuted, size: 22),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoggedIn && user != null)
              _LoggedInProfile(
                fx: fx,
                name: user!.name,
                subtitle: _profileSubtitle(user!),
                onTap: onProfileTap,
              )
            else
              _GuestCta(fx: fx, onSignIn: onSignIn),
          ],
        ),
      ),
    );
  }

  static String _profileSubtitle(User user) {
    final email = user.email.trim();
    if (email.isNotEmpty) return email;
    final phone = user.phone?.trim() ?? '';
    if (phone.isNotEmpty) return phone;
    return '';
  }
}

class _BrandMark extends StatelessWidget {
  final FeedXpressoPalette fx;

  const _BrandMark({required this.fx});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fx.accent.withValues(alpha: 0.35),
            fx.iconSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: fx.accent.withValues(alpha: 0.45), width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.article_rounded, color: fx.accent, size: 18),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fx.navActiveIndicator,
                shape: BoxShape.circle,
                border: Border.all(color: fx.glassSurface, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedInProfile extends StatelessWidget {
  final FeedXpressoPalette fx;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _LoggedInProfile({
    required this.fx,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: fx.accentSurface,
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: fx.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: fx.title,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: fx.meta,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fx.iconFgMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _GuestCta extends StatelessWidget {
  final FeedXpressoPalette fx;
  final VoidCallback onSignIn;

  const _GuestCta({required this.fx, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.t(context, 'profile_guest_title'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: fx.title,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          I18n.t(context, 'profile_guest_subtitle'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: fx.meta,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onSignIn();
            },
            style: FilledButton.styleFrom(
              backgroundColor: fx.accent,
              foregroundColor: fx.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              I18n.t(context, 'action_signin'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const _MenuSection({this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Container(
      decoration: BoxDecoration(
        color: fx.surfaceElevated.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fx.divider.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) _SectionLabel(label: label!, fx: fx),
          ...children,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final FeedXpressoPalette fx;

  const _SectionLabel({required this.label, required this.fx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fx.iconFgMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _XpressoMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final String currentLocation;
  final VoidCallback onTap;
  final Color? accent;

  const _XpressoMenuTile({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.currentLocation,
    required this.onTap,
    this.accent,
  });

  bool get _selected => XpressoSideMenu.isRouteActive(currentLocation, route);

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final selected = _selected;
    final accentColor = accent ?? fx.accent;
    final iconColor = selected ? accentColor : (accent ?? fx.iconFg);
    final labelColor = selected ? fx.title : fx.title.withValues(alpha: 0.88);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          decoration: BoxDecoration(
            color: selected ? fx.accentSurface.withValues(alpha: 0.65) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: selected ? 28 : 0,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: selected ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor.withValues(alpha: 0.14)
                      : fx.iconSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? accentColor.withValues(alpha: 0.28)
                        : fx.divider.withValues(alpha: 0.45),
                    width: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.25,
                    color: labelColor,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: FeedXpressoTheme.navIndicatorWidth,
                  height: FeedXpressoTheme.navIndicatorHeight,
                  decoration: BoxDecoration(
                    color: fx.navActiveIndicator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuFooter extends StatelessWidget {
  final FeedXpressoPalette fx;
  final String version;
  final VoidCallback onPrivacyTap;

  const _MenuFooter({
    required this.fx,
    required this.version,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 0.5, color: fx.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ThemeModeChip(fx: fx, themeMode: theme.themeMode),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    I18n.t(context, 'menu_version').replaceAll('{v}', version),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: fx.iconFgMuted,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onPrivacyTap();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: fx.accent,
                    ),
                    child: Text(
                      I18n.t(context, 'tile_privacy_policy'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  final FeedXpressoPalette fx;
  final ThemeMode themeMode;

  const _ThemeModeChip({required this.fx, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fx.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _ThemeChipButton(
            fx: fx,
            label: I18n.t(context, 'appearance_light'),
            icon: Icons.light_mode_outlined,
            selected: themeMode == ThemeMode.light,
            onTap: () => context.read<ThemeProvider>().setThemeMode(ThemeMode.light),
          ),
          _ThemeChipButton(
            fx: fx,
            label: I18n.t(context, 'appearance_dark'),
            icon: Icons.dark_mode_outlined,
            selected: themeMode == ThemeMode.dark,
            onTap: () => context.read<ThemeProvider>().setThemeMode(ThemeMode.dark),
          ),
          _ThemeChipButton(
            fx: fx,
            label: I18n.t(context, 'appearance_auto'),
            icon: Icons.brightness_auto_outlined,
            selected: themeMode == ThemeMode.system,
            onTap: () => context.read<ThemeProvider>().setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _ThemeChipButton extends StatelessWidget {
  final FeedXpressoPalette fx;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChipButton({
    required this.fx,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: fx.accent.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? fx.accentSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? fx.accent : fx.iconFgMuted,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? fx.accent : fx.iconFgMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
