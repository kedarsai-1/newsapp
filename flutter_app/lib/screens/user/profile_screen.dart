import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/news_provider.dart';
import '../../providers/onboarding_draft_provider.dart';
import '../../providers/reporter_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/push_notifications.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _translatedCacheKey = 'feed_translated_summary_cache_v1';

  bool _breakingAlerts = true;
  bool _dailyDigest = true;
  bool _recommendedAlerts = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _editProfile(BuildContext context, String currentName) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: currentName);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => _EditProfileSheet(
        controller: controller,
        fx: FeedXpressoTheme.fx(context),
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final ok = await context.read<AuthProvider>().updateProfile(name: result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated' : 'Could not update profile'),
        behavior: SnackBarBehavior.floating,
        width: 280,
      ),
    );
  }

  Future<void> _syncPushTopics() async {
    final lang = context.read<NewsProvider>().selectedLanguage;
    await PushNotifications.applyTopics(
      PushNotifications.topicsForLanguage(
        lang,
        dailyDigest: _dailyDigest,
        breakingAlerts: _breakingAlerts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);
    final user = context.watch<AuthProvider>().user;
    final newsProvider = context.watch<NewsProvider>();
    final seenCount = newsProvider.seenPostCount;
    final savedCount = newsProvider.savedCount;
    final topicsCount = newsProvider.categories.length;

    return Scaffold(
      backgroundColor: fx.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            toolbarHeight: 52,
            backgroundColor: fx.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 0,
            foregroundColor: fx.title,
            title: Text(
              'Profile',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: fx.title,
              ),
            ),
            actions: [
              Semantics(
                label: 'Open privacy policy',
                button: true,
                child: IconButton(
                  tooltip: 'Privacy policy',
                  onPressed: () => context.push('/privacy-policy'),
                  icon: Icon(Icons.policy_outlined, color: fx.iconFg, size: 22),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: fx.divider),
            ),
          ),

          // ── Profile Card ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileCard(
              user: user,
              fx: fx,
              seenCount: seenCount,
              savedCount: savedCount,
              topicsCount: topicsCount,
              onEdit: () => _editProfile(context, user?.name ?? ''),
              onSignIn: () => context.push('/login'),
              onSignOut: () async {
                final auth = context.read<AuthProvider>();
                await auth.logout();
                context.read<ReporterProvider>().reset();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ),

          // ── Quick Actions Grid ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _QuickActionsGrid(
                fx: fx,
                onSaved: () => context.go('/bookmarks'),
                onHistory: () => context.push('/history'),
                onCategories: () => context.go('/categories'),
                onLanguage: () => context.push('/language'),
              ),
            ),
          ),

          // ── Settings Tabs ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: fx.glassSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: fx.glassBorder, width: 1),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  indicator: BoxDecoration(
                    color: fx.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: fx.textSecondary,
                  labelStyle: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: 'General'),
                    Tab(text: 'Content'),
                    Tab(text: 'About'),
                  ],
                ),
              ),
            ),
          ),

          // ── Tab Content ───────────────────────────────────────
          // Render active tab in the main scroll view so all settings
          // (including notifications) remain reachable on every screen size.
          SliverToBoxAdapter(
            child: _buildActiveTabContent(fx),
          ),

          // Bottom spacer
          SliverToBoxAdapter(
            child: SizedBox(height: bottomInset + 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(dynamic fx) {
    switch (_tabController.index) {
      case 1:
        return _ContentTab(
          fx: fx,
          onReplayOnboarding: () async {
            context.read<OnboardingDraftProvider>().reset();
            await context.read<NewsProvider>().resetOnboarding();
            if (!context.mounted) return;
            context.go('/onboarding/language');
          },
          onClearCache: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_translatedCacheKey);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(I18n.t(context, 'snack_translated_cleared')),
                behavior: SnackBarBehavior.floating,
                width: 280,
                duration: const Duration(milliseconds: 1200),
              ),
            );
          },
        );
      case 2:
        return _AboutTab(fx: fx);
      case 0:
      default:
        return _GeneralTab(
          fx: fx,
          breakingAlerts: _breakingAlerts,
          dailyDigest: _dailyDigest,
          recommendedAlerts: _recommendedAlerts,
          onBreakingChanged: (v) async {
            setState(() => _breakingAlerts = v);
            await _syncPushTopics();
          },
          onDailyDigestChanged: (v) async {
            setState(() => _dailyDigest = v);
            await _syncPushTopics();
          },
          onRecommendedChanged: (v) => setState(() => _recommendedAlerts = v),
        );
    }
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final dynamic user;
  final dynamic fx;
  final int seenCount;
  final int savedCount;
  final int topicsCount;
  final VoidCallback onEdit;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  const _ProfileCard({
    required this.user,
    required this.fx,
    required this.seenCount,
    required this.savedCount,
    required this.topicsCount,
    required this.onEdit,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = user != null;
    final name = user?.name ?? 'Guest User';
    final email = user?.email ?? 'Sign in to sync across devices';
    final initials = AppUtils.initials(name);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fx.accent,
            fx.accent.withValues(alpha: 0.65),
            fx.accentTertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: fx.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Watermark
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.person_rounded,
                size: 120, color: Colors.white.withValues(alpha: 0.07)),
          ),
          Positioned(
            left: -10,
            top: -10,
            child: Icon(Icons.grid_view_rounded,
                size: 80, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Semantics(
                      label: isLoggedIn ? 'Edit profile avatar' : 'Guest avatar',
                      button: isLoggedIn,
                      child: GestureDetector(
                        onTap: isLoggedIn ? onEdit : null,
                        child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoggedIn
                              ? Text(
                                  initials,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 28,
                                ),
                        ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit / Sign In button
                    if (isLoggedIn)
                      _ProfileActionBtn(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        onTap: onEdit,
                      )
                    else
                      _ProfileActionBtn(
                        icon: Icons.login_rounded,
                        label: 'Sign in',
                        onTap: onSignIn,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                // Stats row
                Row(
                  children: [
                    _ProfileStat(
                      value: '$seenCount',
                      label: 'Read',
                      icon: Icons.auto_stories_rounded,
                    ),
                    _ProfileStat(
                      value: '$savedCount',
                      label: 'Saved',
                      icon: Icons.bookmark_rounded,
                    ),
                    _ProfileStat(
                      value: '$topicsCount',
                      label: 'Topics',
                      icon: Icons.category_rounded,
                    ),
                    if (isLoggedIn)
                      _ProfileStat(
                        value: '0',
                        label: 'Reports',
                        icon: Icons.article_rounded,
                      ),
                  ],
                ),
                if (isLoggedIn) ...[
                  const SizedBox(height: 16),
                  // Sign out button
                  Semantics(
                    label: 'Sign out',
                    hint: 'Double tap to sign out',
                    button: true,
                    child: GestureDetector(
                      onTap: onSignOut,
                      child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Sign out',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ProfileActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: filled ? 0.3 : 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: filled
                  ? const Color(0xFF6366F1)
                  : Colors.white.withValues(alpha: 0.9),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ProfileStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Actions Grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final dynamic fx;
  final VoidCallback onSaved;
  final VoidCallback onHistory;
  final VoidCallback onCategories;
  final VoidCallback onLanguage;

  const _QuickActionsGrid({
    required this.fx,
    required this.onSaved,
    required this.onHistory,
    required this.onCategories,
    required this.onLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.bookmark_rounded,
        label: 'Saved',
        color: const Color(0xFF6366F1),
        onTap: onSaved,
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'History',
        color: const Color(0xFF10B981),
        onTap: onHistory,
      ),
      _QuickAction(
        icon: Icons.category_rounded,
        label: 'Categories',
        color: const Color(0xFFF59E0B),
        onTap: onCategories,
      ),
      _QuickAction(
        icon: Icons.language_rounded,
        label: 'Language',
        color: const Color(0xFFEC4899),
        onTap: onLanguage,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 720 ? 4 : 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _QuickActionCard(action: action, fx: fx);
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatefulWidget {
  final _QuickAction action;
  final dynamic fx;

  const _QuickActionCard({required this.action, required this.fx});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.action.label,
      hint: 'Double tap to ${widget.action.label.toLowerCase()}',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.action.onTap,
        child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.95 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: widget.fx.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.fx.glassBorder.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.action.color.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.action.color,
                      widget.action.color.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.action.color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.action.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.action.label,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.fx.title,
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

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────

class _EditProfileSheet extends StatelessWidget {
  final TextEditingController controller;
  final dynamic fx;

  const _EditProfileSheet({
    required this.controller,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 120),
      decoration: BoxDecoration(
        color: fx.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: fx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Edit Profile',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: fx.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Update your display name',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: fx.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.notoSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: fx.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Display name',
                labelStyle: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fx.textSecondary,
                ),
                filled: true,
                fillColor: fx.glassSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: fx.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: fx.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: fx.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: fx.divider),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fx.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: fx.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── General Tab ─────────────────────────────────────────────────────────────

class _GeneralTab extends StatelessWidget {
  final dynamic fx;
  final bool breakingAlerts;
  final bool dailyDigest;
  final bool recommendedAlerts;
  final ValueChanged<bool> onBreakingChanged;
  final ValueChanged<bool> onDailyDigestChanged;
  final ValueChanged<bool> onRecommendedChanged;

  const _GeneralTab({
    required this.fx,
    required this.breakingAlerts,
    required this.dailyDigest,
    required this.recommendedAlerts,
    required this.onBreakingChanged,
    required this.onDailyDigestChanged,
    required this.onRecommendedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final news = context.watch<NewsProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Theme
          _SettingsCard(
            fx: fx,
            title: 'Appearance',
            icon: Icons.palette_rounded,
            iconColor: const Color(0xFF6366F1),
            children: [
              _SegmentedRow(
                label: 'Theme',
                segments: [
                  ('Light', Icons.light_mode_outlined),
                  ('Dark', Icons.dark_mode_outlined),
                  ('Auto', Icons.brightness_auto_outlined),
                ],
                selectedIndex: theme.themeMode == ThemeMode.light
                    ? 0
                    : theme.themeMode == ThemeMode.dark
                        ? 1
                        : 2,
                onChanged: (i) {
                  theme.setThemeMode(
                    i == 0
                        ? ThemeMode.light
                        : i == 1
                            ? ThemeMode.dark
                            : ThemeMode.system,
                  );
                },
                fx: fx,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Language
          _SettingsCard(
            fx: fx,
            title: 'Language',
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF10B981),
            children: [
              _LanguageSelector(
                selectedLanguage: news.selectedLanguage,
                onChanged: (lang) => news.selectLanguage(lang),
                fx: fx,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notifications
          _SettingsCard(
            fx: fx,
            title: 'Notifications',
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFF59E0B),
            showDivider: false,
            children: [
              _ToggleRow(
                label: 'Breaking news alerts',
                subtitle: 'Get notified about urgent stories',
                value: breakingAlerts,
                onChanged: onBreakingChanged,
                fx: fx,
              ),
              _ToggleRow(
                label: 'Daily digest',
                subtitle: 'Morning summary of top stories',
                value: dailyDigest,
                onChanged: onDailyDigestChanged,
                fx: fx,
              ),
              _ToggleRow(
                label: 'Recommended stories',
                subtitle: 'Based on your interests',
                value: recommendedAlerts,
                onChanged: onRecommendedChanged,
                fx: fx,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Content Tab ─────────────────────────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final dynamic fx;
  final VoidCallback onReplayOnboarding;
  final VoidCallback onClearCache;

  const _ContentTab({
    required this.fx,
    required this.onReplayOnboarding,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SettingsCard(
            fx: fx,
            title: 'Content Preferences',
            icon: Icons.tune_rounded,
            iconColor: const Color(0xFFEC4899),
            children: [
              _SettingsRow(
                label: 'Replay onboarding',
                subtitle: 'Reset language, interests & notifications',
                icon: Icons.tour_rounded,
                iconColor: const Color(0xFF8B5CF6),
                onTap: onReplayOnboarding,
                fx: fx,
              ),
              _SettingsRow(
                label: 'Layout mode',
                subtitle: 'Choose how articles are displayed',
                icon: Icons.view_quilt_rounded,
                iconColor: const Color(0xFF06B6D4),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: fx.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Carousel',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fx.accent,
                    ),
                  ),
                ),
                onTap: () => context.push('/layout-mode'),
                fx: fx,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            fx: fx,
            title: 'Storage & Data',
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFF64748B),
            showDivider: false,
            children: [
              _SettingsRow(
                label: 'Clear translated cache',
                subtitle: 'Remove cached article translations',
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFFEF4444),
                onTap: onClearCache,
                fx: fx,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── About Tab ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final dynamic fx;

  const _AboutTab({required this.fx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SettingsCard(
            fx: fx,
            title: 'About',
            icon: Icons.info_rounded,
            iconColor: const Color(0xFF6366F1),
            children: [
              _SettingsRow(
                label: 'Version',
                subtitle: 'App version and build info',
                icon: Icons.new_releases_rounded,
                iconColor: const Color(0xFF10B981),
                trailing: Text(
                  '1.0.0',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fx.textSecondary,
                  ),
                ),
                onTap: null,
                fx: fx,
              ),
              _SettingsRow(
                label: 'Privacy policy',
                subtitle: 'How we handle your data',
                icon: Icons.privacy_tip_rounded,
                iconColor: const Color(0xFF8B5CF6),
                onTap: () => context.push('/privacy-policy'),
                fx: fx,
              ),
              _SettingsRow(
                label: 'Terms of service',
                subtitle: 'Usage terms and conditions',
                icon: Icons.description_rounded,
                iconColor: const Color(0xFFF59E0B),
                onTap: () => context.push('/terms-of-service'),
                fx: fx,
              ),
              _SettingsRow(
                label: 'Open source licenses',
                subtitle: 'Third-party libraries we use',
                icon: Icons.code_rounded,
                iconColor: const Color(0xFF64748B),
                showDivider: false,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'NewsApp',
                  applicationVersion: '1.0.0',
                ),
                fx: fx,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            fx: fx,
            title: 'Support',
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF14B8A6),
            showDivider: false,
            children: [
              _SettingsRow(
                label: 'Contact us',
                subtitle: 'Help, feedback & suggestions',
                icon: Icons.email_rounded,
                iconColor: const Color(0xFF6366F1),
                showDivider: false,
                onTap: () => context.push('/contact'),
                fx: fx,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Settings Card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final dynamic fx;
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final bool showDivider;

  const _SettingsCard({
    required this.fx,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fx.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: fx.title,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, thickness: 0.5, color: fx.divider),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final dynamic fx;
  final bool showDivider;

  const _SettingsRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trailing,
    this.onTap,
    required this.fx,
    this.showDivider = true,
  });

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isTapable = widget.onTap != null;
    final hint = 'Double tap to open ${
      widget.label.toLowerCase()
    }';

    return Semantics(
      label: widget.label,
      hint: hint,
      button: isTapable,
      child: GestureDetector(
        onTapDown: isTapable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isTapable ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: isTapable ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.fx.glassBorder.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon,
                  color: widget.iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.fx.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      color: widget.fx.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
            if (isTapable && widget.trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                color: widget.fx.iconFgMuted,
                size: 20,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final dynamic fx;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fx.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    color: fx.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Semantics(
              label: label,
              hint: 'Double tap to toggle $label',
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: fx.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Language Selector ────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onChanged;
  final dynamic fx;

  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onChanged,
    required this.fx,
  });

  static const _languages = [
    ('en', 'English', '🇬🇧'),
    ('hi', 'हिंदी', '🇮🇳'),
    ('te', 'తెలుగు', '🇮🇳'),
    ('ta', 'தமிழ்', '🇮🇳'),
    ('kn', 'ಕನ್ನಡ', '🇮🇳'),
    ('bn', 'বাংলা', '🇮🇳'),
    ('ml', 'മലയാളം', '🇮🇳'),
    ('all', 'All Languages', '🌐'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _languages.map((lang) {
          final (code, name, flag) = lang;
          final isSelected = selectedLanguage == code;
          return Semantics(
            label: name,
            hint: 'Double tap to select $name',
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(code),
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? fx.accent
                    : fx.glassBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? fx.accent
                      : fx.glassBorder,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: fx.accent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : fx.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Segmented Row ────────────────────────────────────────────────────────────

class _SegmentedRow extends StatelessWidget {
  final String label;
  final List<(String, IconData)> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final dynamic fx;

  const _SegmentedRow({
    required this.label,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fx.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: fx.glassBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: segments.asMap().entries.map((entry) {
                final idx = entry.key;
                final (label, icon) = entry.value;
                final isSelected = idx == selectedIndex;
                return Expanded(
                  child: Semantics(
                    label: label,
                    hint: 'Double tap to select $label',
                    button: true,
                    child: GestureDetector(
                      onTap: () => onChanged(idx),
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? fx.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: fx.accent.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : fx.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : fx.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
