import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/models.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';
import '../../theme/app_palette.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _roleFilters = [null, 'reporter', 'user', 'admin'];
  final _tabLabels = ['All', 'Reporters', 'Users', 'Admins'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _load(_tabs.index); });
    _load(0);
  }

  void _load(int i) => context.read<AdminProvider>().loadUsers(role: _roleFilters[i]);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<AdminProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: p.primary,
          unselectedLabelColor: p.textHint,
          indicatorColor: p.primary,
          tabs: _tabLabels.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: provider.loading
          ? ListView(padding: const EdgeInsets.all(12), children: List.generate(6, (_) => const UserRowShimmer()))
          : provider.users.isEmpty
              ? Center(child: Text('No users found.', style: TextStyle(color: p.textSecondary)))
              : RefreshIndicator(
                  onRefresh: () => provider.loadUsers(role: _roleFilters[_tabs.index]),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _UserTile(
                      user: provider.users[i],
                      onChangeRole: (userId, role) async {
                        final ok = await provider.updateUserRole(userId, role);
                        if (ok && context.mounted) AppUtils.showSuccess(context, 'Role updated.');
                      },
                      onToggleActive: (userId) async {
                        final ok = await provider.toggleUserActive(userId);
                        if (ok && context.mounted) AppUtils.showInfo(context, 'User status updated.');
                      },
                    ),
                  ),
                ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final Future<void> Function(String, String) onChangeRole;
  final Future<void> Function(String) onToggleActive;
  const _UserTile({required this.user, required this.onChangeRole, required this.onToggleActive});

  Future<void> _showRoleDialog(BuildContext context) async {
    final pal = context.palette;
    final role = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change role for ${user.name}'),
        children: ['user', 'reporter', 'admin'].map((r) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, r),
          child: Row(children: [
            Icon(AppUtils.roleIcon(r), size: 18, color: AppUtils.roleColor(r)),
            const SizedBox(width: 10),
            Text(r[0].toUpperCase() + r.substring(1),
              style: TextStyle(fontWeight: user.role == r ? FontWeight.bold : FontWeight.normal)),
            if (user.role == r) Text(' (current)', style: TextStyle(fontSize: 12, color: pal.textHint)),
          ]),
        )).toList(),
      ),
    );
    if (role != null && role != user.role) await onChangeRole(user.id, role);
  }

  Future<void> _confirmToggle(BuildContext context) async {
    final pal = context.palette;
    final ok = await AppUtils.confirm(context,
      title: user.isActive ? 'Suspend User' : 'Activate User',
      message: '${user.isActive ? 'Suspend' : 'Activate'} ${user.name}?',
      confirmLabel: user.isActive ? 'Suspend' : 'Activate',
      confirmColor: user.isActive ? pal.error : pal.success,
    );
    if (ok) await onToggleActive(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final roleColor = AppUtils.roleColor(user.role);
    return Container(
      decoration: BoxDecoration(
        color: p.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: user.isActive ? p.cardBorder : const Color(0xFFFCEBEB), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withOpacity(0.15),
            child: Text(AppUtils.initials(user.name), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: roleColor)),
          ),
          if (!user.isActive)
            Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: p.error, shape: BoxShape.circle))),
        ]),
        title: Row(children: [
          Text(user.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(user.role, style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(user.email, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          if (!user.isActive) Text('Suspended', style: TextStyle(fontSize: 11, color: p.error, fontWeight: FontWeight.w500)),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'role') _showRoleDialog(context);
            if (action == 'toggle') _confirmToggle(context);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'role', child: Row(children: [Icon(Icons.swap_horiz, size: 16), SizedBox(width: 8), Text('Change Role')])),
            PopupMenuItem(value: 'toggle', child: Row(children: [
              Icon(user.isActive ? Icons.block : Icons.check_circle, size: 16, color: user.isActive ? p.error : p.success),
              const SizedBox(width: 8),
              Text(user.isActive ? 'Suspend' : 'Activate', style: TextStyle(color: user.isActive ? p.error : p.success)),
            ])),
          ],
        ),
      ),
    );
  }
}