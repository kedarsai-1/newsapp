import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Avatar
          Center(child: Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary,
              child: Text(AppUtils.initials(user.name), style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E5E5))),
              child: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.textSecondary),
            ),
          ])),
          const SizedBox(height: 14),
          Center(child: Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
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

          // Account section
          _SectionHeader('Account'),
          _ProfileTile(icon: Icons.person_outline, title: 'Edit Profile', onTap: () {}),
          _ProfileTile(icon: Icons.lock_outline, title: 'Change Password', onTap: () {}),
          _ProfileTile(icon: Icons.notifications_outlined, title: 'Notification Preferences', onTap: () {}),

          const SizedBox(height: 16),
          _SectionHeader('App'),
          _ProfileTile(icon: Icons.info_outline, title: 'About NewsNow', onTap: () {}),
          _ProfileTile(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),
          _ProfileTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () {}),

          const SizedBox(height: 16),
          _SectionHeader('Account Status'),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5)),
            child: ListTile(
              leading: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: user.isActive ? AppColors.success : AppColors.error, shape: BoxShape.circle),
              ),
              title: Text(user.isActive ? 'Active' : 'Suspended', style: TextStyle(color: user.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w500)),
              trailing: Text('ID: ${user.id.substring(user.id.length - 6)}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ),
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await AppUtils.confirm(context, title: 'Sign Out', message: 'Are you sure you want to sign out?', confirmLabel: 'Sign Out', confirmColor: AppColors.error);
              if (confirmed && context.mounted) {
                await context.read<AuthProvider>().logout();
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('NewsNow v1.0.0', style: const TextStyle(fontSize: 12, color: AppColors.textHint))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
  );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5)),
    child: ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
      onTap: onTap,
    ),
  );
}