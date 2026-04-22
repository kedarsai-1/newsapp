import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme/app_palette.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final Color? backgroundColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppBar(
      backgroundColor: backgroundColor ?? p.glassSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      automaticallyImplyLeading: showBack,
      leading: leading,
      title: subtitle != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.textPrimary)),
              Text(subtitle!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: p.textSecondary)),
            ])
          : Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary)),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 64 : 56);
}

// Role badge widget used in appbars
class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  Color _color(BuildContext context) {
    final p = context.palette;
    switch (role) {
      case 'admin': return p.accentOrangeLight;
      case 'reporter': return p.accentGreenLight;
      default: return p.info;
    }
  }

  IconData get _icon {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'reporter': return Icons.mic;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          role[0].toUpperCase() + role.substring(1),
          style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}