import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/saved_local_place.dart';
import '../../providers/news_provider.dart';
import '../../utils/i18n.dart';
import '../feed/feed_xpresso_theme.dart';
import 'local_location_picker_sheet.dart';

/// Way2News-style dual saved location chips for the Local tab.
class LocalSavedLocationBar extends StatelessWidget {
  const LocalSavedLocationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final news = context.watch<NewsProvider>();
    if (!news.isLocalMode) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          for (var slot = 0; slot < NewsProvider.maxSavedLocations; slot++) ...[
            if (slot > 0) const SizedBox(width: 8),
            Expanded(
              child: _LocationChip(
                fx: fx,
                slot: slot,
                place: news.savedLocationAt(slot),
                isActive: news.activeLocationSlot == slot,
                onTap: () => news.selectActiveLocationSlot(slot),
                onEdit: () => _openPicker(context, slot, news.savedLocationAt(slot)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    int slot,
    SavedLocalPlace? existing,
  ) async {
    final picked = await showModalBottomSheet<SavedLocalPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocalLocationPickerSheet(
        slot: slot,
        initial: existing,
        defaultLabel: slot == 0
            ? I18n.t(context, 'local_label_home')
            : I18n.t(context, 'local_label_native'),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked.isEmpty) {
      await context.read<NewsProvider>().clearLocationSlot(slot);
      return;
    }
    await context.read<NewsProvider>().saveLocationSlot(slot, picked);
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.fx,
    required this.slot,
    required this.place,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
  });

  final FeedXpressoPalette fx;
  final int slot;
  final SavedLocalPlace? place;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final empty = place == null || place!.isEmpty;
    final title = empty
        ? (slot == 0
            ? I18n.t(context, 'local_add_home')
            : I18n.t(context, 'local_add_native'))
        : place!.shortChipLabel;
    final subtitle = empty ? I18n.t(context, 'local_tap_to_set') : place!.displayTitle;

    return Material(
      color: isActive ? fx.accent.withValues(alpha: 0.14) : fx.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: empty ? onEdit : onTap,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? fx.accent : fx.chipInactiveBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                slot == 0 ? Icons.home_outlined : Icons.place_outlined,
                size: 18,
                color: isActive ? fx.accent : fx.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? fx.accent : fx.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: fx.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 16, color: fx.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
