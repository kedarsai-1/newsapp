import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_spacing.dart';

/// Button tokens and reusable Material button styles.
class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle primary(AppPalette p) => ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
        shape:
            const RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  static ButtonStyle tonal(AppPalette p) => FilledButton.styleFrom(
        backgroundColor: p.primary.withValues(alpha: 0.18),
        foregroundColor: p.primary,
        minimumSize: const Size.fromHeight(44),
        shape:
            const RoundedRectangleBorder(borderRadius: AppSpacing.buttonRadius),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
}

/// Card styles for content blocks.
class AppCardStyles {
  AppCardStyles._();

  static BoxDecoration elevated(AppPalette p) => BoxDecoration(
        color: p.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: p.cardBorder.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration glass(AppPalette p) => BoxDecoration(
        color: p.surface.withValues(alpha: 0.62),
        borderRadius: AppSpacing.panelRadius,
        border: Border.all(color: p.glassBorder),
      );
}

/// Semantic icon set. Centralize icon choice for consistency.
class AppIcons {
  AppIcons._();

  static const home = Icons.home_rounded;
  static const categories = Icons.grid_view_rounded;
  static const bookmarks = Icons.bookmark_rounded;
  static const profile = Icons.person_rounded;
  static const search = Icons.search_rounded;
  static const notification = Icons.notifications_none_rounded;
  static const back = Icons.arrow_back_ios_new_rounded;
  static const chevronDown = Icons.keyboard_arrow_down_rounded;
  static const image = Icons.image_outlined;
  static const empty = Icons.inbox_rounded;
  static const list = Icons.view_agenda_outlined;
  static const login = Icons.login_rounded;
  static const logout = Icons.logout_rounded;
  static const privacy = Icons.privacy_tip_outlined;
  static const alert = Icons.flash_off_rounded;
  static const translate = Icons.translate_rounded;
  static const share = Icons.ios_share_rounded;
  static const offline = Icons.offline_pin_rounded;
  static const themeDark = Icons.dark_mode_rounded;
  static const themeLight = Icons.light_mode_rounded;
}
