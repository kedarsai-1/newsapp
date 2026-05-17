import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thumbnail-first highlights — opens YouTube only when user taps play.
class SportsYoutubeSheet {
  static Future<void> open(
    BuildContext context, {
    required String title,
    String? youtubeUrl,
    String? youtubeVideoId,
  }) async {
    final id = youtubeVideoId?.trim();
    final url = youtubeUrl?.trim().isNotEmpty == true
        ? youtubeUrl!.trim()
        : (id != null && id.isNotEmpty
            ? 'https://www.youtube.com/watch?v=$id'
            : null);
    if (url == null) return;

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $title')),
      );
    }
  }
}
