import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/reporter_provider.dart';
import '../../widgets/empty_state.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';
import '../../theme/app_palette.dart';
import '../../widgets/location_label.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});
  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _statuses = [null, 'pending', 'approved', 'rejected', 'draft'];
  final _labels = ['All', 'Pending', 'Approved', 'Rejected', 'Draft'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _load(_tabs.index); });
    _load(0);
  }

  void _load(int i) => context.read<ReporterProvider>().loadMyPosts(status: _statuses[i]);

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<ReporterProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: p.primary,
          unselectedLabelColor: p.textHint,
          indicatorColor: p.primary,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.myPosts.isEmpty
              ? EmptyState(
                  icon: Icons.article_outlined,
                  title: 'No stories here',
                  subtitle: _tabs.index == 0 ? 'Start writing your first story.' : null,
                  buttonLabel: _tabs.index == 0 ? 'Create Story' : null,
                  onButtonTap: _tabs.index == 0 ? () => context.go('/reporter/new') : null,
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadMyPosts(status: _statuses[_tabs.index]),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.myPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final post = provider.myPosts[i];
                      final statusColor = AppUtils.statusColor(post.status);
                      return Container(
                        decoration: BoxDecoration(
                          color: p.glassSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.cardBorder, width: 0.5),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Status header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(children: [
                              Icon(AppUtils.statusIcon(post.status), size: 14, color: statusColor),
                              const SizedBox(width: 6),
                              Text(post.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                              const Spacer(),
                              Text(timeago.format(post.createdAt), style: TextStyle(fontSize: 11, color: p.textHint)),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(post.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Wrap(spacing: 10, children: [
                                if (post.category != null)
                                  Text('${post.category!.icon} ${post.category!.name}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                                if (post.location != null)
                                  LocationLabel(
                                    location: post.location!,
                                    style: TextStyle(fontSize: 12, color: p.textHint),
                                    iconSize: 12,
                                    expandText: false,
                                    maxTextWidth: 180,
                                  ),
                              ]),
                              if (post.status == 'rejected' && post.rejectionReason != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(8)),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(Icons.info_outline, size: 14, color: p.error),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(post.rejectionReason!, style: TextStyle(fontSize: 12, color: p.error))),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(children: [
                                if (post.status == 'approved') ...[
                                  Icon(Icons.visibility_outlined, size: 13, color: p.textHint),
                                  const SizedBox(width: 4),
                                  Text(AppUtils.formatCount(post.views), style: TextStyle(fontSize: 12, color: p.textHint)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.favorite_border, size: 13, color: p.textHint),
                                  const SizedBox(width: 4),
                                  Text(AppUtils.formatCount(post.likes), style: TextStyle(fontSize: 12, color: p.textHint)),
                                  const SizedBox(width: 12),
                                ],
                                if (post.media.isNotEmpty) ...[
                                  Icon(Icons.perm_media_outlined, size: 13, color: p.textHint),
                                  const SizedBox(width: 4),
                                  Text('${post.media.length} media', style: TextStyle(fontSize: 12, color: p.textHint)),
                                ],
                                const Spacer(),
                                if (['draft', 'rejected'].contains(post.status))
                                  TextButton.icon(
                                    onPressed: () => context.go('/reporter/new'),
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  ),
                              ]),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/reporter/new'),
        backgroundColor: p.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}