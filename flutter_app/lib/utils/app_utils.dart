import 'package:flutter/material.dart';
import '../constants.dart';

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
    if (v.length < 6) return 'Minimum 6 characters';
    return null;
  }

  static String? validateRequired(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? validateMinLength(String? v, String field, int min) =>
      (v == null || v.trim().length < min) ? '$field must be at least $min characters' : null;

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: GlassColors.accentGreenLight, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: GlassColors.textPrimary))),
      ]),
    ));
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.error_outline, color: GlassColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: GlassColors.textPrimary))),
      ]),
    ));
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: GlassColors.textPrimary)),
    ));
  }

  static Future<bool> confirm(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', Color? confirmColor}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(color: GlassColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? GlassColors.accentGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Color roleColor(String role) {
    switch (role) {
      case 'admin': return GlassColors.accentOrangeLight;
      case 'reporter': return GlassColors.accentGreenLight;
      default: return GlassColors.info;
    }
  }

  static IconData roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'reporter': return Icons.mic;
      default: return Icons.person;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'approved': return GlassColors.success;
      case 'rejected': return GlassColors.error;
      case 'pending': return GlassColors.warning;
      default: return GlassColors.textHint;
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
}