import 'package:flutter/material.dart';
import '../widgets/feed/feed_xpresso_theme.dart';

class AppUtils {
  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  static String? validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  static String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Minimum 8 characters';
    return null;
  }

  static String? validateRequired(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? validateMinLength(String? v, String field, int min) =>
      (v == null || v.trim().length < min) ? '$field must be at least $min characters' : null;

  static FeedXpressoPalette _fx(BuildContext? context) =>
      context != null ? FeedXpressoTheme.fx(context) : FeedXpressoPalette.dark;

  static void showSuccess(BuildContext context, String message) {
    final fx = _fx(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle, color: fx.accentLight, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: fx.title))),
      ]),
    ));
  }

  static void showError(BuildContext context, String message) {
    final fx = _fx(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.error_outline, color: fx.error, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: fx.title))),
      ]),
    ));
  }

  static void showInfo(BuildContext context, String message) {
    final fx = _fx(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: fx.title)),
    ));
  }

  static Future<bool> confirm(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', Color? confirmColor}) async {
    final fx = _fx(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: TextStyle(color: fx.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? fx.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Color roleColor(String role, [BuildContext? context]) {
    final fx = _fx(context);
    switch (role) {
      case 'admin': return fx.accentSecondaryLight;
      case 'reporter': return fx.accentLight;
      default: return fx.info;
    }
  }

  static IconData roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'reporter': return Icons.mic;
      default: return Icons.person;
    }
  }

  static Color statusColor(String status, [BuildContext? context]) {
    final fx = _fx(context);
    switch (status) {
      case 'approved': return fx.success;
      case 'rejected': return fx.error;
      case 'pending': return fx.warning;
      default: return fx.textHint;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'pending': return Icons.pending;
      default: return Icons.edit_note;
    }
  }

  static String initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : '?');
  }

  static String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
