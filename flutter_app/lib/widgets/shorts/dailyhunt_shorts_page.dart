import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../premium_news_ui.dart';
import 'shorts_media_layer.dart';

/// Lightweight shorts page — flat bottom bar, local action state.
class DailyhuntShortsPage extends StatefulWidget {
  final NewsPost post;
  final bool isActive;
  final bool liked;
  final bool saved;
  final bool translating;
  final String? translatedSummary;
  final Future<bool> Function() onLike;
  final Future<bool> Function() onSave;
  final VoidCallback onShare;
  final VoidCallback onTranslate;
  final VoidCallback onOpenArticle;
  final double bottomContentPadding;

  const DailyhuntShortsPage({
    super.key,
    required this.post,
    required this.isActive,
    required this.liked,
    required this.saved,
    required this.translating,
    this.translatedSummary,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onTranslate,
    required this.onOpenArticle,
    required this.bottomContentPadding,
  });

  @override
  State<DailyhuntShortsPage> createState() => _DailyhuntShortsPageState();
}

class _DailyhuntShortsPageState extends State<DailyhuntShortsPage> {
  late bool _liked;
  late bool _saved;
  late final String _snippet;
  late final String _sourceLine;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _saved = widget.saved;
    _snippet = _buildSnippet();
    _sourceLine = _buildSourceLine();
  }

  @override
  void didUpdateWidget(covariant DailyhuntShortsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.liked;
      _saved = widget.saved;
    } else {
      if (oldWidget.liked != widget.liked) _liked = widget.liked;
      if (oldWidget.saved != widget.saved) _saved = widget.saved;
    }
    if (oldWidget.translatedSummary != widget.translatedSummary) {
      // Rebuild snippet only when translation toggles.
    }
  }

  String _buildSnippet() {
    final t = widget.translatedSummary;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return premiumSnippet(widget.post, maxLength: 180);
  }

  String _buildSourceLine() {
    final post = widget.post;
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'RSS');
    final lang = post.language.trim().toUpperCase();
    final langBit = lang.isNotEmpty && lang != 'EN' ? ' · $lang' : '';
    return '$src · ${timeago.format(post.displayTime)}$langBit';
  }

  Future<void> _handleLike() async {
    setState(() => _liked = !_liked);
    final ok = await widget.onLike();
    if (!mounted || ok) return;
    setState(() => _liked = !_liked);
  }

  Future<void> _handleSave() async {
    setState(() => _saved = !_saved);
    final ok = await widget.onSave();
    if (!mounted || ok) return;
    setState(() => _saved = !_saved);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final snippet = widget.translatedSummary != null &&
            widget.translatedSummary!.trim().isNotEmpty
        ? widget.translatedSummary!.trim()
        : _snippet;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ShortsMediaLayer(post: widget.post, isActive: widget.isActive),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: const Color(0xCC000000),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  52,
                  widget.bottomContentPadding,
                ),
                child: GestureDetector(
                  onTap: widget.onOpenArticle,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          height: 1.3,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _sourceLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: widget.bottomContentPadding + 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SideAction(
                  icon: _liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                  label: 'Like',
                  iconColor: _liked ? p.primary : Colors.white,
                  onTap: _handleLike,
                ),
                _SideAction(
                  icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  label: 'Save',
                  iconColor: _saved ? p.primary : Colors.white,
                  onTap: _handleSave,
                ),
                _SideAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: widget.onShare,
                ),
                _SideAction(
                  icon: Icons.translate_rounded,
                  label: widget.translatedSummary == null ? 'Translate' : 'Original',
                  busy: widget.translating,
                  onTap: widget.onTranslate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool busy;

  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : Icon(icon, color: iconColor ?? Colors.white, size: 22),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD8D8D8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
