import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';
import '../../providers/theme_provider.dart';
import '../../utils/i18n.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(I18n.t(context, 'settings_title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, size: 56, color: p.textHint),
                const SizedBox(height: 12),
                Text(
                  I18n.t(context, 'signin_access_settings'),
                  style: TextStyle(color: p.textSecondary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: Text(I18n.t(context, 'action_signin')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(I18n.t(context, 'settings_title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          24 + MediaQuery.of(context).padding.bottom + 84,
        ),
        children: [
          Center(child: Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: p.primary,
              child: Text(AppUtils.initials(user.name), style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: p.glassSurface, shape: BoxShape.circle, border: Border.all(color: p.cardBorder)),
              child: Icon(Icons.camera_alt_outlined, size: 16, color: p.textSecondary),
            ),
          ])),
          const SizedBox(height: 14),
          Center(child: Text(user.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: p.textPrimary))),
          Center(child: Text(user.email, style: TextStyle(color: p.textSecondary, fontSize: 14))),
          const SizedBox(height: 8),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: AppUtils.roleColor(user.role).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppUtils.roleIcon(user.role), size: 14, color: AppUtils.roleColor(user.role)),
              const SizedBox(width: 6),
              Text(user.role[0].toUpperCase() + user.role.substring(1),
                  style: TextStyle(fontSize: 13, color: AppUtils.roleColor(user.role), fontWeight: FontWeight.w600)),
            ]),
          )),
          const SizedBox(height: 32),

          _SectionHeader(I18n.t(context, 'section_account')),
          _ProfileTile(icon: Icons.person_outline, title: I18n.t(context, 'tile_edit_profile'), onTap: () {}),
          _ProfileTile(icon: Icons.lock_outline, title: I18n.t(context, 'tile_change_password'), onTap: () {}),
          _ProfileTile(icon: Icons.notifications_outlined, title: I18n.t(context, 'tile_notification_prefs'), onTap: () {}),
          if (user.role == 'user')
            _ProfileTile(
              icon: Icons.mic_none_rounded,
              title: I18n.t(context, 'tile_become_reporter'),
              onTap: () async {
                final confirmed = await AppUtils.confirm(
                  context,
                  title: I18n.t(context, 'tile_become_reporter'),
                  message:
                      I18n.t(context, 'become_reporter_msg'),
                  confirmLabel: I18n.t(context, 'confirm_continue'),
                  confirmColor: p.accentPurple,
                );
                if (!confirmed || !context.mounted) return;
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                context.go('/register?role=reporter');
              },
            ),

          const SizedBox(height: 16),
          _SectionHeader(I18n.t(context, 'section_appearance')),
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: p.glassSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.cardBorder, width: 0.5)),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto, size: 18)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {theme.themeMode},
                  onSelectionChanged: (Set<ThemeMode> s) {
                    if (s.isNotEmpty) theme.setThemeMode(s.first);
                  },
                  emptySelectionAllowed: false,
                  showSelectedIcon: false,
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          _SectionHeader(I18n.t(context, 'section_app')),
          _ProfileTile(icon: Icons.info_outline, title: I18n.t(context, 'tile_about'), onTap: () {}),
          _ProfileTile(icon: Icons.help_outline, title: I18n.t(context, 'tile_help_support'), onTap: () {}),
          _ProfileTile(
            icon: Icons.privacy_tip_outlined,
            title: I18n.t(context, 'tile_privacy_policy'),
            onTap: () => context.push('/privacy-policy'),
          ),
          _ProfileTile(
            icon: Icons.cleaning_services_outlined,
            title: I18n.t(context, 'tile_clear_cache'),
            subtitle: I18n.t(context, 'tile_clear_cache_sub'),
            onTap: () async {
              final confirmed = await AppUtils.confirm(
                context,
                title: I18n.t(context, 'confirm_clear_cache_title'),
                message: I18n.t(context, 'confirm_clear_cache_msg'),
                confirmLabel: I18n.t(context, 'confirm_continue'),
                confirmColor: p.accentOrange,
              );
              if (!confirmed || !context.mounted) return;

              // Clear in-memory decoded image cache.
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();

              // Clear disk cache used by cached_network_image.
              await DefaultCacheManager().emptyCache();

              // Clear guest-only caches (but keep auth + language preference).
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(AppConstants.guestLikesKey);
              await prefs.remove(AppConstants.guestBookmarksKey);
              await prefs.remove(AppConstants.guestCommentsKey);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t(context, 'snack_cache_cleared'))),
              );
            },
          ),

          const SizedBox(height: 16),
          _SectionHeader(I18n.t(context, 'section_account_status')),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(color: p.glassSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.cardBorder, width: 0.5)),
            child: ListTile(
              leading: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: user.isActive ? p.success : p.error, shape: BoxShape.circle),
              ),
              title: Text(user.isActive ? 'Active' : 'Suspended', style: TextStyle(color: user.isActive ? p.success : p.error, fontWeight: FontWeight.w500)),
              trailing: Text('ID: ${user.id.substring(user.id.length - 6)}', style: TextStyle(fontSize: 11, color: p.textHint)),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final confirmed = await AppUtils.confirm(
                context,
                title: I18n.t(context, 'confirm_signout_title'),
                message: I18n.t(context, 'confirm_signout_msg'),
                confirmLabel: I18n.t(context, 'action_signout'),
                confirmColor: p.error,
              );
              if (confirmed && context.mounted) {
                await context.read<AuthProvider>().logout();
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(
              I18n.t(context, 'action_signout'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: p.error.withValues(alpha: 0.92),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('NewsNow v1.0.0', style: TextStyle(fontSize: 12, color: p.textHint))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary, letterSpacing: 0.5)),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: p.glassSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.cardBorder, width: 0.5)),
      child: ListTile(
        leading: Icon(icon, color: p.textSecondary, size: 20),
        title: Text(title, style: TextStyle(fontSize: 14, color: p.textPrimary)),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: p.textHint),
              ),
        trailing: Icon(Icons.chevron_right, color: p.textHint, size: 20),
        onTap: onTap,
      ),
    );
  }
}
