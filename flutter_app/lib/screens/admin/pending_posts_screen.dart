import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/admin_provider.dart';
import '../../models/models.dart';
import '../../widgets/empty_state.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';

class PendingPostsScreen extends StatefulWidget {
  const PendingPostsScreen({super.key});
  @override
  State<PendingPostsScreen> createState() => _PendingPostsScreenState();
}

class _PendingPostsScreenState extends State<PendingPostsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminProvider>().loadPendingPosts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('Pending Review'),
          const SizedBox(width: 10),
          if (provider.pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(12)),
              child: Text('${provider.pendingCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.pendingPosts.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'All caught up!',
                  subtitle: 'No pending stories to review.',
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadPendingPosts(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.pendingPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ReviewCard(
                      post: provider.pendingPosts[i],
                      onApprove: (isBreaking, isFeatured) async {
                        final ok = await provider.approvePost(
                          provider.pendingPosts[i].id,
                          isBreaking: isBreaking,
                          isFeatured: isFeatured,
                        );
                        if (ok && context.mounted) AppUtils.showSuccess(context, 'Story published!');
                      },
                      onReject: (reason) async {
                        final ok = await provider.rejectPost(provider.pendingPosts[i].id, reason);
                        if (ok && context.mounted) AppUtils.showInfo(context, 'Story rejected.');
                      },
                    ),
                  ),
                ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final NewsPost post;
  final Future<void> Function(bool isBreaking, bool isFeatured) onApprove;
  final Future<void> Function(String reason) onReject;

  const _ReviewCard({required this.post, required this.onApprove, required this.onReject});

  Future<void> _showApproveDialog(BuildContext context) async {
    bool isBreaking = false;
    bool isFeatured = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Publish Story'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: isBreaking, activeColor: AppColors.breaking,
              onChanged: (v) => setLocal(() => isBreaking = v!),
              title: const Text('Breaking News'), contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: isFeatured, activeColor: AppColors.primary,
              onChanged: (v) => setLocal(() => isFeatured = v!),
              title: const Text('Featured Story'), contentPadding: EdgeInsets.zero,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve & Publish')),
          ],
        ),
      ),
    );
    if (confirmed == true) await onApprove(isBreaking, isFeatured);
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Story'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Give the reporter a reason so they can revise:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'e.g. Needs sources, verify facts...'), maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) await onReject(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (post.hasImages)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: CachedNetworkImage(
              imageUrl: post.firstImage!.url, height: 160, width: double.infinity, fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 160, color: const Color(0xFFF0F0F0)),
              errorWidget: (_, __, ___) => Container(height: 160, color: const Color(0xFFF0F0F0), child: const Icon(Icons.broken_image, color: AppColors.textHint)),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.primary,
                  child: Text(AppUtils.initials(post.reporter?.name ?? '?'), style: const TextStyle(color: Colors.white, fontSize: 10))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.reporter?.name ?? 'Reporter', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(timeago.format(post.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ])),
              if (post.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(6)),
                  child: Text('${post.category!.icon} ${post.category!.name}', style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w500)),
                ),
            ]),
            const SizedBox(height: 10),
            Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 6),
            Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, children: [
              if (post.location?.city != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(post.location!.displayLocation, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              if (post.hasImages)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.image_outlined, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text('${post.media.where((m) => m.isImage).length} photo(s)', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                ]),
              if (post.hasVideos)
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam_outlined, size: 13, color: AppColors.textHint),
                  SizedBox(width: 3),
                  Text('Video', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ]),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _showRejectDialog(context),
                icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                label: const Text('Reject', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: () => _showApproveDialog(context),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve & Publish', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}