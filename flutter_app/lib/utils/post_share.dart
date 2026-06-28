import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/i18n.dart';

enum _WebShareAction { copy, whatsapp }

/// Dailyhunt-style share: title, short link, "By {source} via {app}."
abstract final class PostShare {
  static String fallbackShareText(NewsPost post) {
    final base = AppConstants.shareWebBaseUrl;
    final url = base.isNotEmpty ? '$base/article/${post.id}' : (post.sourceUrl ?? '');
    return _format(
      title: post.title,
      shareUrl: url,
      sourceName: post.displaySourceName,
    );
  }

  static String _format({
    required String title,
    required String shareUrl,
    required String sourceName,
  }) {
    final headline = title.trim();
    final source = sourceName.trim().isNotEmpty ? sourceName.trim() : 'News';
    final brand = AppConstants.appName;
    return '$headline\n$shareUrl\n\nBy $source via $brand.';
  }

  static Future<String> resolveShareText(NewsPost post) async {
    final res = await ApiService.getPostShareLink(post.id);
    if (res['success'] == true) {
      final text = res['shareText']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
      final url = res['shareUrl']?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return _format(
          title: post.title,
          shareUrl: url,
          sourceName: res['sourceName']?.toString() ?? post.displaySourceName,
        );
      }
    }
    return fallbackShareText(post);
  }

  static Future<void> sharePost(
    NewsPost post, {
    BuildContext? context,
    String? subject,
  }) async {
    final text = await resolveShareText(post);
    if (kIsWeb) {
      await _shareOnWeb(text, context: context);
      return;
    }

    try {
      Rect? shareOrigin;
      if (context != null) {
        final ro = context.findRenderObject();
        if (ro is RenderBox) {
          final topLeft = ro.localToGlobal(Offset.zero);
          shareOrigin = Rect.fromLTWH(
            topLeft.dx,
            topLeft.dy,
            ro.size.width,
            ro.size.height,
          );
        }
      }
      await Share.share(
        text,
        subject: subject ?? post.title,
        sharePositionOrigin: shareOrigin,
      );
    } catch (_) {
      await _copyWithFeedback(context, text);
    }
  }

  static Future<void> _shareOnWeb(String text, {BuildContext? context}) async {
    if (context != null && context.mounted) {
      final action = await _showWebShareSheet(context, text);
      if (action == _WebShareAction.copy && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'share_copied'))),
        );
      }
      return;
    }
    await _copyWithFeedback(context, text);
  }

  static Future<_WebShareAction?> _showWebShareSheet(
    BuildContext context,
    String text,
  ) async {
    final fx = Theme.of(context);
    final result = await showModalBottomSheet<_WebShareAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                I18n.t(ctx, 'share_sheet_title'),
                style: fx.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fx.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text,
                  style: fx.textTheme.bodySmall?.copyWith(height: 1.45),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (ctx.mounted) Navigator.pop(ctx, _WebShareAction.copy);
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(I18n.t(ctx, 'share_copy')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final wa = Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent(text)}',
                  );
                  await launchUrl(wa, mode: LaunchMode.externalApplication);
                  if (ctx.mounted) Navigator.pop(ctx, _WebShareAction.whatsapp);
                },
                icon: const Icon(Icons.chat_rounded),
                label: Text(I18n.t(ctx, 'share_whatsapp')),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

  static Future<void> _copyWithFeedback(BuildContext? context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t(context, 'share_copied'))),
      );
    }
  }
}
