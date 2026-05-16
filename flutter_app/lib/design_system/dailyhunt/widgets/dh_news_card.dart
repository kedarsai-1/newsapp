import 'package:flutter/material.dart';

import '../../../widgets/feed/compact_list_row.dart';

/// Search results row — light compact list (not Xpresso).
class DhNewsCard extends StatelessWidget {
  final String title;
  final String? summary;
  final String imageUrl;
  final String sourceLabel;
  final String timeLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DhNewsCard({
    super.key,
    required this.title,
    this.summary,
    required this.imageUrl,
    required this.sourceLabel,
    required this.timeLabel,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CompactListRow(
      title: title,
      summary: summary,
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      metaLine: '$sourceLabel · $timeLabel',
      onTap: onTap,
      trailing: trailing,
    );
  }
}
