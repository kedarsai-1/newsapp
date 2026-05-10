import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../premium_news_ui.dart';
import 'shorts_media_layer.dart';

/// Dailyhunt-style shorts card: full media, bottom copy, right action rail (no TikTok scaling).
class DailyhuntShortsPage extends StatelessWidget {
  final NewsPost post;
  final bool isActive;
  final bool liked;
  final bool saved;
  final bool translating;
  final String? translatedSummary;
  final VoidCallback onLike;
  final VoidCallback onSave;
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

  String _snippet() {
    if (translatedSummary != null && translatedSummary!.trim().isNotEmpty) {
      return translatedSummary!.trim();
    }
    return premiumSnippet(post, maxLength: 220);
  }

  String _sourceLine() {
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'RSS');
    final lang = post.language.trim().toUpperCase();
    final langBit = lang.isNotEmpty && lang != 'EN' ? ' · $lang' : '';
    return '$src · ${timeago.format(post.displayTime)}$langBit';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        ShortsMediaLayer(post: post, isActive: isActive),
        // Single bottom scrim for readability (no multi-stop “fancy” stack).
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: bottomContentPadding + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SideAction(
                icon: liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                label: 'Like',
                iconColor: liked ? p.primary : Colors.white,
                onTap: onLike,
              ),
              _SideAction(
                icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                label: 'Save',
                iconColor: saved ? p.primary : Colors.white,
                onTap: onSave,
              ),
              _SideAction(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: onShare,
              ),
              _SideAction(
                icon: Icons.translate_rounded,
                label: translatedSummary == null ? 'Translate' : 'Original',
                busy: translating,
                onTap: onTranslate,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 72,
          bottom: bottomContentPadding,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpenArticle,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _snippet(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.35,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sourceLine(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : Icon(icon, color: iconColor ?? Colors.white, size: 26),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
